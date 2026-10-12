import 'dart:convert';
import 'package:flutter/material.dart';
import '../screens/fees/fee_logic.dart';

class Fee {
  final String id;
  final String feeGroupId;
  final String feeGroupsFeetypeId;
  final String studentFeesMasterId;
  final String feeType;
  final String feeCode;
  final String feeGroupName;
  final String dueDate;
  final double amount;
  final double fine;
  final double discount;
  final double paid;
  final double balance;
  final double totalDue;
  final String? month;
  final String status; // 'Paid', 'Unpaid', 'Partial', 'Balance'
  final bool hasPendingOfflinePayment; // NEW: Flag for pending offline payment
  final Map<String, dynamic> raw;

  Fee({
    required this.id,
    required this.feeGroupId,
    required this.feeGroupsFeetypeId,
    required this.studentFeesMasterId,
    required this.feeType,
    required this.feeCode,
    required this.feeGroupName,
    required this.dueDate,
    required this.amount,
    required this.fine,
    required this.discount,
    required this.paid,
    required this.balance,
    required this.totalDue,
    this.month,
    required this.status,
    this.hasPendingOfflinePayment = false, // Default to false
    required this.raw,
  });

  factory Fee.fromJson(Map<String, dynamic> json) {
    // Generate a TRULY UNIQUE ID for the UI to prevent selection collisions
    // The API often returns the same 'id' (student_fees_master_id) for multiple installments/months
    // We must combine available IDs to create a unique key for the app.
    final studentFeesMasterIdRaw = (json['student_fees_master_id'] ?? json['id'] ?? '').toString();
    final feeGroupsFeetypeIdRaw = (json['fee_groups_feetype_id'] ?? '').toString();
    final dueDateRaw = (json['due_date'] ?? '').toString();
    final amountRaw = (json['amount'] ?? '').toString();
    
    // Composite Unique ID: MasterID_TypeID_DueDate_Amount
    // This ensures that even if MasterID collision occurs, we have other differentiators
    final id = '${studentFeesMasterIdRaw}_${feeGroupsFeetypeIdRaw}_${dueDateRaw}_$amountRaw';
    final feeGroupId = (json['fee_groups_id'] ?? json['fee_group_id'] ?? '').toString();
    final feeGroupsFeetypeId = (json['fee_groups_feetype_id'] ?? '').toString();
    final studentFeesMasterId = studentFeesMasterIdRaw;
    final feeType = (json['type'] ?? json['fee_type'] ?? '').toString();
    final feeCode = ([json['code'], json['fee_code'], json['feemaster_code']]
        .firstWhere((e) => e != null && e.toString().trim().isNotEmpty, orElse: () => 'TRANSPORT'))
        .toString();
    String feeGroupName = (json['fee_group_name'] ?? json['name'] ?? '').toString();
    final transportName = (json['transport_feemaster_name'] ?? '').toString();

    // Explicitly handle Transport Name (User requirement: Must be visible)
    if (transportName.isNotEmpty && transportName != 'null') {
      if (feeGroupName.isEmpty || feeGroupName == 'null') {
        feeGroupName = transportName;
      } else if (!feeGroupName.toLowerCase().contains(transportName.toLowerCase())) {
        feeGroupName = '$feeGroupName - $transportName';
      }
    }
    
    // Fallback if still empty
    if (feeGroupName.isEmpty || feeGroupName == 'null') {
       feeGroupName = (json['type'] ?? json['fee_type'] ?? '').toString();
    }
    
    // If we have a base name, enhance it (User requested "Full Heading")
    if (feeGroupName.isNotEmpty && feeGroupName != 'null') {
        // Append Fee Type if it exists and is different from the Group Name
        if (feeType.isNotEmpty && feeType != 'null' && !feeGroupName.toLowerCase().contains(feeType.toLowerCase())) {
             feeGroupName = '$feeGroupName - $feeType';
        }
        // Append Fee Code if it exists and is different
        if (feeCode.isNotEmpty && feeCode != 'null' && !feeGroupName.contains(feeCode)) {
             feeGroupName = '$feeGroupName ($feeCode)';
        }
    }
    
    // Final Fallback if absolutely nothing is found
    if (feeGroupName.isEmpty || feeGroupName == 'null' || feeGroupName == 'Fee Payment') {
      // Try SPECIFIC fallbacks often found in these systems
      final monthVal = (json['month'] ?? '').toString();
      final descVal = (json['description'] ?? json['remark'] ?? '').toString();
      final fineTitle = (json['fine_title'] ?? '').toString();

      if (fineTitle.isNotEmpty && fineTitle != 'null') {
         feeGroupName = fineTitle;
      } else if (monthVal.isNotEmpty && monthVal != 'null') {
         feeGroupName = '$monthVal Fees';
      } else if (descVal.isNotEmpty && descVal != 'null') {
         feeGroupName = descVal;
      } else {
         feeGroupName = 'Fee Payment';
         
      }
    }
    final dueDate = (json['due_date'] ?? '').toString();
    final month = (json['month'] ?? '').toString();

    // NEW: Handle cases like "350.00 + 50.00" in amount field
    final rawAmountStr = (
      json['amount'] ?? 
      json['fees'] ?? 
      json['total_amount'] ?? 
      json['fee_amount'] ??
      '0'
    ).toString();
    
    double baseAmountFromStr = 0;
    double fineFromAmountStr = 0;
    
    if (rawAmountStr.contains('+')) {
      final parts = rawAmountStr.split('+');
      baseAmountFromStr = FeeLogic.parseDouble(parts[0]);
      if (parts.length > 1) {
        fineFromAmountStr = FeeLogic.parseDouble(parts[1]);
      }
    } else {
      baseAmountFromStr = FeeLogic.parseDouble(rawAmountStr);
    }

    final amount = baseAmountFromStr;
    
    // SUPPORTED FINE KEYS - Prioritize Accrued amounts over Potential/Policy amounts
    final explicitFine = FeeLogic.parseDouble((
      json['amount_fine'] ?? 
      json['fine_amount'] ?? 
      json['total_amount_fine'] ?? 
      json['fee_fine'] ?? 
      '0'
    ).toString());

    // Final fine is either the one from the plus string OR the explicit field
    final fine = (explicitFine > 0) ? explicitFine : fineFromAmountStr;

    // Support multiple discount keys
    final discount = FeeLogic.parseDouble((
      json['discount_amount'] ?? 
      json['total_amount_discount'] ?? 
      json['amount_discount'] ?? 
      json['discount'] ?? 
      json['extra_discount'] ?? 
      '0'
    ).toString());

    final paid = FeeLogic.parseDouble((
      json['paid_amount'] ?? 
      json['total_amount_paid'] ?? 
      json['amount_paid'] ?? // Found in some responses
      json['paid'] ?? 
      '0'
    ).toString());
    
    // BALANCE AMOUNT from API (Primary source of truth for "Total Due")
    // Rule: Believe the backend balance first to ensure "Paid" status syncs correctly.
    double? apiBalance;
    for (final key in [
      'amount_remaining', 
      'total_amount_remaining', 
      'balance_amount', 
      'amount_balance', 
      'balance',
      'balance_amt',
      'remaining_amount',
      'due_amount'
    ]) {
      if (json.containsKey(key) && json[key] != null && json[key].toString().isNotEmpty) {
        final val = FeeLogic.parseDouble(json[key]);
        apiBalance = val;
        break;
      }
    }

    // STRICT CALCULATION (Verification)
    final expectedTotalDue = (amount + fine) - (discount + paid);
    
    // CRITICAL: Choose balance logic to match web behavior
    // USER EXPECTATION: The Balance column in the app MUST match the web admin panel.
    // Web observations: Balance column reflects (Base - Paid), EXCLUDING the fine.
    // However, when paying, the fine MUST be included.
    
    double balance;
    if (apiBalance != null) {
      // Trust the API balance to match web display
      balance = apiBalance;
    } else {
      // Fallback: match web logic (base - paid) if API doesn't provide balance
      balance = (amount - paid).clamp(0.0, double.maxFinite);
    }

    // Diagnostic log
    if (apiBalance != null && (apiBalance - expectedTotalDue).abs() > 0.01) {
      
    }

    // STRICT STATUS MAPPING (Rule 7)
    // IF balance == 0 → status = Paid
    // IF paid > 0 AND balance > 0 → status = Partial
    // IF paid == 0 → status = Unpaid
    String status = 'Unpaid';
    if (balance <= 0.001) { // Floating point safe 0
      status = 'Paid';
    } else if (paid > 0) {
      status = 'Partial';
    } else {
      status = 'Unpaid';
    }

    

    return Fee(
      id: id,
      feeGroupId: feeGroupId,
      feeGroupsFeetypeId: feeGroupsFeetypeId,
      studentFeesMasterId: studentFeesMasterId,
      feeType: feeType,
      feeCode: feeCode,
      feeGroupName: feeGroupName,
      dueDate: dueDate,
      amount: amount,
      fine: fine,
      discount: discount,
      paid: paid,
      balance: balance,
      totalDue: expectedTotalDue, // totalDue INCLUDES the fine for payment gateway logic
      month: month.isEmpty ? null : month,
      status: status,
      raw: json,
    );
  }

  String get title => feeGroupName;
  String get code => feeCode;
  bool get isPayable => totalDue > 0;

  /// Payment History Extractor
  /// Parses 'amount_detail' from raw JSON to get individual transaction records
  List<Map<String, dynamic>> get paymentHistory {
    final detail = raw['amount_detail'];
    if (detail == null) return [];
    
    try {
      if (detail is String) {
        if (detail.trim().isEmpty || detail == 'null') return [];
        final parsed = jsonDecode(detail);
        if (parsed is List) return List<Map<String, dynamic>>.from(parsed);
        if (parsed is Map) {
           // If it's a map with numeric keys, convert to list
           if (parsed.keys.every((k) => int.tryParse(k.toString()) != null)) {
             return parsed.values.map((e) => Map<String, dynamic>.from(e)).toList();
           }
           return [Map<String, dynamic>.from(parsed)];
        }
      } else if (detail is List) {
        return List<Map<String, dynamic>>.from(detail);
      } else if (detail is Map) {
        if (detail.keys.every((k) => int.tryParse(k.toString()) != null)) {
           return detail.values.map((e) => Map<String, dynamic>.from(e)).toList();
        }
        return [Map<String, dynamic>.from(detail)];
      }
    } catch (e) {
      
    }
    return [];
  }
}

class ProcessingFee {
  final String id;
  final String feeTitle;
  final String feeCode;
  final String paymentId;
  final String paymentMode;
  final String paymentDate;
  final double amount;
  final double discount;
  final double fine;
  final double processingFee;
  final double paidAmount;
  final double balance;
  final String status; // Usually "PROCESSING"
  final String? description;
  final Map<String, dynamic> raw;

  ProcessingFee({
    required this.id,
    required this.feeTitle,
    required this.feeCode,
    required this.paymentId,
    required this.paymentMode,
    required this.paymentDate,
    required this.amount,
    required this.discount,
    required this.fine,
    required this.processingFee,
    required this.paidAmount,
    required this.balance,
    required this.status,
    this.description,
    required this.raw,
  });

  factory ProcessingFee.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> amountDetail = {};
    if (json['amount_detail'] != null) {
      try {
        if (json['amount_detail'] is String && json['amount_detail'].toString().isNotEmpty) {
          amountDetail = jsonDecode(json['amount_detail']);
        } else if (json['amount_detail'] is Map) {
          amountDetail = Map<String, dynamic>.from(json['amount_detail']);
        }
      } catch (_) {}
    }

    final amount = FeeLogic.parseDouble(amountDetail['amount'] ?? json['amount'] ?? '0');
    final discount = FeeLogic.parseDouble(amountDetail['amount_discount'] ?? json['amount_discount'] ?? json['discount'] ?? '0');
    final fine = FeeLogic.parseDouble(amountDetail['amount_fine'] ?? json['amount_fine'] ?? json['fine'] ?? '0');
    final proc = FeeLogic.parseDouble(amountDetail['gateway_processing_charge'] ?? json['gateway_processing_charge'] ?? json['processing_fee'] ?? '0');
    final paid = FeeLogic.parseDouble(json['amount_paid'] ?? json['paid_amount'] ?? amount);
    final bal = FeeLogic.parseDouble(json['amount_balance'] ?? json['balance_amount'] ?? '0');

    return ProcessingFee(
      id: (json['id'] ?? json['unique_id'] ?? '').toString(),
      feeTitle: (json['fee_group_name'] ?? json['name'] ?? 'Fee Payment').toString(),
      feeCode: (json['code'] ?? json['fee_code'] ?? '').toString(),
      paymentId: (json['payment_id'] ?? json['unique_id'] ?? '').toString(),
      paymentMode: (json['payment_mode'] ?? amountDetail['payment_mode'] ?? '').toString(),
      paymentDate: (json['payment_date'] ?? json['date'] ?? amountDetail['date'] ?? '').toString(),
      amount: amount,
      discount: discount,
      fine: fine,
      processingFee: proc,
      paidAmount: paid,
      balance: bal,
      status: 'PROCESSING',
      description: amountDetail['description']?.toString(),
      raw: json,
    );
  }

  String get feeName => feeTitle;
}

class OfflinePayment {
  final String id;
  final String feeTitle;
  final String feesGroup;
  final String feesCode;
  final String paymentDate;
  final String submitDate;
  final double amount;
  final String requestId;
  final String paymentId;
  final String paymentFrom;
  final String paymentMode;
  final String reference;
  final String status; // Approved, Rejected, Pending
  final String approved; // approved, rejected, or empty
  final String approveDate;
  final String? attachment;
  final String? description;
  final String studentFeesMasterId;
  final String feeGroupsFeetypeId;
  final String studentTransportFeeId;
  final Map<String, dynamic> raw;

  OfflinePayment({
    required this.id,
    required this.requestId,
    required this.feeTitle,
    required this.feesGroup,
    required this.feesCode,
    required this.paymentDate,
    required this.submitDate,
    required this.amount,
    required this.paymentId,
    required this.paymentFrom,
    required this.paymentMode,
    required this.reference,
    required this.status,
    required this.approved,
    required this.approveDate,
    this.attachment,
    this.description,
    required this.studentFeesMasterId,
    required this.feeGroupsFeetypeId,
    required this.studentTransportFeeId,
    required this.raw,
  });

  factory OfflinePayment.fromJson(Map<String, dynamic> json) {
    // Status resolution logic
    String status = 'Pending';
    final paymentId = json['payment_id']?.toString().trim() ?? '';
    final isActive = json['is_active']?.toString().trim() ?? '0';
    final explicitStatus = json['status']?.toString().toLowerCase().trim() ?? '';
    final paymentStatus = json['payment_status']?.toString().toLowerCase().trim() ?? '';
    final approvalStatus = json['approval_status']?.toString().toLowerCase().trim() ?? '';
    final approveDate = json['approve_date']?.toString().trim() ?? '';
    final statusDate = json['status_date']?.toString().trim() ?? '';
    
    // 1. Check explicit status strings (Strongest signal)
    if (explicitStatus == 'approved' || explicitStatus == '1' || isActive == '1' || 
               paymentStatus == 'approved' || paymentStatus == 'success' || paymentStatus == '1' ||
               approvalStatus == 'approved' || approvalStatus == '1') {
      status = 'Approved';
    } 
    // 2. Check Rejected states
    else if (explicitStatus == 'rejected' || explicitStatus == '2' || isActive == '2' ||
               paymentStatus == 'rejected' || paymentStatus == 'failed' || paymentStatus == '2' ||
               approvalStatus == 'rejected' || approvalStatus == '2') {
      status = 'Rejected';
    } 
    // 3. Check if Payment ID is generated (Secondary signal for Approval)
    else if (paymentId.isNotEmpty && paymentId != '0' && paymentId != 'null') {
      status = 'Approved';
    } 
    // 4. Check Dates - if approved date OR status date is present, it's usually approved
    else if ((approveDate.isNotEmpty && approveDate != 'null' && approveDate != '0000-00-00') ||
             (statusDate.isNotEmpty && statusDate != 'null' && statusDate != '0000-00-00')) {
      status = 'Approved';
    }

    // Robust attachment extraction
    String? attachmentUrl;
    // 1. Check known keys
    for (final key in ['attachment', 'file', 'document', 'proof', 'receipt', 'image', 'upload', 'path']) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        attachmentUrl = json[key].toString();
        break;
      }
    }
    
    // 2. Fallback: Scan for file extensions if still not found
    if (attachmentUrl == null || attachmentUrl.isEmpty) {
      for (final val in json.values) {
        final str = val.toString();
        if (str.length > 4 && (str.endsWith('.jpg') || str.endsWith('.png') || str.endsWith('.pdf') || str.endsWith('.jpeg'))) {
          attachmentUrl = str;
          break;
        }
      }
    }

    return OfflinePayment(
      id: (json['id'] ?? '').toString(),
      requestId: (json['request_id'] ?? json['id'] ?? '').toString(),
      feeTitle: (json['fee_group_name'] ?? 
                 json['fee_type'] ?? 
                 json['type'] ?? 
                 json['name'] ?? 
                 json['fee_category'] ?? 
                 json['transport_feemaster_name'] ?? 
                 ((json['amount'] != null) ? 'Fee Payment (${json['amount']})' : 'Fee Payment')
                ).toString(),
      feesGroup: (json['fee_group_name'] ?? '').toString(),
      feesCode: (json['code'] ?? '').toString(),
      paymentDate: (json['payment_date'] ?? '').toString(),
      submitDate: (json['submit_date'] ?? '').toString(),
      amount: FeeLogic.parseDouble(json['amount'] ?? '0'),
      paymentId: paymentId,
      paymentFrom: (json['bank_account_transferred'] ?? json['payment_from'] ?? '').toString(),
      paymentMode: (json['bank_from'] ?? json['payment_mode'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      status: status,
      approved: (json['approved_rejected'] ?? json['approved'] ?? json['status'] ?? '').toString(),
      approveDate: approveDate,
      attachment: attachmentUrl,
      description: (json['description'] ?? json['reply'] ?? json['note'] ?? '').toString(),
      studentFeesMasterId: (json['student_fees_master_id'] ?? '').toString(),
      feeGroupsFeetypeId: (json['fee_groups_feetype_id'] ?? '').toString(),
      studentTransportFeeId: (json['student_transport_fee_id'] ?? '').toString(),
      raw: json,
    );
  }

  String get comments => description ?? '';
}

class BalanceFee {
  final double balance;
  final List<FeeDiscount> discountsApplied;
  final List<FeeDiscount> discountsNotApplied;
  final double remainAmountFine;
  final double studentFees;

  BalanceFee({
    required this.balance,
    required this.discountsApplied,
    required this.discountsNotApplied,
    required this.remainAmountFine,
    required this.studentFees,
  });

  factory BalanceFee.fromJson(Map<String, dynamic> json) {
    final res = json['result_array'] ?? json;
    
    var applied = <FeeDiscount>[];
    if (res['discount_fee'] is List) {
      applied = (res['discount_fee'] as List).map((e) => FeeDiscount.fromJson(e)).toList();
    }

    var notApplied = <FeeDiscount>[];
    if (res['discount_not_applied'] is List) {
      notApplied = (res['discount_not_applied'] as List).map((e) => FeeDiscount.fromJson(e)).toList();
    }

    return BalanceFee(
      balance: FeeLogic.parseDouble(res['balance'] ?? '0'),
      discountsApplied: applied,
      discountsNotApplied: notApplied,
      remainAmountFine: FeeLogic.parseDouble(res['remain_amount_fine'] ?? '0'),
      studentFees: FeeLogic.parseDouble(res['student_fees'] ?? '0'),
    );
  }
}

class FeeDiscount {
  final String id;
  final String name;
  final String code;
  final double amount;
  final String type; // fix, percentage

  FeeDiscount({
    required this.id,
    required this.name,
    required this.code,
    required this.amount,
    required this.type,
  });

  factory FeeDiscount.fromJson(Map<String, dynamic> json) {
    return FeeDiscount(
      id: (json['fees_discount_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      code: (json['code'] ?? '').toString(),
      amount: FeeLogic.parseDouble(json['amount'] ?? '0'),
      type: (json['type'] ?? 'fix').toString(),
    );
  }
}
