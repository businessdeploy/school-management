import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../utils/url_manager.dart';
import 'leave_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class LeaveListPage extends StatefulWidget {
  const LeaveListPage({super.key});

  @override
  State<LeaveListPage> createState() => _LeaveListPageState();
}

class _LeaveListPageState extends State<LeaveListPage> {
  String schoolName = '';
  String schoolLogo = '';
  bool isLoading = true;
  List<Map<String, dynamic>> leaveApplications = [];
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSchoolInfo();
    loadLeaveApplications();
  }

  Future<void> loadSchoolInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    // Use AppConfig.getAppLogo() to get dynamic logo URL with base URL
    final logoUrl = await AppConfig.getAppLogo();
    setState(() {
      schoolName = prefs.getString('site_url') ?? '';
      schoolLogo = logoUrl; // Now uses dynamic URL with base URL
    });
  }

  Future<void> loadLeaveApplications() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();

      

      final data = await ApiService.getLeaveList(studentId);

      if (!mounted) return;

      // Handle the API response structure
      List<Map<String, dynamic>> leaveList = [];

      // Check for result_array first (as per API spec)
      if (data.containsKey('result_array') && data['result_array'] is List) {
        leaveList = List<Map<String, dynamic>>.from(data['result_array']);
      } else if (data.containsKey('data') && data['data'] is List) {
        leaveList = List<Map<String, dynamic>>.from(data['data']);
      } else if (data.containsKey('leaves') && data['leaves'] is List) {
        leaveList = List<Map<String, dynamic>>.from(data['leaves']);
      } else if (data.containsKey('leave_list') && data['leave_list'] is List) {
        leaveList = List<Map<String, dynamic>>.from(data['leave_list']);
      } else if (data.isNotEmpty) {
        // If the entire response is a single leave
        leaveList = [data];
      }

      // Process the leave data to match the expected format
      final processedLeaves = leaveList.map((leave) {
        // Try multiple field name variations for dates
        final fromDate = leave['from_date'] ?? 
                         leave['leave_from_date'] ?? 
                         leave['start_date'] ?? 
                         leave['leave_from'] ?? 
                         leave['from'] ?? '';
        
        final toDate = leave['to_date'] ?? 
                       leave['leave_to_date'] ?? 
                       leave['end_date'] ?? 
                       leave['leave_to'] ?? 
                       leave['to'] ?? '';
        
        final applyDate = leave['applied_date'] ?? 
                          leave['apply_date'] ?? 
                          leave['created_at'] ?? 
                          leave['created_date'] ?? '';
        
        // Debug: Print the leave object to see what fields are available
        
        
        
        
        // Map status: API returns "0" (pending), "1" (approved), "2" (disapproved)
        final statusValue = leave['status']?.toString() ?? '0';
        
        String status;
        if (statusValue == '1') {
          status = 'Approved';
        } else if (statusValue == '2' || statusValue.toLowerCase() == 'disapproved') {
          status = 'Disapproved';
        } else {
          status = 'Pending';
        }
        
        
        // Extract attachment info from leave data (robust check)
        String attachmentUrl = (leave['attachment_url'] ?? 
                               leave['attachment'] ?? 
                               leave['attachmentLink'] ?? 
                               leave['leave_attachment'] ?? 
                               leave['file_url'] ?? 
                               leave['file'] ?? 
                               leave['document'] ?? 
                               leave['document_url'] ?? 
                               leave['leave_attachment_url'] ?? 
                               leave['attachmentPath'] ?? 
                               leave['doc'] ?? 
                               leave['userfile'] ?? 
                               leave['document_file'] ?? 
                               leave['leave_doc'] ?? 
                               leave['doc_url'] ?? 
                               leave['docs'] ?? 
                               leave['docs_url'] ?? 
                               leave['student_leave_document'] ?? '').toString();
        
        // Deep search fallback: if no attachment found in known keys, check all keys for file extensions
        if (attachmentUrl.isEmpty || attachmentUrl.toLowerCase() == 'null') {
          for (var entry in leave.entries) {
            final val = entry.value?.toString() ?? '';
            if (val.isNotEmpty && (val.contains('.jpg') || val.contains('.png') || val.contains('.pdf') || val.contains('.jpeg'))) {
              attachmentUrl = val;
              break;
            }
          }
        }
        
        final attachmentName = leave['attachment_name'] ?? 
                              leave['file_name'] ?? 
                              leave['document_name'] ?? 
                              leave['leave_attachment_name'] ?? 
                              leave['name'] ?? 
                              leave['student_leave_document_name'] ?? 
                              leave['docs'] ?? '';
        
        // Extract approver info
        final approvedBy = leave['approved_by_name'] ?? 
                           leave['approved_by'] ?? 
                           leave['staff_name'] ?? 
                           leave['approver'] ?? '';
        
        final approveDate = leave['approve_date'] ?? 
                            leave['approved_date'] ?? 
                            leave['status_date'] ?? '';

        // Robust staff ID extraction - prioritized for human-readable employee numbers
        final staffIdRaw = leave['employee_id'] ?? // Moved to top
                          leave['employee_no'] ?? 
                          leave['staff_no'] ?? 
                          leave['staff_number'] ?? 
                          leave['employee_code'] ??
                          leave['staff_employee_id'] ?? // Moved up
                          leave['staffId'] ??
                          leave['employee_id_no'] ??
                          leave['staff_id'] ?? // primary key often 1, 2 etc. moved down
                          leave['approved_by_employee_id'] ??
                          leave['approve_by'] ??
                          leave['approver_id'] ??
                          leave['approved_by_id'] ?? '';
        
        final String staffId = staffIdRaw.toString().trim();
        final bool hasStaffId = staffId.isNotEmpty && staffId.toLowerCase() != 'null';

        return {
          ...leave, // Spread all original fields FIRST
          'id': leave['id'] ?? '',
          'apply_date': _formatDate(applyDate),
          'from_date': _formatDate(fromDate),
          'to_date': _formatDate(toDate),
          'reason': leave['reason'] ?? leave['leave_reason'] ?? '',
          'status': status,
          'statusValue': statusValue,
          'statusColor': getStatusColor(status),
          'approved_by_info': hasStaffId 
              ? '${approvedBy.toString()} ($staffId)'
              : approvedBy.toString(),
          'approved_date_info': _formatDate(approveDate),
          'attachment_url': attachmentUrl.isNotEmpty ? attachmentUrl : (leave['attachment_url'] ?? ''),
          'attachment_name': attachmentName.isNotEmpty ? attachmentName : (leave['attachment_name'] ?? ''),
        };
      }).toList();

      setState(() {
        leaveApplications = processedLeaves;
        isLoading = false;
        errorMessage = null;
      });

      
      
      // Debug: Print status breakdown
      final statusCounts = <String, int>{};
      for (var leave in processedLeaves) {
        final status = leave['status'] as String;
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
      }
      
    } catch (e) {
      
      if (!mounted) return;

      setState(() {
        errorMessage = 'Error loading leave applications: $e';
        isLoading = false;
      });
    }
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'disapproved':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _deleteLeave(Map<String, dynamic> leave) async {
    final leaveId = leave['id']?.toString() ?? '';
    if (leaveId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid leave ID')),
      );
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Leave'),
        content: const Text('Are you sure you want to delete this leave application?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() {
        isLoading = true;
      });

      final response = await ApiService.deleteLeave(leaveId);

      if (!mounted) return;

      if (response['result'] == 'Success' || response['status'] == 1 || response['status'] == '1') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Leave application deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Reload leave applications
        await loadLeaveApplications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to delete leave application'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _editLeave(Map<String, dynamic> leave) async {
    // Navigate to edit page with leave data
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LeavePage(
          leaveData: leave,
        ),
      ),
    );

    // Reload if leave was updated
    if (result == true) {
      await loadLeaveApplications();
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> leave) async {
    try {
      // Get attachment URL from multiple possible keys
      String? attachmentUrl = leave['attachment_url']?.toString() ?? 
                             leave['attachment']?.toString() ?? 
                             leave['attachmentLink']?.toString() ?? 
                             leave['leave_attachment']?.toString() ?? 
                             leave['file_url']?.toString() ?? 
                             leave['document_url']?.toString() ?? 
                             leave['leave_attachment_url']?.toString();
      
      if (attachmentUrl == null || attachmentUrl.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No attachment found'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Resolve full URL if needed
      String fullUrl = attachmentUrl;
      if (!attachmentUrl.startsWith('http://') && !attachmentUrl.startsWith('https://')) {
        final baseUrl = await UrlManager.getBaseUrl();
        if (baseUrl.isNotEmpty) {
          // Extract filename from path
          final fileName = attachmentUrl.split('/').last.split('?').first;
          // Use correct path: uploads/student_leavedocuments/{filename}
          fullUrl = '$baseUrl/uploads/student_leavedocuments/$fileName';
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
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open attachment'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid attachment URL'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening attachment: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDate(String? date) {
    if (date == null || date.isEmpty || date == 'null' || date == 'NULL') {
      return 'N/A';
    }
    
    // Clean the date string (remove extra spaces, trim)
    final cleanDate = date.trim();
    
    try {
      DateTime? parsedDate;
      
      // Try parsing with DateTime.parse first (handles ISO format)
      try {
        parsedDate = DateTime.parse(cleanDate);
      } catch (e) {
        // If DateTime.parse fails, try manual parsing
      }
      
      // If DateTime.parse didn't work, try manual parsing for common formats
      if (parsedDate == null) {
        // Try YYYY-MM-DD format (most common from APIs)
        if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(cleanDate)) {
          final parts = cleanDate.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('-');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
              } catch (e) {
                
              }
            }
          }
        }
        // Try DD-MM-YYYY format
        else if (RegExp(r'^\d{2}-\d{2}-\d{4}').hasMatch(cleanDate)) {
          final parts = cleanDate.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('-');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[2]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[0]),
                );
              } catch (e) {
                
              }
            }
          }
        }
        // Try DD/MM/YYYY format
        else if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(cleanDate)) {
          final parts = cleanDate.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('/');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[2]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[0]),
                );
              } catch (e) {
                
              }
            }
          }
        }
        // Try YYYY/MM/DD format
        else if (RegExp(r'^\d{4}/\d{2}/\d{2}').hasMatch(cleanDate)) {
          final parts = cleanDate.split(' ');
          if (parts.isNotEmpty) {
            final dateParts = parts[0].split('/');
            if (dateParts.length == 3) {
              try {
                parsedDate = DateTime(
                  int.parse(dateParts[0]),
                  int.parse(dateParts[1]),
                  int.parse(dateParts[2]),
                );
              } catch (e) {
                
              }
            }
          }
        }
      }
      
      if (parsedDate != null) {
        // Format as DD/MM/YYYY (proper format)
        return '${parsedDate.day.toString().padLeft(2, '0')}/${parsedDate.month.toString().padLeft(2, '0')}/${parsedDate.year}';
      }
      
      // If parsing fails, return the original date
      
      return cleanDate;
    } catch (e) {
      
      return cleanDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText(
          'Leave List',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.grey[900],
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  EnterpriseUIComponents.buildHeaderWithIllustration(
                    title: 'Leave Application',
                    subtitle: 'Manage your leave requests',
                    illustration: Image.asset(
                      'assets/images/leavepage.jpg',
                      fit: BoxFit.contain,
                    ),
                  ),

                  // Leave Applications List
                  Expanded(
                    child: leaveApplications.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.event_busy,
                                  size: 64,
                                  color: Colors.grey,
                                ),
                                SizedBox(height: 16),
                                TranslatedText(
                                  'No leave applications found',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: leaveApplications.length,
                            itemBuilder: (context, index) {
                              final leave = leaveApplications[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 16),
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
                                    // Header - Light green background
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.green[50], // Match Student Behaviour
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(16),
                                          topRight: Radius.circular(16),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: TranslatedText(
                                              'Apply Date: ${leave['apply_date']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 15,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: leave['statusColor'],
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: TranslatedText(
                                              leave['status'],
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
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
                                                child: TranslatedText(
                                                  'From Date: ${leave['from_date'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: (leave['from_date'] == null || leave['from_date'] == '' || leave['from_date'] == 'N/A')
                                                        ? Colors.red[700]
                                                        : Colors.black87,
                                                    fontWeight: (leave['from_date'] == null || leave['from_date'] == '' || leave['from_date'] == 'N/A')
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: TranslatedText(
                                                  'To Date: ${leave['to_date'] ?? 'N/A'}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: (leave['to_date'] == null || leave['to_date'] == '' || leave['to_date'] == 'N/A')
                                                        ? Colors.red[700]
                                                        : Colors.black87,
                                                    fontWeight: (leave['to_date'] == null || leave['to_date'] == '' || leave['to_date'] == 'N/A')
                                                        ? FontWeight.w600
                                                        : FontWeight.normal,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (leave['reason'] != null &&
                                              leave['reason'].isNotEmpty) ...[
                                            const SizedBox(height: 8),
                                            TranslatedText(
                                              'Reason: ${leave['reason']}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                          // Approval Info
                                          if (leave['status'] == 'Approved') ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withOpacity(0.05),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: Colors.green.withOpacity(0.1)),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  if (leave['approved_by_info'] != null && leave['approved_by_info'].toString().isNotEmpty)
                                                    Row(
                                                      children: [
                                                        Icon(Icons.person, size: 16, color: Colors.green.shade600),
                                                        const SizedBox(width: 8),
                                                        Expanded(
                                                          child: TranslatedText(
                                                            'Approved by: ${leave['approved_by_info']}',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors.green.shade900,
                                                              fontWeight: FontWeight.w500,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  if (leave['approved_date_info'] != null && leave['approved_date_info'] != 'N/A')
                                                    Padding(
                                                      padding: const EdgeInsets.only(top: 4),
                                                      child: Row(
                                                        children: [
                                                          Icon(Icons.calendar_today, size: 14, color: Colors.green.shade600),
                                                          const SizedBox(width: 8),
                                                          Expanded(
                                                            child: TranslatedText(
                                                              'Approved date: ${leave['approved_date_info']}',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color: Colors.green.shade900,
                                                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          ...(() {
                                            final processedUrl = leave['attachment_url']?.toString() ?? '';
                                            final hasAttachment = processedUrl.isNotEmpty && processedUrl.toLowerCase() != 'null';
                                            if (hasAttachment) {
                                              return [
                                                const SizedBox(height: 12),
                                                InkWell(
                                                  onTap: () => _openAttachment(leave),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue[50],
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.blue[100]!),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.attach_file,
                                                          size: 18,
                                                          color: Colors.blue,
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Flexible(
                                                          child: TranslatedText(
                                                            (leave['attachment_name'] != null && leave['attachment_name'].toString().isNotEmpty && leave['attachment_name'].toString().toLowerCase() != 'null')
                                                                ? leave['attachment_name'].toString()
                                                                : 'View Attachment',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors.blue.shade700,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ];
                                            }
                                            return <Widget>[];
                                          })(),
                                          const SizedBox(height: 16),
                                          // Edit and Delete buttons
                                          if (leave['status'] == 'Pending' ||
                                              leave['statusValue'] == '0' ||
                                              (leave['status']?.toString().toLowerCase() ?? '').contains('pending'))
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                // Edit button
                                                InkWell(
                                                  onTap: () => _editLeave(leave),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue[50],
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.blue[200]!),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.edit, size: 18, color: Colors.blue[700]),
                                                        const SizedBox(width: 6),
                                                        TranslatedText(
                                                          'Edit',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.bold,
                                                                color: Colors.blue[700],
                                                              ),
                                                            ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                // Delete button
                                                InkWell(
                                                  onTap: () => _deleteLeave(leave),
                                                  borderRadius: BorderRadius.circular(8),
                                                  child: Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 10,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red[50],
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.red[200]!),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.delete, size: 18, color: Colors.red[700]),
                                                        const SizedBox(width: 6),
                                                        TranslatedText(
                                                          'Delete',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.red[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );                         },
                          ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LeavePage()),
          );
          // Reload leave applications if a new leave was added
          if (result == true) {
            await loadLeaveApplications();
          }
        },
        backgroundColor: Colors.blue.shade700,
        child: Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
