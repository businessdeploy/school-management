import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../../pdf_viewer_page.dart';
import '../../document_viewer_page.dart';
import '../../../utils/url_manager.dart';
import '../fee_logic.dart';
import '../../../models/fee_model.dart';
import 'package:provider/provider.dart';
import '../../../providers/app_config_provider.dart';
import '../../offline_payment_page.dart';
import '../../../widgets/translated_text.dart';

class OfflinePaymentCard extends StatelessWidget {
  final OfflinePayment payment;
  final String? currencySymbol;
  final String studentId;
  final Future<void> Function() onUpdate;

  const OfflinePaymentCard({
    super.key,
    required this.payment,
    required this.studentId,
    required this.onUpdate,
    this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final title = payment.feeTitle;
    final statusText = payment.status;
    final statusColor = FeeLogic.offlineStatusColor(statusText);
    final attachmentUrl = payment.attachment;
    final description = payment.description ?? '';

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OfflinePaymentPage(
              fee: payment.raw,
              currencySymbol: currencySymbol ?? '',
              studentId: studentId,
              studentSessionId: (payment.raw['student_session_id'] ?? '').toString(),
              studentFeesMasterId: (payment.raw['student_fees_master_id'] ?? payment.raw['student_fee_master_id'] ?? '').toString(),
              feeGroupsFeetypeId: (payment.raw['fee_groups_feetype_id'] ?? payment.raw['fee_session_group_id'] ?? '').toString(),
              studentTransportFeeId: (payment.raw['student_transport_fee_id'] ?? '').toString(),
              onSubmitted: onUpdate,
              existingPayment: payment.raw,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20, left: 20, right: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
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
              decoration: BoxDecoration(
                color: const Color(0xFFE1F5FE), // Blue-ish for offline
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (payment.paymentDate.isNotEmpty)
                    _buildDetailRow('Payment Date', FeeLogic.formatDate(payment.paymentDate, context: context)),
                  if (payment.submitDate.isNotEmpty)
                    const SizedBox(height: 8),
                  if (payment.submitDate.isNotEmpty)
                    _buildDetailRow('Submit Date', FeeLogic.formatDate(payment.submitDate, context: context)),
                  
                  const SizedBox(height: 8),
                  // Apply numeric conversion for display
                  _buildDetailRow('Amount', FeeLogic.formatAmount(Provider.of<AppConfigProvider>(context).convertAmount(payment.amount), currencySymbol), isBold: true),

                  if (payment.feesGroup.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Fee Group', payment.feesGroup),
                  ],
                  
                  if (payment.feesCode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Fees Code', payment.feesCode),
                  ],

                  if (payment.paymentFrom.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Payment From', payment.paymentFrom),
                  ],
                  
                  if (payment.paymentMode.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Payment Mode', payment.paymentMode),
                  ],

                  if (payment.reference.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildDetailRow('Reference', payment.reference),
                  ],
                  
                  const SizedBox(height: 8),
                  _buildDetailRow('Description', description.isNotEmpty ? description : '—'),

                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildAttachmentRow(context, attachmentUrl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentRow(BuildContext context, String? attachmentUrl) {
    return Row(
      children: [
        const Icon(Icons.file_present, color: Colors.blue, size: 20),
        const SizedBox(width: 8),
        const Expanded(
          child: TranslatedText(
            'Attachment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
        if (attachmentUrl != null && attachmentUrl.isNotEmpty)
          TextButton.icon(
            onPressed: () async {
              final baseUrl = await UrlManager.getBaseUrl();
              final url = FeeLogic.resolveAttachmentUrl(baseUrl, attachmentUrl);


              // Determine name from URL or fallback
              final name = 'Attachment';

              if (url.toLowerCase().endsWith('.pdf')) {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PDFViewerPage(
                      documentUrl: url,
                      documentTitle: name,
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DocumentViewerPage(
                      documentUrl: url,
                      documentTitle: name,
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.download, size: 18),
            label: const TranslatedText('View', style: TextStyle(fontWeight: FontWeight.bold)),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          )
        else
          const Text(
            '—',
            style: TextStyle(color: Colors.grey, fontSize: 14),
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
