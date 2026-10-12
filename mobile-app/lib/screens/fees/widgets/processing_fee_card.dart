import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_config_provider.dart';
import '../fee_logic.dart';
import '../../../models/fee_model.dart';
import '../../../widgets/translated_text.dart';

class ProcessingFeeCard extends StatelessWidget {
  final ProcessingFee fee;
  final String? currencySymbol;

  const ProcessingFeeCard({
    super.key,
    required this.fee,
    this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final title = fee.feeTitle;
    final code = fee.feeCode;
    final paymentId = fee.paymentId;
    final mode = fee.paymentMode;
    final date = fee.paymentDate;
    
    final amount = fee.amount;
    final discount = fee.discount;
    final fine = fee.fine;
    final proc = fee.processingFee;
    final paid = fee.paidAmount;
    final balance = fee.balance;
    final description = fee.description ?? '';

    final appConfig = Provider.of<AppConfigProvider>(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
              color: Color(0xFFFFF3E0), // Orange-ish for processing
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
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
                _buildStatusBadge(balance, paid),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Fees Code', code),
                const SizedBox(height: 12),
                if (paymentId.isNotEmpty && paymentId != '-') ...[
                   _buildDetailRow('Payment Id', paymentId),
                   const SizedBox(height: 12),
                ],
                if (mode.isNotEmpty) ...[
                   _buildDetailRow('Payment Mode', mode),
                   const SizedBox(height: 12),
                ],
                if (date.isNotEmpty) ...[
                   _buildDetailRow('Payment Date', FeeLogic.formatDate(date, context: context)),
                   const SizedBox(height: 12),
                ],

                _buildDetailRow('Amount', FeeLogic.formatAmount(appConfig.convertAmount(amount), currencySymbol)),
                const SizedBox(height: 12),
                _buildDetailRow('Discount', FeeLogic.formatAmount(appConfig.convertAmount(discount), currencySymbol)),
                const SizedBox(height: 12),
                if (fine > 0) ...[
                  _buildDetailRow('Fine', FeeLogic.formatAmount(appConfig.convertAmount(fine), currencySymbol)),
                  const SizedBox(height: 12),
                ],
                if (proc > 0) ...[
                  _buildDetailRow('Processing Fee', FeeLogic.formatAmount(appConfig.convertAmount(proc), currencySymbol)),
                  const SizedBox(height: 12),
                ],
                
                _buildDetailRow('Paid Amt', FeeLogic.formatAmount(appConfig.convertAmount(paid), currencySymbol)),
                const SizedBox(height: 12),
                _buildDetailRow('Balance', FeeLogic.formatAmount(appConfig.convertAmount(balance), currencySymbol), isBold: true),
                
                if (description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
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

  Widget _buildStatusBadge(double balance, double paid) {
    // Rule 7: Same status logic as Fees page (Rule 3)
    String text = 'Unpaid';
    Color color = const Color(0xFFE57373); // Red
    
    if (balance <= 0.001) {
      text = 'Paid';
      color = const Color(0xFF4CAF50); // Green
    } else if (paid > 0) {
      text = 'Partial';
      color = Colors.orange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
