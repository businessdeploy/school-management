import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_config_provider.dart';
import '../../utils/fee_calculator.dart';

class FeeLogic {
  static double parseDouble(dynamic value) {
    return FeeCalculator.parseAmount(value);
  }

  static String formatAmount(double amount, String? currencySymbol) {
    if (currencySymbol != null && currencySymbol.isNotEmpty) {
      return '$currencySymbol ${amount.toStringAsFixed(2)}';
    }
    return amount.toStringAsFixed(2);
  }

  static String extractFeeTitle(Map<String, dynamic> fee) {
    // Rule: Show values exactly as received from API. Resolve title from standard keys.
    String? groupName = fee['fee_group_name']?.toString() ?? 
                        fee['name']?.toString() ?? 
                        fee['group_name']?.toString();

    String? feeType = fee['type']?.toString() ?? 
                      fee['fee_type']?.toString() ?? 
                      fee['code']?.toString();

    String? month = fee['month']?.toString();

    // If it's a transport fee, we usually have a month
    if (month != null && month.isNotEmpty && month != 'null') {
       if (feeType != null && !feeType.contains(month)) {
         return '$feeType - $month';
       }
       return feeType ?? month;
    }

    if (groupName != null && feeType != null && groupName.trim() != feeType.trim()) {
       return '$groupName - $feeType';
    }

    return groupName ?? feeType ?? 'Fee Payment';
  }

  static String generateFeeUniqueId(Map<String, dynamic> fee) {
    final masterId = fee['student_fees_master_id'] ?? '';
    final feeGroupId = fee['fee_groups_feetype_id'] ?? '';
    final feeType = fee['fee_type'] ?? '';
    final feeCode = fee['fee_code'] ?? '';
    return '${masterId}_${feeGroupId}_${feeType}_$feeCode';
  }

  static String extractFieldValue(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  static String? extractFeeField(Map<String, dynamic> fee, List<String> keys) {
    for (final key in keys) {
      final value = fee[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  static String extractFeeCode(Map<String, dynamic> fee) {
    return extractFeeField(fee, [
      'code',
      'fees_code',
      'fee_code',
      'type',
    ]) ?? 'N/A';
  }

  static String offlineStatusText(Map<String, dynamic> p) {


    // 1. Check if Payment ID is generated (Strongest signal for Approval)
    // If a payment ID exists (e.g. "1255/1"), it means the request was approved and converted to a payment.
    final paymentId = p['payment_id']?.toString().trim();
    if (paymentId != null && paymentId.isNotEmpty && paymentId != '0' && paymentId != 'null') {
      return 'Approved';
    }

    // 2. Check explicit status strings
    final explicitStatus = p['status']?.toString().toLowerCase();
    final paymentStatus = p['payment_status']?.toString().toLowerCase();
    final approvalStatus = p['approval_status']?.toString().toLowerCase();

    if (explicitStatus == 'approved' || explicitStatus == '1') return 'Approved';
    if (explicitStatus == 'rejected' || explicitStatus == '2') return 'Rejected';
    
    if (paymentStatus == 'approved' || paymentStatus == 'paid' || paymentStatus == 'success' || paymentStatus == '1') return 'Approved';
    if (paymentStatus == 'rejected' || paymentStatus == 'failed' || paymentStatus == '2') return 'Rejected';

    if (approvalStatus == 'approved' || approvalStatus == '1') return 'Approved';
    if (approvalStatus == 'rejected' || approvalStatus == '2') return 'Rejected';

    if (explicitStatus == 'pending') return 'Pending';

    // 3. Check Dates
    final approveDate = p['approve_date']?.toString().trim();
    final statusDate = p['status_date']?.toString().trim();
    
    // If approve_date is present, it's definitely Approved
    if (approveDate != null && approveDate.isNotEmpty && approveDate != 'null' && approveDate != '0000-00-00') {
      return 'Approved';
    }

    // If status_date is present, it's definitely Approved
    if (statusDate != null && statusDate.isNotEmpty && statusDate != 'null' && statusDate != '0000-00-00') {
      return 'Approved';
    }

    // 4. Check is_active flag
    final isActive = p['is_active']?.toString().trim();
    final active = p['active']?.toString().trim();

    // Common logic: is_active = 0 (Pending), 1 (Approved), 2 (Rejected)
    if (isActive == '1' || active == '1') {
      return 'Approved';
    }
    
    if (isActive == '2' || active == '2') {
      return 'Rejected';
    }

    // Default to Pending if active is 0 or null (unprocessed)
    if (isActive == '0' || isActive == null || isActive == 'null' || isActive.isEmpty) {
      return 'Pending';
    }

    return 'Pending'; // Default fallback
  }

  static Color offlineStatusColor(String statusText) {
    switch (statusText.toLowerCase()) {
      case 'approved':
        return const Color(0xFF4CAF50); // Colors.green
      case 'rejected':
        return const Color(0xFFF44336); // Colors.red
      default:
        return const Color(0xFFFF9800); // Colors.orange
    }
  }

  static String formatDate(dynamic dateValue, {BuildContext? context, String? format}) {
    // Use global date format from AppConfigProvider if available, otherwise use provided format or fallback
    String dateFormat = format ?? 'dd/MM/yyyy';
    if (context != null) {
      try {
        final provider = Provider.of<AppConfigProvider>(context, listen: false);
        dateFormat = provider.dateFormat;
      } catch (e) {

      }
    }
    if (dateValue == null) return 'N/A';
    
    try {
      DateTime? parsed;

      if (dateValue is String) {
        final trimmed = dateValue.trim();
        if (trimmed.isEmpty) return 'N/A';
        
        // Try parsing ISO formats first
        parsed = DateTime.tryParse(trimmed);
        
        // Fallback: Custom parsing for common formats if DateTime.tryParse fails
        if (parsed == null) {
          if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(trimmed)) {
            final parts = trimmed.split(' ').first.split('/');
            if (parts.length == 3) {
              parsed = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
            }
          } else if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(trimmed)) {
            final parts = trimmed.split(' ').first.split('-');
            if (parts.length == 3) {
              parsed = DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
            }
          }
        }
      } else if (dateValue is DateTime) {
        parsed = dateValue;
      }

      if (parsed != null) {
        // Simple manual formatting based on the provided format string
        // Note: For full robustness, we could use the intl package's DateFormat
        // but to keep it lightweight and focused on common school system formats:
        
        String day = parsed.day.toString().padLeft(2, '0');
        String month = parsed.month.toString().padLeft(2, '0');
        String year = parsed.year.toString();

        // Rule: Follow date_format from settings API universially
        String result = dateFormat
            .toLowerCase()
            .replaceAll('yyyy', year)
            .replaceAll('yy', year.substring(year.length - 2))
            .replaceAll('mm', month)
            .replaceAll('dd', day);
        
        return result;
      }
      
      return dateValue.toString();
    } catch (e) {

      return dateValue.toString();
    }
  }

  static String? extractOfflineAttachmentUrl(Map<String, dynamic> data) {
    final attachment = data['attachment'];
    if (attachment != null && attachment.toString().trim().isNotEmpty && attachment.toString().toLowerCase() != 'null') {
      return attachment.toString().trim();
    }
    
    if (data['attachment_data'] is Map) {
      final attachmentData = data['attachment_data'] as Map;
      for (final key in ['url', 'path', 'file', 'attachment', 'file_url']) {
        final value = attachmentData[key];
        if (value != null && value.toString().trim().isNotEmpty && value.toString().toLowerCase() != 'null') {
          return value.toString().trim();
        }
      }
    }
    
    if (data['file_info'] is Map) {
      final fileInfo = data['file_info'] as Map;
      for (final key in ['url', 'path', 'file', 'attachment', 'file_url', 'attachment_url']) {
        final value = fileInfo[key];
        if (value != null && value.toString().trim().isNotEmpty && value.toString().toLowerCase() != 'null') {
          return value.toString().trim();
        }
      }
    }
    
    for (final key in [
      'file',
      'file_url',
      'attachment_url',
      'document',
      'document_url',
      'attach',
      'file_path',
      // 'image',  <-- Removed: Causes student profile photo to be shown as attachment
      // 'image_url', <-- Removed
      // 'student_image', <-- Removed
      'uploaded_file',
      'uploaded_file_url',
      'payment_attachment',
      'payment_file',
      'receipt',
      'receipt_url',
      'proof',
      'proof_url',
    ]) {
      final value = data[key];
      if (value != null && value.toString().trim().isNotEmpty && value.toString().toLowerCase() != 'null') {
        return value.toString().trim();
      }
    }
    return null;
  }

  static bool feeMatchesPayment(Map<String, dynamic> fee, Map<String, dynamic> payment) {
    final feeTransId = fee['student_transport_fee_id']?.toString();
    final paymentTransId = payment['student_transport_fee_id']?.toString();
    if (feeTransId != null && paymentTransId != null && feeTransId.isNotEmpty && feeTransId != '0') {
      return feeTransId == paymentTransId;
    }

    final feeMasterId = fee['student_fees_master_id']?.toString() ?? fee['id']?.toString();
    final paymentMasterId = payment['student_fees_master_id']?.toString() ?? payment['master_id']?.toString();

    final feeGfId = fee['fee_groups_feetype_id']?.toString();
    final paymentGfId = payment['fee_groups_feetype_id']?.toString();

    if (feeMasterId != null && paymentMasterId != null && feeGfId != null && paymentGfId != null) {
      return feeMasterId == paymentMasterId && feeGfId == paymentGfId;
    }

    if (feeMasterId != null && paymentMasterId != null && feeMasterId == paymentMasterId) {
      return true;
    }
    if (feeGfId != null && paymentGfId != null && feeGfId == paymentGfId) {
      return true;
    }

    return false;
  }

  static String resolveAttachmentUrl(String baseUrl, String url) {

    if (url.toLowerCase().startsWith('http')) return url;
    
    var cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    var path = url;
    if (path.startsWith('/')) {
      path = path.substring(1);
    }
    
    // Rule: For offline payments, they should ALWAYS be in uploads/offline_payments/
    // if not already specified with a full uploads path.
    if (path.contains('offline_payments') || path.contains('offline_bank_payments')) {
       // Extract just the filename if it's a complicated path containing these keywords
       final parts = path.split('/');
       final filename = parts.last;
       return '$cleanBase/uploads/offline_payments/$filename';
    }

    // Force offline_payments folder for filenames or partial paths
    if (!path.startsWith('uploads/')) {
       return '$cleanBase/uploads/offline_payments/$path';
    } else {
       // If it starts with uploads/ but doesn't have a subfolder, assume offline_payments
       final parts = path.split('/');
       if (parts.length == 2) {
          return '$cleanBase/uploads/offline_payments/${parts[1]}';
       } else if (parts.length > 2) {
          // If it's uploads/some/folder/file.jpg, extract filename and force offline_payments
          return '$cleanBase/uploads/offline_payments/${parts.last}';
       }
    }
    
    return '$cleanBase/$path';
  }

  static String formatDateForApi(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static List<Map<String, dynamic>> normalizeFeesList(List<Map<String, dynamic>> rawFees) {
    if (rawFees.isEmpty) return rawFees;
    final normalized = <Map<String, dynamic>>[];

    for (var entry in rawFees) {
      final feesList = entry['fees'];
      if (feesList is List && feesList.isNotEmpty) {
        for (var fee in feesList) {
          if (fee is Map) {
            final enrichedFee = Map<String, dynamic>.from(entry);
            enrichedFee.addAll(Map<String, dynamic>.from(fee));
            final groupName = entry['name'] ?? entry['fee_group_name'] ?? entry['group_name'];
            if (groupName != null) {
              enrichedFee['fee_group_name'] = groupName;
            }
            normalized.add(enrichedFee);
          }
        }
      } else {
        normalized.add(Map<String, dynamic>.from(entry));
      }
    }
    return normalized;
  }

  static List<Map<String, dynamic>> filterFeesByOfflinePayments(
    List<Map<String, dynamic>> fees,
    List<Map<String, dynamic>> offlinePayments,
  ) {
    if (offlinePayments.isEmpty) return fees;

    return fees.where((fee) {
      final matchingPayments = offlinePayments.where((payment) => feeMatchesPayment(fee, payment)).toList();
      if (matchingPayments.isEmpty) return true;

      for (final payment in matchingPayments) {
        final status = offlineStatusText(payment).toLowerCase();
        if (status == 'pending') return false;
        if (status == 'approved') {
          // Rule 1: Use backend balance directly
          final balance = parseDouble(fee['balance'] ?? 0);
          if (balance > 0) return true;
          return false;
        }
      }
      return true;
    }).toList();
  }

  static String enhancePaymentUrl(
    String baseUrl, {
    required double totalAmount,
    String? email,
    String? phone,
    String? returnUrl,
    String? processingChargeType,
    String? gatewayProcessingCharge,
    double? processingFee,
    String? discountId,
    double? discountAmount,
    double? fineAmount,
    double? baseFeeAmount,
  }) {
    if (baseUrl.isEmpty) return baseUrl;
      
    final uri = Uri.parse(baseUrl);
    final queryParams = Map<String, String>.from(uri.queryParameters);



    // Add required parameters (ONLY IF NOT PRESENT or to explicitly override)
    void safeAdd(String key, String value) {

      queryParams[key] = value;
    }

    // Always ensure amount and total match our calculated ones
    safeAdd('amount', totalAmount.toStringAsFixed(2));
    safeAdd('total', totalAmount.toStringAsFixed(2));
    
    if (email != null && email.isNotEmpty && !queryParams.containsKey('email')) {
      safeAdd('email', email);
      safeAdd('customer_email', email);
    }
    
    if (phone != null && phone.isNotEmpty && !queryParams.containsKey('phone')) {
      safeAdd('phone', phone);
      safeAdd('customer_phone', phone);
    }
    
    if (returnUrl != null && returnUrl.isNotEmpty) {
      safeAdd('return_url', returnUrl);
    }
    
    if (processingFee != null && processingFee > 0) {
      final feeStr = processingFee.toStringAsFixed(2);
      // Only set if not already set or if it's currently 0
      if (!queryParams.containsKey('processing_fee') || queryParams['processing_fee'] == '0' || queryParams['processing_fee'] == '0.00') {
        safeAdd('processing_fee', feeStr);
        safeAdd('gateway_fee', feeStr);
      }
    }
    
    // Fine handling - If fineAmount is provided, ensure it is set. If not, zero it out.
    if (fineAmount != null && fineAmount > 0) {
      final fineStr = fineAmount.toStringAsFixed(2);
      safeAdd('fine_amount', fineStr);
      safeAdd('fine', fineStr);
    } else {
      // If we don't have a fine, ensure gateway doesn't find one in the URL
      final fineKeys = ['fine_amount', 'fine', 'amount_fine', 'total_fine', 'pay_fine', 'extra_fine', 'fine_balance', 'fine_amount_balance'];
      for (final key in fineKeys) {
        if (queryParams.containsKey(key)) {
          queryParams[key] = '0';
        }
      }
    }

    if (discountId != null && discountId.isNotEmpty) {
      safeAdd('discount_id', discountId);
    }
    
    if (discountAmount != null && discountAmount > 0) {
      final distStr = discountAmount.toStringAsFixed(2);
      safeAdd('discount_amount', distStr);
    }

    final finalUrl = uri.replace(queryParameters: queryParams).toString();

    return finalUrl;
  }
}
