import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_config_provider.dart';
import '../fee_logic.dart';
import '../../../models/fee_model.dart';
import '../../../widgets/translated_text.dart';

class FeeCard extends StatelessWidget {
  final Fee fee;
  final bool isSelected;
  final ValueChanged<bool?> onSelectedChanged;
  final VoidCallback onPayPressed;
  final VoidCallback? onViewPressed;
  final String? currencySymbol;

  const FeeCard({
    super.key,
    required this.fee,
    required this.isSelected,
    required this.onSelectedChanged,
    required this.onPayPressed,
    this.onViewPressed,
    this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final areaName = fee.raw['fee_group_name'] ?? fee.feeGroupName;
    final title = areaName;
    final code = fee.feeCode;
    final dueDate = fee.dueDate;
    
    final amount = fee.amount;
    final discount = fee.discount;
    final fine = fee.fine;
    final paid = fee.paid;
    final totalPayable = fee.totalDue;
    final status = fee.status.toLowerCase();

    final isPaid = status == 'paid';
    final isPartial = status == 'partial';
    final isBalance = status == 'balance';
    final isUnpaid = status == 'unpaid' || status.isEmpty;

    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;

    // Apply currency conversion
    final displayAmount = appConfig.convertAmount(amount);
    final displayDiscount = appConfig.convertAmount(discount);
    final displayFine = appConfig.convertAmount(fine);
    final displayPaid = appConfig.convertAmount(paid);
    // Clamp negative balance to 0 (fixes issue where 100% discount + payment record = negative balance)
    final rawTotalPayable = appConfig.convertAmount(totalPayable);
    final displayTotalPayable = rawTotalPayable < 0 ? 0.0 : rawTotalPayable;

    return Container(
      margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F5E9), // Light Green header
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                if (!isPaid)
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: isSelected,
                      onChanged: (totalPayable >= 0 && !fee.hasPendingOfflinePayment) ? onSelectedChanged : null,
                      activeColor: primaryColor,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                if (!isPaid) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(isPaid, isPartial, isBalance, isUnpaid),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Fees Code', code),
                const SizedBox(height: 12),
                _buildDueDateRow(dueDate, !isPaid),
                const SizedBox(height: 12),
                _buildAmountRow(displayAmount, displayFine, currencySymbol),
                const SizedBox(height: 12),
                _buildDetailRow('Fine', FeeLogic.formatAmount(displayFine, currencySymbol)),
                const SizedBox(height: 12),
                _buildDetailRow('Discount', FeeLogic.formatAmount(displayDiscount, currencySymbol)),
                const SizedBox(height: 12),
                _buildDetailRow('Paid Amt', FeeLogic.formatAmount(displayPaid, currencySymbol)),
                const SizedBox(height: 12),
                _buildDetailRow('Balance Amt', FeeLogic.formatAmount(displayTotalPayable, currencySymbol), isBold: true),
                
                
                // Show different UI based on fee status
                if (fee.hasPendingOfflinePayment) ...[
                  // Fee has pending offline payment - show pending badge
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.pending_actions, color: Colors.orange, size: 20),
                        SizedBox(width: 8),
                        TranslatedText(
                          'Pending Approval',
                          style: TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (!isPaid) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: onPayPressed,
                      icon: const Icon(Icons.payment, size: 16), // Generic currency icon or from logic
                      label: const TranslatedText('Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7CB342), // Green Pay Button
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ] else if (isPaid) ...[
                   const SizedBox(height: 12),
                   Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: onViewPressed,
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const TranslatedText('View', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1565C0), // Blue View Button
                      ),
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isPaid, bool isPartial, bool isBalance, bool isUnpaid) {
    String text = '';
    Color color = Colors.grey;
    if (isPaid) {
      text = 'Paid';
      color = const Color(0xFF4CAF50); // Green
    } else if (isPartial) {
      text = 'Partial';
      color = Colors.orange;
    } else if (isBalance) {
      text = 'Balance';
      color = Colors.blue; 
    } else if (isUnpaid) {
      text = 'Unpaid';
      color = const Color(0xFFE57373); // Red
    }

    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: TranslatedText(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildDueDateRow(String date, bool isHighlight) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const TranslatedText(
          'Due Date',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        if (isHighlight)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFEF5350), // Red Background Bubble
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              FeeLogic.formatDate(date),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            FeeLogic.formatDate(date),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
      ],
    );
  }

  Widget _buildAmountRow(double amount, double fine, String? symbol) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const TranslatedText(
          'Amount',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14, 
              color: Colors.black87, 
              fontFamily: 'Roboto',
            ),
            children: [
              TextSpan(text: FeeLogic.formatAmount(amount, symbol)),
              if (fine > 0)
                TextSpan(
                  text: ' +${FeeLogic.formatAmount(fine, symbol)}',
                  style: const TextStyle(
                    color: Colors.red, 
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TranslatedText(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}
