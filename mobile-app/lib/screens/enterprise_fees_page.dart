import 'package:flutter/material.dart';
import '../services/api/fees_api.dart';
import '../services/auth_service.dart';
import '../widgets/enterprise_ui_components.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../models/fee_model.dart';
import 'fees/widgets/multi_fee_payment_dialog.dart';
import '../widgets/translated_text.dart';

class EnterpriseFeesPage extends StatefulWidget {
  const EnterpriseFeesPage({super.key});

  @override
  State<EnterpriseFeesPage> createState() => _EnterpriseFeesPageState();
}

class _EnterpriseFeesPageState extends State<EnterpriseFeesPage> {
  int _selectedTab = 0; // 0 = Fees, 1 = Processing Fees, 2 = Offline Payment
  Map<String, dynamic> feesData = {};
  List<Fee> fees = [];
  List<ProcessingFee> processingFees = [];
  List<OfflinePayment> offlinePayments = [];
  bool isLoading = true;
  String? error;
  String? studentId;

  @override
  void initState() {
    super.initState();
    _loadFeesData();
  }

  Future<void> _loadFeesData() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      studentId = await AuthService.getStudentId();
      

      // Load all fees data in parallel using FeesApi which is model-based
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

      if (!mounted) return;

      final feesResponse = Map<String, dynamic>.from(results[0] as Map);
      final processingResponse = Map<String, dynamic>.from(results[1] as Map);
      final offlineResponse = Map<String, dynamic>.from(results[2] as Map);

      setState(() {
        feesData = feesResponse;
        fees = List<Fee>.from(feesResponse['fees'] ?? []);
        processingFees = List<ProcessingFee>.from(processingResponse['fees'] ?? []);
        offlinePayments = List<OfflinePayment>.from(offlineResponse['payments'] ?? []);
        isLoading = false;
      });
      
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        error = 'Error loading fees data: $e';
      });
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Fees'),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFeesData,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Sticky Header
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Your Fees are here!',
                    subtitle: 'Manage your fees and payments',
                    illustration: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(Icons.receipt_long, color: Colors.green[400], size: 32),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Icon(Icons.attach_money, color: Colors.orange[400], size: 20),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: EnterpriseUIComponents.buildTabBar(
                              tabs: const ['Fees', 'Processing Fees', 'Offline Payment'],
                              selectedIndex: _selectedTab,
                              onTap: (index) => setState(() => _selectedTab = index),
                              colors: [Colors.red[400]!, Colors.orange[400]!, Colors.green[400]!],
                            ),
                          ),
                          const SizedBox(height: 16),
                          if (error != null)
                            EnterpriseUIComponents.buildErrorState(
                              error: error!,
                              onRetry: _loadFeesData,
                            )
                          else
                            _buildContent(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
    return Column(
      children: [
        // Grand Total Section
        EnterpriseUIComponents.buildCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EnterpriseUIComponents.buildSectionHeader(
                title: 'Grand Total',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildTotalItem('Amount', EnterpriseUIComponents.formatCurrency(feesData['total_amount'])),
                  ),
                  Expanded(
                    child: _buildTotalItem('Discount', EnterpriseUIComponents.formatCurrency(feesData['total_discount'])),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTotalItem('Fine', EnterpriseUIComponents.formatCurrency(feesData['total_fine'])),
                  ),
                  Expanded(
                    child: _buildTotalItem('Paid', EnterpriseUIComponents.formatCurrency(feesData['total_paid'])),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildTotalItem('Balance', EnterpriseUIComponents.formatCurrency(feesData['total_balance'])),
                  ),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ],
          ),
        ),
        
        // Fees List
        if (fees.isEmpty)
          EnterpriseUIComponents.buildEmptyState(
            title: 'No Fees Found',
            message: 'There are no fees records available at the moment.',
            icon: Icons.receipt_long_outlined,
            action: ElevatedButton.icon(
              onPressed: _loadFeesData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: fees.length,
            itemBuilder: (context, index) {
              final fee = fees[index];
              return _buildFeeCard(fee);
            },
          ),
      ],
    );
  }

  Widget _buildTotalItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black54,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildFeeCard(Fee fee) {
    final feeName = fee.title;
    final amount = EnterpriseUIComponents.formatCurrency(fee.amount);
    final discount = EnterpriseUIComponents.formatCurrency(fee.discount);
    final fine = EnterpriseUIComponents.formatCurrency(fee.fine);
    final paidAmount = EnterpriseUIComponents.formatCurrency(fee.paid);
    final balanceAmount = EnterpriseUIComponents.formatCurrency(fee.balance);
    final dueDate = fee.dueDate;
    final status = fee.status;
    final feeCode = fee.code;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feeName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (feeCode.isNotEmpty)
                        Text(
                          feeCode,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                EnterpriseUIComponents.buildStatusBadge(
                  text: status,
                  color: EnterpriseUIComponents.getStatusColor(status),
                ),
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseUIComponents.buildDataRow(
                        label: 'Due Date',
                        value: dueDate,
                      ),
                    ),
                    Expanded(
                      child: EnterpriseUIComponents.buildDataRow(
                        label: 'Total Amount',
                        value: amount,
                        isImportant: true,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: EnterpriseUIComponents.buildDataRow(
                        label: 'Paid Amount',
                        value: paidAmount,
                      ),
                    ),
                    Expanded(
                      child: EnterpriseUIComponents.buildDataRow(
                        label: 'Balance Amount',
                        value: balanceAmount,
                        isImportant: true,
                        valueColor: fee.balance > 0 ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
                if (fee.discount > 0 || fee.fine > 0) ...[
                  const Divider(height: 20),
                  Row(
                    children: [
                      if (fee.discount > 0)
                        Expanded(
                          child: EnterpriseUIComponents.buildDataRow(
                            label: 'Discount',
                            value: discount,
                          ),
                        ),
                      if (fee.fine > 0)
                        Expanded(
                          child: EnterpriseUIComponents.buildDataRow(
                            label: 'Fine',
                            value: fine,
                          ),
                        ),
                    ],
                  ),
                ],
                if (fee.isPayable) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _showPaymentDialog(fee),
                      icon: const Icon(Icons.payment, size: 18),
                      label: const TranslatedText('PAY NOW'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green[600],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(Fee fee) {
    showDialog(
      context: context,
      builder: (context) => MultiFeePaymentDialog(
        feesToPay: [fee.raw],
        feesData: feesData,
        studentId: studentId!,
        currencySymbol: Provider.of<AppConfigProvider>(context, listen: false).currency,
        onPaymentComplete: _loadFeesData,
      ),
    );
  }

  Widget _buildProcessingFeesTab() {
    return Column(
      children: [
        // Header
        EnterpriseUIComponents.buildCard(
          child: const Text(
            'Your Processing Fees Details!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        
        // Processing Fees List
        if (processingFees.isEmpty)
          EnterpriseUIComponents.buildEmptyState(
            title: 'No Processing Fees',
            message: 'There are no fees currently being processed.',
            icon: Icons.hourglass_empty_outlined,
            action: ElevatedButton.icon(
              onPressed: _loadFeesData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: processingFees.length,
            itemBuilder: (context, index) {
              final fee = processingFees[index];
              return _buildProcessingFeeCard(fee);
            },
          ),
      ],
    );
  }

  Widget _buildProcessingFeeCard(ProcessingFee fee) {
    final feeName = fee.feeName;
    final amount = EnterpriseUIComponents.formatCurrency(fee.amount);
    final paymentId = fee.paymentId;
    final paymentMode = fee.paymentMode;
    final paymentDate = fee.paymentDate;
    final status = fee.status;

    return EnterpriseUIComponents.buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  feeName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              EnterpriseUIComponents.buildStatusBadge(
                text: status.toUpperCase(),
                color: EnterpriseUIComponents.getStatusColor(status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          EnterpriseUIComponents.buildDataRow(
            label: 'Fees Code',
            value: fee.feeCode,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment ID',
            value: paymentId,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment Mode',
            value: paymentMode,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment Date',
            value: paymentDate,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Amount',
            value: amount,
            isImportant: true,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Discount',
            value: EnterpriseUIComponents.formatCurrency(fee.discount),
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Fine',
            value: EnterpriseUIComponents.formatCurrency(fee.fine),
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Paid Amount',
            value: EnterpriseUIComponents.formatCurrency(fee.paidAmount),
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Balance',
            value: EnterpriseUIComponents.formatCurrency(fee.balance),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflinePaymentTab() {
    return Column(
      children: [
        // Header
        EnterpriseUIComponents.buildCard(
          child: const Text(
            'Your Offline Bank Payments is here!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        
        // Offline Payments List
        if (offlinePayments.isEmpty)
          EnterpriseUIComponents.buildEmptyState(
            title: 'No Offline Payments',
            message: 'There are no offline payment requests at the moment.',
            icon: Icons.account_balance_outlined,
            action: ElevatedButton.icon(
              onPressed: _loadFeesData,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: offlinePayments.length,
            itemBuilder: (context, index) {
              final payment = offlinePayments[index];
              return _buildOfflinePaymentCard(payment);
            },
          ),
      ],
    );
  }

  Widget _buildOfflinePaymentCard(OfflinePayment payment) {
    final requestId = payment.requestId;
    final amount = EnterpriseUIComponents.formatCurrency(payment.amount);
    final paymentDate = payment.paymentDate;
    final submitDate = payment.submitDate;
    final status = payment.status;
    final feesGroup = payment.feesGroup;
    final feesCode = payment.feesCode;
    final paymentFrom = payment.paymentFrom;
    final reference = payment.reference;
    final paymentMode = payment.paymentMode;
    final comments = payment.comments;

    return EnterpriseUIComponents.buildCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Request ID $requestId',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              EnterpriseUIComponents.buildStatusBadge(
                text: status,
                color: EnterpriseUIComponents.getStatusColor(status),
              ),
            ],
          ),
          const SizedBox(height: 16),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment Date',
            value: paymentDate,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Submit Date',
            value: submitDate,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Amount',
            value: amount,
            isImportant: true,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Approved/Rejected',
            value: payment.approved,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment ID',
            value: payment.paymentId,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Fees Group',
            value: feesGroup,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Fees Code',
            value: feesCode,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment From',
            value: paymentFrom,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Reference',
            value: reference,
          ),
          EnterpriseUIComponents.buildDataRow(
            label: 'Payment Mode',
            value: paymentMode,
          ),
          if (comments.isNotEmpty)
            EnterpriseUIComponents.buildDataRow(
              label: 'Comments',
              value: comments,
            ),
        ],
      ),
    );
  }
}
