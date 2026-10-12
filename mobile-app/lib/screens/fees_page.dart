import 'package:flutter/material.dart';
import '../services/api/fees_api.dart';
import '../services/auth_service.dart';
import '../widgets/enterprise_ui_components.dart';
import 'offline_payment_page.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import 'fees/fee_logic.dart';
import 'fees/widgets/fee_card.dart';
import 'fees/widgets/processing_fee_card.dart';
import 'fees/widgets/offline_payment_card.dart';
import 'fees/widgets/multi_fee_payment_dialog.dart';
import '../models/fee_model.dart';
import '../widgets/translated_text.dart';

class FeesPage extends StatefulWidget {
  const FeesPage({super.key});

  @override
  State<FeesPage> createState() => _FeesPageState();
}

class _FeesPageState extends State<FeesPage> {
  int _selectedTab = 0; // 0 = Fees, 1 = Processing Fees, 2 = Offline Payment
  Map<String, dynamic> feesData = {};
  List<Fee> fees = [];
  List<ProcessingFee> processingFees = [];
  List<OfflinePayment> offlinePayments = [];
  
  // Multi-select state
  final List<Fee> _selectedFees = [];
  
  bool isLoading = true;
  String? error;
  String? studentId;
  String? _currencySymbolFromPaymentRequest;

  String? _currencySymbol() {
    // 1. Check if we have a symbol from a previous payment request in this session
    if (_currencySymbolFromPaymentRequest != null && 
        _currencySymbolFromPaymentRequest!.trim().isNotEmpty) {
      return _currencySymbolFromPaymentRequest;
    }
    
    // 2. Fallback to global app setting from Provider
    // This allows dynamic currency conversion to show the correct symbol immediately
    try {
      final symbol = Provider.of<AppConfigProvider>(context).selectedCurrencySymbol;
      if (symbol.isNotEmpty && symbol.toLowerCase() != 'null') {
        return symbol;
      }
    } catch (e) {
    }
    
    return null;
  }
  

  @override
  void initState() {
    super.initState();
    _loadFeesData();
  }
  
  // CRITICAL RULE 4: Currency symbol must come from invoice.symbol only
  // Extract and store currency symbol from paymentrequest API response
  void _toggleFeeSelection(Fee fee, bool? selected) {
    if (selected == null) return;
    
    setState(() {
      final feeId = fee.id;
      if (selected) {
        // Multi-selection allowed (User controlled)
        // Add if not already selected
        if (!_selectedFees.any((f) => f.id == feeId)) {
          _selectedFees.add(fee);
        }
      } else {
        // Remove
        final index = _selectedFees.indexWhere((f) => f.id == feeId);
        if (index != -1) {
          _selectedFees.removeAt(index);
        }
      }
    });
  }

  void _toggleSelectAll(bool? selected) {
    setState(() {
      _selectedFees.clear();
      if (selected == true) {
        // Only select fees that are unpaid/partial (payable)
        _selectedFees.addAll(fees.where((f) => f.isPayable && !f.hasPendingOfflinePayment));
      }
    });
  }

  bool get _isAllSelected {
    final payableFees = fees.where((f) => f.isPayable && !f.hasPendingOfflinePayment).toList();
    if (payableFees.isEmpty) return false;
    
    // Check if every payable fee is in _selectedFees
    return payableFees.every((pf) => _selectedFees.any((sf) => sf.id == pf.id));
  }

  Future<void> _loadFeesData() async {
    
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      studentId = await AuthService.getStudentId();

      // Load all fees data in parallel independently to prevent one failure from blocking others
      final results = await Future.wait([
        FeesApi.getFees(studentId!).catchError((e) {
          return {'status': 0, 'fees': <Fee>[]};
        }),
        FeesApi.getProcessingFees(studentId!).catchError((e) {
          return {'status': 0, 'fees': <ProcessingFee>[]};
        }),
        FeesApi.getOfflineBankPayments(studentId!).catchError((e) {
          return {'status': 0, 'payments': <OfflinePayment>[]};
        }),
      ]);

      if (!mounted) {
        return;
      }

      final feesResponse = Map<String, dynamic>.from(results[0] as Map);
      final processingResponse = Map<String, dynamic>.from(results[1] as Map);
      final offlineResponse = Map<String, dynamic>.from(results[2] as Map);

      List<Fee> extractedFees = List<Fee>.from(feesResponse['fees'] ?? []);
      List<ProcessingFee> extractedProcessing = List<ProcessingFee>.from(processingResponse['fees'] ?? []);
      List<OfflinePayment> extractedOffline = List<OfflinePayment>.from(offlineResponse['payments'] ?? []);

      // CRITICAL: Cross-reference offline payments with fees
      // Mark fees that have pending offline payment requests
      // Filter out fees that have approved offline payments (they're paid)
      
      final List<Fee> updatedFees = extractedFees.where((fee) {
        // Rule: If ANY offline payment for this specific fee is approved, hide the fee (it's paid)
        final hasApproved = extractedOffline.any((p) => 
          p.status.toLowerCase() == 'approved' && FeeLogic.feeMatchesPayment(fee.raw, p.raw)
        );
        if (hasApproved) {
          return false; // Don't include this fee
        }
        return true; // Include this fee
      }).map((fee) {
        // Rule: If ANY offline payment for this specific fee is pending, mark it
        final hasPending = extractedOffline.any((p) => 
          p.status.toLowerCase() == 'pending' && FeeLogic.feeMatchesPayment(fee.raw, p.raw)
        );
        
        if (hasPending) {
          // Create new Fee instance with hasPendingOfflinePayment = true
          return Fee(
            id: fee.id,
            feeGroupId: fee.feeGroupId,
            feeGroupsFeetypeId: fee.feeGroupsFeetypeId,
            studentFeesMasterId: fee.studentFeesMasterId,
            feeType: fee.feeType,
            feeCode: fee.feeCode,
            feeGroupName: fee.feeGroupName,
            dueDate: fee.dueDate,
            amount: fee.amount,
            fine: fee.fine,
            discount: fee.discount,
            paid: fee.paid,
            balance: fee.balance,
            totalDue: fee.totalDue,
            month: fee.month,
            status: fee.status,
            hasPendingOfflinePayment: true,
            raw: fee.raw,
          );
        }
        return fee;
      }).toList();

      setState(() {
        feesData = feesResponse;
        fees = updatedFees;
        processingFees = extractedProcessing;
        offlinePayments = extractedOffline;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
        error = 'Error loading fees data: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // Light gray background
      appBar: AppBar(
        title: const TranslatedText(
          'Fees',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj, // Use dynamic primary color
        foregroundColor: Colors.white,
        elevation: 2,
        shadowColor: Provider.of<AppConfigProvider>(context).primaryColorObj.withValues(alpha: 0.3),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Header Section with illustration
          _buildHeaderSection(),
          
          // Tab Navigation
          _buildTabNavigation(),
          
          // Content Area
          Expanded(
            child: Container(
              color: Colors.white,
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : error != null
                      ? _buildErrorState()
                      : _buildContent(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _selectedFees.isNotEmpty
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TranslatedText(
                            '${_selectedFees.length} Selected',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const TranslatedText(
                            'Click Pay Now to view summary',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () => _showPaymentModeSelection(null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                        child: TranslatedText(
                        'Pay Now (${_currencySymbol() ?? ''}${_selectedFees.fold(0.0, (sum, fee) => sum + Provider.of<AppConfigProvider>(context).convertAmount(fee.totalDue)).toStringAsFixed(2)})',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  // Show payment mode selection dialog
  Future<void> _showPaymentModeSelection(Fee? fee) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const TranslatedText('Choose Payment Mode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   IconButton(
                     icon: const Icon(Icons.close, size: 20),
                     onPressed: () => Navigator.pop(context),
                     padding: EdgeInsets.zero,
                     constraints: const BoxConstraints(),
                   ),
                ],
              ),
              const SizedBox(height: 20),
              _buildPaymentModeOption(
                icon: Icons.public,
                title: 'Online Payment',
                onTap: () {
                  Navigator.pop(context);
                  _showMultiFeePaymentDialog(singleFee: fee);
                },
              ),
              const SizedBox(height: 12),
              _buildPaymentModeOption(
                icon: Icons.wallet,
                title: 'Offline Payment',
                onTap: () {
                  Navigator.pop(context);
                  
                  // Use provided fee, or first selected fee from multi-select
                  final feeToUse = fee ?? (_selectedFees.isNotEmpty ? _selectedFees.first : null);
                  
                  if (feeToUse == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select at least one fee for offline payment.')),
                    );
                    return;
                  }

                  // Extract IDs needed for OfflinePaymentPage with fallbacks
                  final studentSessionId = feeToUse.raw['student_session_id']?.toString() ?? 
                                          feesData['student_session_id']?.toString() ?? '';
                  
                  // Try multiple possible field names for student_fees_master_id
                  String studentFeesMasterId = feeToUse.studentFeesMasterId;
                  // If it's a composite ID (contains underscores), extract the first part which is the real master ID
                  if (studentFeesMasterId.contains('_')) {
                    studentFeesMasterId = studentFeesMasterId.split('_').first;
                  }
                  
                  if (studentFeesMasterId.isEmpty) {
                    studentFeesMasterId = (feeToUse.raw['student_fees_master_id'] ?? 
                                          feeToUse.raw['master_id'] ?? 
                                          feeToUse.raw['fees_master_id'] ?? 
                                          '').toString();
                  }
                  
                  // Try multiple possible field names for fee_groups_feetype_id
                  String feeGroupsFeetypeId = feeToUse.feeGroupsFeetypeId;
                  if (feeGroupsFeetypeId.isEmpty) {
                    feeGroupsFeetypeId = feeToUse.raw['fee_session_group_id']?.toString() ?? 
                                        feeToUse.raw['feetype_id']?.toString() ?? 
                                        feeToUse.raw['type_id']?.toString() ?? 
                                        feeToUse.feeGroupId;
                  }
                  
                  // Extract student_transport_fee_id for transport fees
                  final studentTransportFeeId = feeToUse.raw['student_transport_fee_id']?.toString() ?? '';
 
  
 
                  // Rule: Validation passes if it's either a standard fee (type id) OR a transport fee
                  if (studentId == null || studentFeesMasterId.isEmpty || (feeGroupsFeetypeId.isEmpty && studentTransportFeeId.isEmpty)) {
                    final missingFields = <String>[];
                    if (studentId == null) missingFields.add('Student ID');
                    if (studentFeesMasterId.isEmpty) missingFields.add('Fee Master ID');
                    if (feeGroupsFeetypeId.isEmpty && studentTransportFeeId.isEmpty) missingFields.add('Fee Type ID');
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Missing: ${missingFields.join(", ")}. Please contact support.')),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OfflinePaymentPage(
                        fee: feeToUse.raw,
                        currencySymbol: _currencySymbol() ?? '',
                        studentId: studentId!,
                        studentSessionId: studentSessionId,
                        studentFeesMasterId: studentFeesMasterId,
                        feeGroupsFeetypeId: feeGroupsFeetypeId,
                        studentTransportFeeId: studentTransportFeeId,
                        onSubmitted: () async {
                          await _loadFeesData();
                          if (mounted) {
                            setState(() {
                              _selectedTab = 2; // Switch to Offline Payment tab
                            });
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentModeOption({required IconData icon, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: Provider.of<AppConfigProvider>(context).primaryColorObj),
            const SizedBox(width: 16),
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Future<void> _showMultiFeePaymentDialog({Fee? singleFee}) async {
    final feesToPay = singleFee != null ? [singleFee.raw] : _selectedFees.map((f) => f.raw).toList();
    if (feesToPay.isEmpty) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => MultiFeePaymentDialog(
        feesToPay: feesToPay,
        feesData: feesData,
        studentId: studentId ?? '',
        currencySymbol: _currencySymbol() ?? '',
        onPaymentComplete: () {
          setState(() {
            _selectedFees.clear();
          });
          _loadFeesData();
        },
      ),
    );
  }

  void _showPaymentDetails(Fee fee) {
    final history = fee.paymentHistory;
    final appConfig = Provider.of<AppConfigProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   const TranslatedText('Payment Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   IconButton(
                     icon: const Icon(Icons.close, size: 20),
                     onPressed: () => Navigator.pop(context),
                     padding: EdgeInsets.zero,
                     constraints: const BoxConstraints(),
                   ),
                ],
              ),
              const SizedBox(height: 16),
              if (history.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: TranslatedText('No payment records found.'),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: history.map((record) {
                        final date = record['date'] ?? record['payment_date'] ?? '';
                        final paymentId = (record['payment_id'] ?? record['inv_no'] ?? '-').toString();
                        final mode = (record['payment_mode'] ?? record['mode'] ?? '-').toString();
                        final amount = FeeLogic.parseDouble(record['amount'] ?? record['paid'] ?? '0');
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            children: [
                              _buildPaymentHistoryRow('Date', FeeLogic.formatDate(date, context: context)),
                              const SizedBox(height: 8),
                              _buildPaymentHistoryRow('Payment ID', paymentId),
                              const SizedBox(height: 8),
                              _buildPaymentHistoryRow('Mode', mode),
                              const SizedBox(height: 8),
                              _buildPaymentHistoryRow('Amount', FeeLogic.formatAmount(appConfig.convertAmount(amount), _currencySymbol()), isBold: true),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentHistoryRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TranslatedText(label, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection() {
    return EnterpriseUIComponents.buildHeaderWithIllustration(
      title: 'Fees Management',
      subtitle: 'Manage your school fees and payments',
      illustration: Image.asset(
        'assets/images/feespage.jpeg',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildTabNavigation() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: _buildTabButton('Fees', 0, const Color(0xFFFF0000))),
          const SizedBox(width: 10),
          Expanded(child: _buildTabButton('Processing Fees', 1, const Color(0xFFFFA500))),
          const SizedBox(width: 10),
          Expanded(child: _buildTabButton('Offline Payment', 2, const Color(0xFF7CB342))),
        ],
      ),
    );
  }

  Widget _buildTabButton(String text, int index, Color color) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white, // Inactive is white
          borderRadius: BorderRadius.circular(30), // Full Pill
          border: isSelected ? null : Border.all(color: color), // Colored border when inactive? Or just grey? Let's match reference style - Solid blocks when active.
          // Reference shows distinct solid blocks. Let's stick to simple solids.
        ),
        // Wait, for inactive reference usually implies grey or outlined. 
        // Let's use Grey for inactive background to make active pop, as per plan.
        
        // REVISING based on plan: "Fees: Red background (Active), Grey (Inactive)"
        child: TranslatedText(
          text,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  // Custom Tab Button Builder - Implementing the specific logic:
  // Active: Specified Color
  // Inactive: Grey background
  Widget _buildPillTab(String text, int index, Color activeColor) {
      final isSelected = _selectedTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _selectedTab = index),
          child: Container(
             height: 45,
             alignment: Alignment.center,
             decoration: BoxDecoration(
               color: isSelected ? activeColor : const Color(0xFFF0F0F0),
               borderRadius: BorderRadius.circular(30),
             ),
             child: TranslatedText(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black54,
                  fontWeight: FontWeight.bold,
                  fontSize: 12, // Small text to fit
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
             ),
          ),
        ),
      );
  }



  Widget _buildGrandTotalCard() {
    final grandFee = feesData['grand_fee'];
    if (grandFee == null) return const SizedBox.shrink();

    final symbol = _currencySymbol();
    // Use AppConfigProvider to convert amounts based on selected currency
    final appConfig = Provider.of<AppConfigProvider>(context);
    
    final amount = appConfig.convertAmount(FeeLogic.parseDouble(grandFee['amount']));
    final discount = appConfig.convertAmount(FeeLogic.parseDouble(grandFee['amount_discount']));
    final fine = appConfig.convertAmount(FeeLogic.parseDouble(grandFee['amount_fine']));
    final paid = appConfig.convertAmount(FeeLogic.parseDouble(grandFee['amount_paid']));
    final balance = appConfig.convertAmount(FeeLogic.parseDouble(grandFee['amount_remaining']));
    final additionalFine = appConfig.convertAmount(FeeLogic.parseDouble(grandFee['fee_fine']));

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F4F4), // Light greenish/grey tint from reference
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TranslatedText(
            'Grand Total',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 16),
          // Using a Row of Columns for cleaner distribution than Table
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSummaryItem('Amount', amount, symbol),
               _buildSummaryItem('Discount', discount, symbol),
               _buildSummaryItem(
                 'Fine', 
                 fine, 
                 symbol, 
                 additionalValue: additionalFine > 0 && additionalFine < 50000 ? additionalFine : null,
               ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               _buildSummaryItem('Paid', paid, symbol),
               _buildSummaryItem('Balance', balance, symbol),
               // Spacer to balance the grid if needed, or just 2 items
               const Expanded(child: SizedBox()), 
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, double value, String? symbol, {double? additionalValue}) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
                fontFamily: 'Roboto', // Match app font
              ),
              children: [
                TextSpan(text: FeeLogic.formatAmount(value, symbol)),
                if (additionalValue != null && additionalValue > 0)
                  TextSpan(
                    text: ' +${FeeLogic.formatAmount(additionalValue, symbol)}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildContent() {
    switch (_selectedTab) {
      case 0:
        return _buildFeesTab();
      case 1:
        return _buildProcessingFeesTab();
      case 2:
        return _buildOfflinePaymentTab();
      default:
        return _buildFeesTab();
    }
  }

  Widget _buildFeesTab() {
    return RefreshIndicator(
      onRefresh: _loadFeesData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            _buildGrandTotalCard(),
            // Select All Checkbox
            if (fees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    children: [
                       Checkbox(
                          value: _isAllSelected,
                          onChanged: _toggleSelectAll,
                          activeColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                       const TranslatedText(
                         'Select All',
                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                       ),
                    ],
                  ),
                ),
              ),

            if (fees.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 50),
                child: _buildEmptyPlaceholder(message: 'No fees available'),
              )
            else
              ...fees.map((fee) => FeeCard(
                    fee: fee,
                    isSelected: _selectedFees.any((f) => f.id == fee.id),
                    onSelectedChanged: (val) => _toggleFeeSelection(fee, val),
                    onPayPressed: () => _showPaymentModeSelection(fee),
                    onViewPressed: () => _showPaymentDetails(fee),
                    currencySymbol: _currencySymbol(),
                  )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({required String message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingFeesTab() {
    return RefreshIndicator(
      onRefresh: () async {
        
        await _loadFeesData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            const TranslatedText(
              'Processing Fees',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 16),

            if (error != null && processingFees.isEmpty)
              _buildErrorStateWithRetry()
            else if (processingFees.isEmpty)
              _buildEmptyPlaceholder(message: 'No processing fees available.')
            else
              ...processingFees.map((fee) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: ProcessingFeeCard(
                  fee: fee,
                  currencySymbol: _currencySymbol(),
                ),
              )),
            ],
          ),
        ),
    );
  }

  Widget _buildErrorStateWithRetry() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Failed to load processing fees',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          if (error != null)
            Text(
              error!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              
              _loadFeesData();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1976D2),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildOfflinePaymentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // Offline Payments List
          // Offline Payments List
          if (offlinePayments.isEmpty)
            _buildEmptyPlaceholder(message: 'No offline payments available.')
          else
            ...offlinePayments.map((payment) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: OfflinePaymentCard(
                  payment: payment,
                  studentId: studentId!,
                  onUpdate: () async => _loadFeesData(),
                  currencySymbol: _currencySymbol(),
                ),
              );
            }),
        ],
      ),
    );
  }


  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Error: $error',
            style: const TextStyle(
              fontSize: 18,
              color: Colors.red,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadFeesData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}


