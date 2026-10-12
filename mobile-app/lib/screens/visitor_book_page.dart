import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:provider/provider.dart';
import '../models/visitor.dart';
import '../services/api/communication_api.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../providers/app_config_provider.dart';
import 'add_visitor_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class VisitorBookPage extends StatefulWidget {
  const VisitorBookPage({super.key});

  @override
  State<VisitorBookPage> createState() => _VisitorBookPageState();
}

class _VisitorBookPageState extends State<VisitorBookPage> {
  List<Visitor> visitors = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadVisitors();
  }

  Future<void> loadVisitors() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final studentId = await AuthService.getStudentId();
      final response = await CommunicationApi.getVisitors(studentId);

      List<dynamic> visitorItems = [];
      if (response['visitors'] != null) {
        visitorItems = response['visitors'];
      }

      if (!mounted) return;

      if (visitorItems.isEmpty) {
        setState(() {
          visitors = [];
          isLoading = false;
          errorMessage = 'No visitors found.';
        });
        return;
      }

      final convertedVisitors = visitorItems
          .map((item) => Visitor.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        visitors = convertedVisitors;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        visitors = [];
        isLoading = false;
        errorMessage = 'Failed to load visitors. Please check your internet connection and try again.';
      });
    }
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';

    // Debug raw date
    

    try {
      DateTime? date;

      // 1. Try ISO-8601 (YYYY-MM-DD)
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {}

      // 2. Try MM/dd/yyyy (US)
      if (date == null) {
        try {
          date = DateFormat('MM/dd/yyyy').parse(dateStr);
        } catch (_) {}
      }

      // 3. Try dd/MM/yyyy (UK/IN) - just in case
      if (date == null) {
        try {
          date = DateFormat('dd/MM/yyyy').parse(dateStr);
        } catch (_) {}
      }

      // If successful, format to MM/dd/yyyy
      if (date != null) {
        final formatted = DateFormat('MM/dd/yyyy').format(date);
        
        return formatted;
      }
    } catch (e) {
      
    }

    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;
    final secondaryColor = appConfigProvider.secondaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Visitor Book',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Visitor Book',
            subtitle: 'Monitor your visitor records',
            illustration: Image.asset(
              'assets/images/ic_visitors.png',
              fit: BoxFit.contain,
            ),
          ),
          // Content Section
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              TranslatedText(
                                errorMessage!,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: loadVisitors,
                                  child: const TranslatedText('Retry'),
                              ),
                            ],
                          ),
                        )
                      : visitors.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                    TranslatedText(
                                      'No visitors found',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: visitors.length,
                              itemBuilder: (context, index) {
                                return _buildVisitorCard(visitors[index], secondaryColor);
                              },
                            ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildVisitorCard(Visitor visitor, Color headerColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header with visitor name
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: headerColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: TranslatedText(
              visitor.name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Details
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Purpose', visitor.purpose),
                _buildDetailRow('Phone', visitor.contact),
                _buildDetailRow('Id Card', visitor.idProof),
                _buildDetailRow('No of Person', visitor.noOfPeople),
                _buildDetailRow('Date', _formatDate(visitor.date)),
                _buildDetailRow('In Time', visitor.inTime),
                _buildDetailRow('Out Time', visitor.outTime),
                if (visitor.note.isNotEmpty)
                  _buildDetailRow('Note', visitor.note),
                if (visitor.image.isNotEmpty)
                  _buildAttachmentRow(visitor),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: TranslatedText(
              '$label:',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: TranslatedText(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentRow(Visitor visitor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Icon(
                  Icons.attach_file,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                TranslatedText(
                  'Attachment:',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: TextButton.icon(
              onPressed: () => _openAttachment(visitor),
              icon: const Icon(Icons.download, size: 16, color: Colors.blue),
              label: TranslatedText(
                _getAttachmentFileName(visitor.image),
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.blue,
                  fontWeight: FontWeight.w400,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAttachmentFileName(String imagePath) {
    if (imagePath.isEmpty) return 'No file';
    // Extract filename from path
    final parts = imagePath.split('/');
    return parts.isNotEmpty ? parts.last : 'Attachment';
  }

  Future<void> _openAttachment(Visitor visitor) async {
    try {
      String? attachmentUrl = visitor.image;
      
      if (attachmentUrl.isEmpty || attachmentUrl == 'null' || attachmentUrl == 'NULL') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('No attachment found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Resolve full URL if needed
      String fullUrl = attachmentUrl;
      final baseUrl = await UrlManager.getBaseUrl();
      
      // Fix: If URL contains 'admin/visitors', replace it with correct path
      if (attachmentUrl.contains('admin/visitors') || attachmentUrl.contains('admin/visitor')) {
         // Extract filename: typically at the end
         final fileName = attachmentUrl.split('/').last.split('?').first;
         if (baseUrl.isNotEmpty) {
           fullUrl = '$baseUrl/uploads/front_office/visitors/$fileName';
         } else {
           // Fallback if base URL missing (unlikely)
           fullUrl = attachmentUrl.replaceFirst('admin/visitors', 'uploads/front_office/visitors');
         }
      } else if (!attachmentUrl.startsWith('http://') && !attachmentUrl.startsWith('https://')) {
        if (baseUrl.isNotEmpty) {
          // Extract filename from path
          final fileName = attachmentUrl.split('/').last.split('?').first;
          // Try common visitor attachment paths
          if (attachmentUrl.contains('visitor') && !attachmentUrl.contains('front_office')) {
             if (attachmentUrl.startsWith('/')) {
                // If it starts with slash, it might be a relative path, but we prefer our specific path
                // Check if it already has the correct folder structure
                 if (attachmentUrl.contains('uploads/front_office/visitors')) {
                     fullUrl = '$baseUrl$attachmentUrl';
                 } else {
                     fullUrl = '$baseUrl/uploads/front_office/visitors/$fileName';
                 }
             } else {
                 fullUrl = '$baseUrl/uploads/front_office/visitors/$fileName';
             }
          } else {
            // Default to uploads/front_office/visitors/
            fullUrl = '$baseUrl/uploads/front_office/visitors/$fileName';
          }
          // Remove double slashes (except in protocol)
          fullUrl = fullUrl.replaceAll(RegExp(r'(?<!:)/+'), '/');
        } else {
          fullUrl = attachmentUrl;
        }
      }

      

      // Try to launch the URL
      final uri = Uri.tryParse(fullUrl);
      if (uri != null) {
        final launched = await launchUrlString(
          fullUrl,
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          if (mounted) {
             // Fallback: try opening as is if modification failed (or vice versa)
             
             await launchUrlString(
                visitor.image,
                mode: LaunchMode.externalApplication,
             );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Invalid attachment URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Error opening attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildVisitorIllustration() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Clock
          Positioned(
            top: 10,
            left: 20,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue[300],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.blue[400]!, width: 2),
              ),
              child: Stack(
                children: [
                  // Clock numbers
                  Positioned(
                    top: 5,
                    left: 18,
                    child: Text('12', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                  ),
                  Positioned(
                    top: 18,
                    right: 5,
                    child: Text('3', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                  ),
                  Positioned(
                    bottom: 5,
                    left: 18,
                    child: Text('6', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                  ),
                  Positioned(
                    top: 18,
                    left: 5,
                    child: Text('9', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                  ),
                  // Clock hands
                  Positioned(
                    top: 20,
                    left: 19,
                    child: Container(
                      width: 2,
                      height: 8,
                      color: Colors.red[400],
                    ),
                  ),
                  Positioned(
                    top: 22,
                    left: 19,
                    child: Container(
                      width: 2,
                      height: 6,
                      color: Colors.red[400],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gears
          Positioned(
            top: 5,
            right: 10,
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: Colors.blue[200],
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Bar chart
          Positioned(
            bottom: 20,
            left: 10,
            child: Row(
              children: [
                Container(width: 4, height: 15, color: Colors.blue[300]),
                const SizedBox(width: 2),
                Container(width: 4, height: 20, color: Colors.blue[400]),
                const SizedBox(width: 2),
                Container(width: 4, height: 12, color: Colors.blue[300]),
              ],
            ),
          ),
          // Calendar
          Positioned(
            bottom: 10,
            right: 15,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.blue[300],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        topRight: Radius.circular(3),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(width: 2, height: 2, decoration: BoxDecoration(color: Colors.blue[400], shape: BoxShape.circle)),
                              Container(width: 2, height: 2, decoration: BoxDecoration(color: Colors.blue[400], shape: BoxShape.circle)),
                            ],
                          ),
                          const SizedBox(height: 1),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Container(width: 2, height: 2, decoration: BoxDecoration(color: Colors.blue[400], shape: BoxShape.circle)),
                              Container(width: 2, height: 2, decoration: BoxDecoration(color: Colors.blue[400], shape: BoxShape.circle)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Figures
          Positioned(
            bottom: 5,
            left: 5,
            child: Container(
              width: 8,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.yellow[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 5,
            child: Container(
              width: 6,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.red[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
