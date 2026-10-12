import 'package:flutter/foundation.dart';

/// Single source of truth for fee calculations
/// 
/// ⚠️ CRITICAL RULES:
/// 1. ALL values MUST come from API responses (no static/hardcoded values)
/// 2. Fine is ONLY used if API returns fine > 0 (never defaulted or guessed)
/// 3. NO UI calculations - only use this for validation/display
/// 4. Currency conversion happens on backend - UI only displays
/// 
/// Formula: totalPayable = baseAmount + fineAmount - discountAmount + processingFee
class FeeCalculator {
  /// Calculate total payable amount
  /// 
  /// ⚠️ IMPORTANT: Fine is ONLY added if fineAmount > 0 (from API)
  /// If API returns fine = 0, null, or missing, fine is NOT added
  /// 
  /// Formula: baseAmount + fineAmount - discountAmount + processingFee
  /// 
  /// Parameters (ALL from API):
  /// - [baseAmount]: Base fee amount from API (remaining balance, excluding fine)
  /// - [fineAmount]: Fine amount from API (ONLY use if > 0)
  /// - [discountAmount]: Discount amount from API (can be 0)
  /// - [processingFee]: Processing fee from API (can be 0)
  /// 
  /// Returns: Total payable amount (never negative)
  static double calculateTotalPayable({
    required double baseAmount,
    required double fineAmount, // From API - use ONLY if > 0
    double discountAmount = 0.0,
    double processingFee = 0.0,
  }) {
    // Ensure all values are non-negative
    final base = baseAmount.clamp(0.0, double.maxFinite);
    
    // ⚠️ CRITICAL: Fine is ONLY used if API returned fine > 0
    // If API returns 0, null, or missing, fine = 0 (not added)
    final fine = (fineAmount > 0) ? fineAmount.clamp(0.0, double.maxFinite) : 0.0;
    
    final discount = discountAmount.clamp(0.0, double.maxFinite);
    final processing = processingFee.clamp(0.0, double.maxFinite);
    
    // Formula: base + fine (only if > 0) - discount + processing
    final total = (base + fine - discount + processing).clamp(0.0, double.maxFinite);
    
    // Ensure discount never exceeds (base + fine)
    final maxDiscount = (base + fine).clamp(0.0, double.maxFinite);
    if (discount > maxDiscount) {
      
      final adjustedTotal = (base + fine - maxDiscount + processing).clamp(0.0, double.maxFinite);
      return adjustedTotal;
    }
    
    return total;
  }
  
  /// Calculate due amount (balance + fine)
  /// 
  /// ⚠️ IMPORTANT: Fine is ONLY added if fineAmount > 0 (from API)
  /// 
  /// Formula: balanceAmount + fineAmount (only if fine > 0)
  /// 
  /// This is used when discount is already applied to balance
  static double calculateDueAmount({
    required double balanceAmount,
    required double fineAmount, // From API - use ONLY if > 0
  }) {
    final balance = balanceAmount.clamp(0.0, double.maxFinite);
    
    // ⚠️ CRITICAL: Fine is ONLY added if API returned fine > 0
    // If API returns 0, null, or missing, fine = 0 (not added)
    final fine = (fineAmount > 0) ? fineAmount.clamp(0.0, double.maxFinite) : 0.0;
    
    return (balance + fine).clamp(0.0, double.maxFinite);
  }
  
  /// Calculate remaining balance
  /// 
  /// Formula: baseAmount - paidAmount - discountAmount
  /// 
  /// This calculates what's left to pay (excluding fine)
  static double calculateRemainingBalance({
    required double baseAmount,
    required double paidAmount,
    double discountAmount = 0.0,
  }) {
    final base = baseAmount.clamp(0.0, double.maxFinite);
    final paid = paidAmount.clamp(0.0, double.maxFinite);
    final discount = discountAmount.clamp(0.0, double.maxFinite);
    
    return (base - paid - discount).clamp(0.0, double.maxFinite);
  }
  
  /// Validate fee amounts
  /// 
  /// Returns true if amounts are valid, false otherwise
  static bool validateAmounts({
    required double baseAmount,
    double fineAmount = 0.0,
    double discountAmount = 0.0,
    double paidAmount = 0.0,
    double processingFee = 0.0,
  }) {
    // All amounts must be non-negative
    if (baseAmount < 0 || fineAmount < 0 || discountAmount < 0 || 
        paidAmount < 0 || processingFee < 0) {
      return false;
    }
    
    // Discount cannot exceed base + fine
    final maxDiscount = (baseAmount + fineAmount).clamp(0.0, double.maxFinite);
    if (discountAmount > maxDiscount) {
      return false;
    }
    
    // Paid cannot exceed base
    if (paidAmount > baseAmount) {
      return false;
    }
    
    return true;
  }
  
  /// Parse amount from dynamic value
  /// 
  /// Safely converts any value to double
  /// Handles formats like "350.00 + 35.00" by summing both parts
  static double parseAmount(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      
      // Handle format like "350.00 + 35.00" or "350.00+35.00"
      if (trimmed.contains('+')) {
        final parts = trimmed.split('+');
        double total = 0.0;
        for (final part in parts) {
          final cleaned = part.trim().replaceAll(RegExp(r'[^0-9\.-]'), '');
          final parsed = double.tryParse(cleaned);
          if (parsed != null) {
            total += parsed;
          }
        }
        if (total > 0) {
          
          return total;
        }
      }
      
      // Standard parsing for single values
      final cleaned = trimmed.replaceAll(RegExp(r'[^0-9\.-]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }
    return 0.0;
  }
}

