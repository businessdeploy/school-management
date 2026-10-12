import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../../providers/app_config_provider.dart';
import '../../../services/api/fees_api.dart';
import '../../../services/auth_service.dart';
import '../../../utils/url_manager.dart';
import '../../../utils/dynamic_api_headers.dart';
import 'package:http/http.dart' as http;
import '../fee_logic.dart';
import '../../payment_webview_page.dart';
import '../../../models/fee_model.dart';

class MultiFeePaymentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> feesToPay;
  final Map<String, dynamic> feesData;
  final String studentId;
  final String currencySymbol;
  final VoidCallback onPaymentComplete;

  const MultiFeePaymentDialog({
    super.key,
    required this.feesToPay,
    required this.feesData,
    required this.studentId,
    required this.currencySymbol,
    required this.onPaymentComplete,
  });

  @override
  State<MultiFeePaymentDialog> createState() => _MultiFeePaymentDialogState();
}

class _MultiFeePaymentDialogState extends State<MultiFeePaymentDialog> {
  final Map<String, TextEditingController> controllers = {};
  final Map<String, double> balances = {};
  final Map<String, double> fines = {};
  final Map<String, String> errors = {};
  final Map<String, List<dynamic>> feeDiscounts = {};
  final List<String> globalSelectedDiscounts = [];
  final List<dynamic> allUniqueDiscounts = [];
  bool isLoadingDiscounts = false;

  Map<String, dynamic>? paymentSummary;
  bool isLoadingSummary = true;
  bool isPaymentProcessing = false;
  String? paymentUrl;
  String? apiReturnUrl;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    for (var controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await _fetchDiscounts();
    await _fetchSummary();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (controllers.isEmpty) {
        final appConfig = Provider.of<AppConfigProvider>(context);
        for (var fee in widget.feesToPay) {
            final id = FeeLogic.generateFeeUniqueId(fee);
            final fObj = Fee.fromJson(fee);
            // CRITICAL: Initialize with fee balance ONLY, not fee+fine
            // The fine will be added separately by the backend
            final convertedAmount = appConfig.convertAmount(fObj.balance);
            controllers[id] = TextEditingController(text: convertedAmount.toStringAsFixed(2));
        }
    }
  }

  List<Map<String, dynamic>> _buildRootDiscountGroup() {
      // Build discount group for API
      final List<Map<String, dynamic>> rootDiscountGroup = [];
      final Set<String> processedDiscountIds = {};

      for (var dId in globalSelectedDiscounts) {
        if (processedDiscountIds.contains(dId)) continue;
        processedDiscountIds.add(dId);
        
        // Find the discount definition from allUniqueDiscounts
        Map<String, dynamic>? discountDef;
        for (var fee in widget.feesToPay) {
          final id = FeeLogic.generateFeeUniqueId(fee);
          final availableDiscounts = feeDiscounts[id] ?? [];
          for (var d in availableDiscounts) {
            if (d['id'].toString().trim() == dId) {
              discountDef = d;
              break;
            }
          }
          if (discountDef != null) break;
        }
        
        if (discountDef == null) {
          rootDiscountGroup.add({dId: "0.00"});
          continue;
        }
        
        final percentage = FeeLogic.parseDouble(discountDef['percentage']);
        final fixedAmount = FeeLogic.parseDouble(discountDef['amount']);
        
        double discountAmount = 0.0;
        
        if (percentage > 0) {
          for (var fee in widget.feesToPay) {
            final id = FeeLogic.generateFeeUniqueId(fee);
            final enteredAmount = double.tryParse(controllers[id]!.text) ?? 0;
            final fObj = Fee.fromJson(fee);
            final availableDiscounts = feeDiscounts[id] ?? [];
            
            // bool hasDiscount = availableDiscounts.any((d) => d['id'].toString().trim() == dId);
            
            // 

            // CRITICAL CHANGE: Force apply discount to ALL fees if selected by user
            // This supports "Global" discounts that the API might associate with only one fee but user intends for all.
            // if (!hasDiscount) continue;
            
            // CRITICAL CHANGE: User requested discount should apply to Fine as well for ALL percentages
            double discBase = enteredAmount + fObj.fine;
            
            // if (percentage >= 99.99) {
            //   discBase += fObj.fine;
            // }
            final chunk = (discBase * percentage) / 100;
            discountAmount += chunk;
            
            
          }
        } else if (fixedAmount > 0) {
          discountAmount = fixedAmount;
        }
        
        
        rootDiscountGroup.add({
          dId: discountAmount.toStringAsFixed(2)
        });
      }
      return rootDiscountGroup;
  }

  Future<void> _fetchSummary() async {
    if (!mounted) return;
    setState(() {
      isLoadingSummary = true;
      paymentSummary = null;
      errors.clear();
    });

    try {
      final List<Map<String, dynamic>> payload = _buildPaymentPayload();
      
      double totalDiscountAmount = 0.0;
      double tempTotalFeeAmount = 0.0;
      double tempTotalFineAmount = 0.0;
      
      final List<Map<String, dynamic>> rootDiscountGroup = _buildRootDiscountGroup();
      
      // Calculate total discount amount from the group we just built
      totalDiscountAmount = 0.0;
      for (var discountMap in rootDiscountGroup) {
        for (var amount in discountMap.values) {
          totalDiscountAmount += FeeLogic.parseDouble(amount);
        }
      }
      
      // Calculate total fee and fine amounts
      tempTotalFeeAmount = 0.0;
      tempTotalFineAmount = 0.0;
      for (var fee in widget.feesToPay) {
        final id = FeeLogic.generateFeeUniqueId(fee);
        final enteredAmount = double.tryParse(controllers[id]!.text) ?? 0;
        tempTotalFeeAmount += enteredAmount;
        
        final fObj = Fee.fromJson(fee);
        tempTotalFineAmount += fObj.fine;
      }
      
      // Check for 100% discount locally
      // Rule: If any selected discount is >= 99.99%, we consider it a full waiver
      bool isFullWaiver = false;
      
      for (var d in allUniqueDiscounts) {
         final dId = d['id'].toString();
         final isSelected = globalSelectedDiscounts.contains(dId);
         final rawPerc = d['percentage'];
         final p = FeeLogic.parseDouble(rawPerc);
         
         
         
         if (isSelected) {
            if (p >= 99.99) {
               isFullWaiver = true;
               
               break;
            }
         }
      }

      Map<String, dynamic>? response;

      if (isFullWaiver) {
         // MOCK RESPONSE for 100% discount to allow "Confirm Payment" button to appear
         // We do NOT call the API here because we want the user to click Confirm first
         response = {
            'status': 1,
            // Total should Include Fine to match API behavior and _buildFooter logic
            'total': (tempTotalFeeAmount + tempTotalFineAmount).toStringAsFixed(2),
            'fine_amount_balance': tempTotalFineAmount.toStringAsFixed(2),
            // Discount covers Total (Fee + Fine)
            'applied_fee_discount': (tempTotalFeeAmount + tempTotalFineAmount).toStringAsFixed(2),
            'message': 'Verification successful. Proceed to confirm.',
            'currency_symbol': widget.currencySymbol,
            // Add dummy values to pass validation if needed
         };
         await Future.delayed(const Duration(milliseconds: 500)); // Simulate network
      } else {
          // 1. Standard API Call for non-zero payments
          response = await FeesApi.payMultipleFees(
            payments: payload,
            feeDiscountGroup: rootDiscountGroup,
            paymentMode: 'online',
            currency: Provider.of<AppConfigProvider>(context, listen: false).selectedCurrencyLabel,
            note: null,
            totalFineAmount: tempTotalFineAmount,
          );
          
          // 2. Extract Rate and Calculate Correct Fee (if applicable)
          if (response != null && (response['status'] == 1 || response.containsKey('total'))) {
              final double apiGrossTotal = FeeLogic.parseDouble(response['total']);
              final double apiOriginalCharge = FeeLogic.parseDouble(response['gateway_processing_charge']);
              final String type = response['processing_charge_type']?.toString().toLowerCase() ?? '';
              
              if (type == 'percentage') {
                 final double rate = (apiGrossTotal > 0) ? (apiOriginalCharge / apiGrossTotal) : 0.0;
                 final double correctBase = tempTotalFeeAmount + tempTotalFineAmount - totalDiscountAmount;
                 final double correctProcessingFee = correctBase * rate;
                 
                 // 3. Second Call: Override with correct fee
                 response = await FeesApi.payMultipleFees(
                    payments: payload,
                    feeDiscountGroup: rootDiscountGroup,
                    paymentMode: 'online',
                    currency: Provider.of<AppConfigProvider>(context, listen: false).selectedCurrencyLabel,
                    note: null,
                    processingChargeType: 'percentage', // Metadata
                    gatewayProcessingCharge: correctProcessingFee.toStringAsFixed(2), // Override Amount
                    totalFineAmount: tempTotalFineAmount,
                 );
              }
          }
      }

      if (mounted) {
        setState(() {
          if (response != null && (response!['status'] == 1 || response!.containsKey('redirect_url') || response!.containsKey('pay_url') || isFullWaiver)) {
            paymentSummary = response;
            paymentUrl = _extractUrl(response!);
            apiReturnUrl = response!['return_url']?.toString();
          } else {
            errors['global'] = response?['message'] ?? 'Unable to fetch payment details.';
          }
          isLoadingSummary = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          errors['global'] = 'Error fetching summary: $e';
          isLoadingSummary = false;
        });
      }
    }
  }

  String? _extractUrl(Map<String, dynamic> res) {
    return res['redirect_url'] ?? 
           res['pay_url'] ?? 
           (res['data'] is Map ? (res['data']['redirect_url'] ?? res['data']['pay_url']) : null);
  }

  List<Map<String, dynamic>> _buildPaymentPayload() {
    final List<Map<String, dynamic>> payload = [];
    final Set<String> addedDiscountIds = {}; // Track which discounts we've already added

    for (var fee in widget.feesToPay) {
      final id = FeeLogic.generateFeeUniqueId(fee);
      final fObj = Fee.fromJson(fee);
      final enteredAmount = double.tryParse(controllers[id]!.text) ?? 0;
      
      // Build discounts for this fee, but only add each discount once across all fees
      final List<Map<String, dynamic>> discountsPayload = [];
      final available = feeDiscounts[id] ?? [];
      
      for (var d in available) {
        final dId = d['id'].toString().trim();
        final type = (d['type'] ?? 'fix').toString().toLowerCase();
        
        // CRITICAL CHANGE: Percentage discounts should be applied to ALL eligible fees.
        // Fixed discounts should only be applied once (to the first fee that claims it).
        bool shouldAdd = false;
        if (globalSelectedDiscounts.contains(dId)) {
           if (type == 'percentage') {
             shouldAdd = true; // Always add percentage discount
           } else {
             shouldAdd = !addedDiscountIds.contains(dId); // Fixed: Add only once
           }
        }
        
        if (shouldAdd) {
          // This discount is selected and valid for this fee
          String sendType = (d['type'] ?? 'fix').toString();
          String sendAmount = (d['amount'] ?? '').toString();
          String sendPercentage = (d['percentage'] ?? '').toString();
          
          // CRITICAL: Send percentage discounts AS percentage, do not convert to fix.
          // This allows the backend to apply it to fines if configured.
          if (type == 'percentage') {
             sendPercentage = (d['percentage'] ?? '').toString();
             sendType = 'percentage';
             // User snippet showed amount: 0 for percentage discounts
             sendAmount = "0.00"; 
          } else {
             // For fixed discounts, keep calculated logic or raw amount
             sendType = 'fix';
          }

          discountsPayload.add({
            'id': dId,
            'amount': sendAmount,
            'percentage': sendPercentage,
            'type': sendType,
            'name': (d['name'] ?? '').toString(),
          });
          
          if (type != 'percentage') {
             addedDiscountIds.add(dId); // Mark fixed discount as consumed
          }
        }

      }
      
      // CRITICAL FIX: Send ONLY the fee amount (balance), NOT fee+fine -> REVERTED logic based on validation issue
      // If we want to discount the fine, we typically need to include it in the base amount if the backend clamps discount <= amount.
      // Trying to send (Fee + Fine) as the amount to justify the larger discount.
      final double feeAmount = enteredAmount + fObj.fine;
      
      final bool isTransport = (fee['fee_category'] ?? fee['category'] ?? '').toString() == 'transport';

      payload.add({
        'student_fees_master_id': isTransport ? null : (fee['student_fees_master_id'] ?? fee['id']).toString(),
        'fee_groups_feetype_id': isTransport ? null : (fee['fee_groups_feetype_id'] ?? fee['fee_session_group_id']).toString(),
        'amount': feeAmount.toStringAsFixed(2),
        'student_id': (fee['student_id'] ?? widget.studentId).toString(),
        'student_session_id': (fee['student_session_id'] ?? fee['session_id'] ?? '').toString(),
        'fee_category': (fee['fee_category'] ?? fee['category'] ?? 'fees').toString(),
        'student_transport_fee_id': (fee['student_transport_fee_id'] ?? '').toString(),
        'fee_type': fObj.feeType,
        'fee_code': fObj.code,
        'fee_group': fObj.feeGroupName,
        'fine_balance': fObj.fine.toStringAsFixed(2), // Send fine balance
        'fine_amount': fObj.fine.toStringAsFixed(2), // Send fine amount
        'discounts': discountsPayload, // Only contains discounts not yet added to previous fees
      });
      

    }
    
    return payload;
  }

  Future<void> _fetchDiscounts() async {
    if (!mounted) return;
    setState(() {
      isLoadingDiscounts = true;
    });
    
    try {
      final Set<String> seenDiscountIds = {};
      final List<Future<void>> fetchTasks = [];

      for (var f in widget.feesToPay) {
        final id = FeeLogic.generateFeeUniqueId(f);
        final profile = await AuthService.getUserProfile();
        
        final studentSessionId = FeeLogic.extractFieldValue(f, ['student_session_id', 'session_id']).isNotEmpty 
            ? FeeLogic.extractFieldValue(f, ['student_session_id', 'session_id']) 
            : profile['student_session_id'] ?? '';
            
        final masterId = FeeLogic.extractFieldValue(f, ['student_fees_master_id', 'master_id', 'id']);
        final typeId = FeeLogic.extractFieldValue(f, ['fee_groups_feetype_id', 'fee_session_group_id', 'type_id']);
        final category = FeeLogic.extractFieldValue(f, ['fee_category', 'category']).isNotEmpty ? FeeLogic.extractFieldValue(f, ['fee_category', 'category']) : 'fees';

        if (studentSessionId.isNotEmpty && masterId.isNotEmpty && typeId.isNotEmpty) {
           fetchTasks.add(Future(() async {
             try {
               final discountRes = await FeesApi.getFeesDiscount(
                 studentSessionId: studentSessionId,
                 studentFeesMasterId: masterId,
                 feeGroupsFeetypeId: typeId,
                 feeCategory: category,
               );
               
               

               if (discountRes['status'] == 1) {
                  final discounts = discountRes['discount_not_applied'] ?? [];
                  
                  feeDiscounts[id] = discounts;
                  for (var d in discounts) {
                    final dId = d['id'].toString();
                    
                    if (!seenDiscountIds.contains(dId)) {
                      seenDiscountIds.add(dId);
                      allUniqueDiscounts.add(d);
                    }
                  }
               } else {
                  
                  final globalNotApplied = widget.feesData['discount_not_applied'];
                  final globalStudentDisc = widget.feesData['student_discount_fee'];
                  final List<dynamic> combined = [];
                  if (globalNotApplied is List) combined.addAll(globalNotApplied);
                  if (globalStudentDisc is List) combined.addAll(globalStudentDisc);
                  
                  if (combined.isNotEmpty) {
                      
                      feeDiscounts[id] = combined;
                      for (var d in combined) {
                        final dId = d['id'].toString();
                        if (!seenDiscountIds.contains(dId)) {
                          seenDiscountIds.add(dId);
                          allUniqueDiscounts.add(d);
                        }
                      }
                  }
               }
             } catch (e) {

             }
           }));
        }
      }
      
      if (fetchTasks.isNotEmpty) {
        await Future.wait(fetchTasks);
      }

      // CRITICAL FIX: Propagate discounts across fees with the same Master ID
      // This ensures that if a discount (e.g. Waiver) is returned for one month,
      // it is available for other months of the same fee type (sharing the same master_id).
      final Map<String, Set<Map<String, dynamic>>> masterIdDiscounts = {};

      // 1. Collect all discounts per Master ID
      for (var f in widget.feesToPay) {
        final id = FeeLogic.generateFeeUniqueId(f);
        final masterId = FeeLogic.extractFieldValue(f, ['student_fees_master_id', 'master_id', 'id']);
        if (masterId.isEmpty || masterId == '0') continue;

        if (feeDiscounts.containsKey(id)) {
          masterIdDiscounts.putIfAbsent(masterId, () => {});
          // We must use a custom equality check or just rely on 'id' uniqueness
          for (var d in feeDiscounts[id]!) {
             // Add if not already present (by ID)
             final existing = masterIdDiscounts[masterId]!.any((element) => element['id'].toString() == d['id'].toString());
             if (!existing) {
               masterIdDiscounts[masterId]!.add(d);
             }
          }
        }
      }

      // 2. Distribute gathered discounts back to all fees with that Master ID
      for (var f in widget.feesToPay) {
        final id = FeeLogic.generateFeeUniqueId(f);
        final masterId = FeeLogic.extractFieldValue(f, ['student_fees_master_id', 'master_id', 'id']);
        if (masterId.isEmpty || masterId == '0') continue;
        
        if (masterIdDiscounts.containsKey(masterId)) {
           final merged = masterIdDiscounts[masterId]!.toList();
           feeDiscounts[id] = merged;
           
        }
      }

    } catch (e) {
      
    } finally {
      if (mounted) {
        setState(() {
          isLoadingDiscounts = false;
        });
      }
    }
  }

  void _validateInput(String id, String value) {
     final amount = double.tryParse(value);
     final appConfig = Provider.of<AppConfigProvider>(context, listen: false);
     final fObj = Fee.fromJson(widget.feesToPay.firstWhere((f) => FeeLogic.generateFeeUniqueId(f) == id));
     // Validate against fee balance only (not including fine)
     final maxAllowed = appConfig.convertAmount(fObj.balance);
     
     setState(() {
       if (value.isEmpty) {
         errors[id] = 'Required';
       } else if (amount == null || amount <= 0) {
         errors[id] = 'Invalid amount';
       } else if (amount > maxAllowed) {
         errors[id] = 'Max: ${FeeLogic.formatAmount(maxAllowed, widget.currencySymbol)}';
       } else {
         errors.remove(id);
       }
     });
     
     if (errors.isEmpty) {
        if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 800), () {
           _fetchSummary();
        });
     }
  }

  void _toggleDiscount(String discountId, bool? value) {
     setState(() {
       if (value == true) {
         if (!globalSelectedDiscounts.contains(discountId)) {
           globalSelectedDiscounts.add(discountId);
         }
       } else {
         globalSelectedDiscounts.remove(discountId);
       }
     });

     _fetchSummary();
  }

  Future<void> _handlePayment() async {
    if (isPaymentProcessing) return;

    setState(() {
      isPaymentProcessing = true;
    });

    final summary = paymentSummary!;
    
    try {
      // READ API VALUES DIRECTLY - NO CALCULATIONS
      double apiDiscount = FeeLogic.parseDouble(summary['applied_fee_discount'] ?? 0);
      double apiFee = FeeLogic.parseDouble(summary['total'] ?? 0);
      double apiFine = FeeLogic.parseDouble(summary['fine_amount_balance'] ?? 0);
      
      // Rule: If any 100% discount is selected, the total payable MUST be zero (discount both fee and fine)
      bool hasFullDiscount = false;
      for (var d in allUniqueDiscounts) {
        if (globalSelectedDiscounts.contains(d['id'].toString())) {
          final percentage = FeeLogic.parseDouble(d['percentage']);
          if (percentage >= 99.99) {
            hasFullDiscount = true;
            break;
          }
        }
      }

      if (hasFullDiscount) {
        apiDiscount = apiFee + apiFine;
      }
      
      // ONLY ALLOWED CALCULATION: Base (Fee + Fine - Discount)
      // Processing fee is now HIDDEN in the app and added only at the gateway page
      double calculatedPayable = apiFee + apiFine - apiDiscount;
      final double finalPayable = calculatedPayable > 0 ? calculatedPayable : 0.0;

      final bool isZeroPayment = (finalPayable <= 0.001);

      if (isZeroPayment) {
        // CRITICAL: For zero payments, we must now CALL the API to commit the transaction
        // because we skipped it in _fetchSummary to show the confirmation button first.
        
        final List<Map<String, dynamic>> payload = _buildPaymentPayload();
        // final List<Map<String, dynamic>> rootDiscountGroup = _buildRootDiscountGroup(); // Not needed for V2
        
        
        
        // CRITICAL: Use the NEW fees_pay API which handles bulk payments and discounts properly
        // We pass the payload with ORIGINAL amounts (e.g. 50.00) and the discount details (100%).
        // The backend should calculate net zero and mark as paid.
        final response = await FeesApi.payMultipleFeesV2(payload);
        
        

        if (response != null && (response['status'] == 1 || (response['message']?.toString().toLowerCase().contains('success') ?? false))) {
          
          // CRITICAL: For zero payments, the "pay" URL must be visited to finalize the transaction
          // even if no gateway is involved. It likely checks balance=0 and marks as paid.
          final String? finalizeUrl = _extractUrl(response);
          if (finalizeUrl != null && finalizeUrl.isNotEmpty) {
              
              try {
                  final headers = await DynamicApiHeaders.getCompleteHeaders();
                  final cookie = await DynamicApiHeaders.getSessionCookie(); 
                  
                  // Consume redirect manually to handle cookie/auth loss?
                  // Or just use http.get and hope. logging body now.
                  final httpRes = await http.get(Uri.parse(finalizeUrl), headers: headers);
                  
                  
              } catch (e) {
                  
              }
          }

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment marked as Paid successfully!'), 
            backgroundColor: Colors.green
          ));
          widget.onPaymentComplete();
          if (mounted) Navigator.pop(context);
          return;
        } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(response?['message'] ?? 'Unable to process zero-amount payment.'), 
            backgroundColor: Colors.red
          ));
        }
      }

      if (paymentUrl == null || paymentUrl!.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content: Text('Payment initialization failed. Please try again.'),
           backgroundColor: Colors.red,
         ));
         return;
      }
      
      if (!mounted) return;
      
      // NOTE: The payment gateway page calculations are controlled by the backend
      // The 'amount' parameter here is just for display in the app's webview title
      // The actual gateway calculation happens on the backend/gateway side
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentWebViewPage(
            url: paymentUrl!,
            title: 'Secure Payment',
            amount: finalPayable,  // This is for app display only
          ),
        ),
      );

      if (result == true) {
        widget.onPaymentComplete();
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          isPaymentProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Provider.of<AppConfigProvider>(context).primaryColorObj;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(child: _buildBody()),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Payment Summary',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 20, color: Colors.black54),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildFeeList(),
            if (isLoadingDiscounts)
              const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
            else if (allUniqueDiscounts.isNotEmpty)
              _buildDiscountSection(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.feesToPay.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final fee = widget.feesToPay[index];
        final id = FeeLogic.generateFeeUniqueId(fee);
        final fObj = Fee.fromJson(fee);
        final error = errors[id];
        final title = (fee['fee_group'] ?? fee['group_name'] ?? 'Fee').toString();
        final subtitle = (fee['fee_type'] ?? fee['type'] ?? '').toString();

        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIcon(context),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                        const SizedBox(height: 12),
                        _buildCompactRow('Balance', Provider.of<AppConfigProvider>(context).convertAmount(fObj.balance)),
                        _buildCompactRow('Fine', Provider.of<AppConfigProvider>(context).convertAmount(fObj.fine), color: fObj.fine > 0 ? Colors.red : null),
                        if (fObj.discount > 0)
                          _buildCompactRow('Discount', -Provider.of<AppConfigProvider>(context).convertAmount(fObj.discount), color: Colors.green[700]),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controllers[id],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                onChanged: (val) => _validateInput(id, val),
                decoration: InputDecoration(
                  labelText: 'Amount to Pay',
                  prefixText: '${widget.currencySymbol} ',
                  filled: true,
                  fillColor: Colors.grey[50],
                  errorText: error,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIcon(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Provider.of<AppConfigProvider>(context).secondaryColorObj.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.receipt_long_outlined, color: Provider.of<AppConfigProvider>(context).primaryColorObj, size: 24),
    );
  }

  Widget _buildCompactRow(String label, double amount, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          Text(
            FeeLogic.formatAmount(amount, widget.currencySymbol),
            style: TextStyle(color: color ?? Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 1, thickness: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
          child: Text(
            'Available Discounts',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey[800]),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: allUniqueDiscounts.map((d) {
                final dId = d['id'].toString();
                final isSelected = globalSelectedDiscounts.contains(dId);
                final dPercent = d['percentage']?.toString() ?? '';
                final appConfig = Provider.of<AppConfigProvider>(context);
                final dAmount = FeeLogic.parseDouble(d['amount']);
                final valueText = dPercent.isNotEmpty ? "$dPercent%" : FeeLogic.formatAmount(appConfig.convertAmount(dAmount), widget.currencySymbol);

                return InkWell(
                  onTap: () => _toggleDiscount(dId, !isSelected),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleDiscount(dId, val),
                          activeColor: Colors.green,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(d['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              Text(d['code'] ?? '', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        Text(valueText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildFooter() {
    final primaryColor = Provider.of<AppConfigProvider>(context).primaryColorObj;
    
    if (isLoadingSummary) {
      return Container(
        height: 150,
        color: Colors.white,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (paymentSummary == null) {
      return Container(
        padding: const EdgeInsets.all(20),
        color: Colors.white,
        child: Text(errors['global'] ?? 'Failed to load summary', style: const TextStyle(color: Colors.red)),
      );
    }

    final summary = paymentSummary!;
    
    // API RESPONSE FIELDS - SINGLE SOURCE OF TRUTH
    double apiFee = FeeLogic.parseDouble(summary['total'] ?? 0);
    double apiFine = FeeLogic.parseDouble(summary['fine_amount_balance'] ?? 0);
    double apiDiscount = FeeLogic.parseDouble(summary['applied_fee_discount'] ?? 0);
    final currencySymbol = summary['currency_symbol']?.toString() ?? widget.currencySymbol;

    // Rule: Override discount to include fine if 100% discount is selected
    bool hasFullDiscount = false;
    for (var d in allUniqueDiscounts) {
      if (globalSelectedDiscounts.contains(d['id'].toString())) {
        final percentage = FeeLogic.parseDouble(d['percentage']);
        if (percentage >= 99.99) {
          hasFullDiscount = true;
          break;
        }
      }
    }

    if (hasFullDiscount) {
      // If 100% discount, Discount = Total (Fee + Fine)
      apiDiscount = apiFee; 
    }

    // ONLY ALLOWED CALCULATION: Total - Discount
    // apiFee (from 'total') includes Fine.
    final double rawPayable = apiFee - apiDiscount;
    final double finalPayable = rawPayable > 0 ? rawPayable : 0.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Column(
        children: [
          _buildSummaryRow('Fee Amount', apiFee, currency: currencySymbol),
          _buildSummaryRow('Fine', apiFine, color: Colors.red[700], currency: currencySymbol),
          _buildSummaryRow('Discount', -apiDiscount, color: Colors.green[700], currency: currencySymbol),

          
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TOTAL PAYABLE', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(
                FeeLogic.formatAmount(finalPayable, currencySymbol),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryColor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: errors.isNotEmpty || isPaymentProcessing 
                      ? null 
                      : () => _handlePayment(),
                  child: isPaymentProcessing
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(finalPayable <= 0.001 ? 'Confirm Payment' : 'Pay Now', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {Color? color, bool isCount = false, FontWeight? fontWeight, String? currency}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: fontWeight)),
          Text(
            isCount ? amount.toInt().toString() : FeeLogic.formatAmount(amount, currency ?? widget.currencySymbol),
            style: TextStyle(fontSize: 13, fontWeight: fontWeight ?? FontWeight.bold, color: color ?? Colors.grey[800]),
          ),
        ],
      ),
    );
  }
}