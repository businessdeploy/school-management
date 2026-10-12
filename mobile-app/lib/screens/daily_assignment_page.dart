import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../models/daily_assignment.dart';
import '../utils/url_manager.dart';
import '../widgets/responsive_body.dart';
import '../providers/app_config_provider.dart';
import 'login_page.dart';
import 'add_edit_daily_assignment_page.dart';
import 'pdf_viewer_page.dart';
import 'document_viewer_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class DailyAssignmentPage extends StatefulWidget {
  const DailyAssignmentPage({super.key});

  @override
  State<DailyAssignmentPage> createState() => _DailyAssignmentPageState();
}

class _DailyAssignmentPageState extends State<DailyAssignmentPage> {
  List<DailyAssignment> assignmentList = [];
  List<DailyAssignment> originalAssignmentList = [];
  bool isLoading = true;
  String? errorMessage;
  DateTime selectedDate = DateTime.now();
  bool _isDeleteLoaderVisible = false;

  @override
  void initState() {
    super.initState();
    loadDailyAssignments();
  }

  Future<void> loadDailyAssignments() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final userProfile = await AuthService.getUserProfile();
      String studentId = userProfile['student_id'] ?? '';

      if (studentId.isEmpty) {
        final userId = userProfile['user_id'];
        if (userId != null && userId.isNotEmpty) {
          studentId = userId;
        } else {
          // Get dynamic student ID from authentication service
          studentId = await AuthService.getStudentId();
        }
      }

      List<DailyAssignment> assignmentItems = [];

      try {
        final token = await AuthService.getToken();
        if (token == null || token.isEmpty) {
          throw Exception('User not authenticated. Please login again.');
        }

        final data = await ApiService.getDailyAssignments(studentId);

        
        
        
        

        if (data['dailyassignment'] != null) {
          final List<dynamic> rawList = data['dailyassignment'];
          
          
          // CRITICAL: Load ALL assignments from API (no filtering, no limiting)
          // Do NOT filter only latest record - show all historical assignments
          assignmentItems = rawList
              .map((item) => DailyAssignment.fromJson(item))
              .toList();
          
          
          
          // Log assignment IDs to verify all are loaded
          for (final assignment in assignmentItems) {
            
          }
        } else {
          
          // Check for alternative response keys
          for (final key in ['assignments', 'data', 'result', 'list']) {
            if (data[key] != null && data[key] is List) {
              final altList = data[key] as List<dynamic>;
              
              assignmentItems = altList
                  .map((item) => DailyAssignment.fromJson(item))
                  .toList();
              break;
            }
          }
        }
      } catch (e) {
        

        if (e.toString().contains('not authenticated') ||
            e.toString().contains('login')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const TranslatedText(
                  'Authentication failed. Please login again.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'Login',
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginPageUI(),
                      ),
                      (route) => false,
                    );
                  },
                ),
              ),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load assignments: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        }
        rethrow;
      }

      final processedAssignments =
          _sortAssignments(_deduplicateAssignments(assignmentItems));

      setState(() {
        assignmentList = processedAssignments;
        originalAssignmentList = processedAssignments;
        isLoading = false;
        errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Error loading assignments: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appConfigProvider = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfigProvider.primaryColorObj;
    final secondaryColor = appConfigProvider.secondaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Daily Assignment',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor, // Dynamic primary color
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewAssignment,
        backgroundColor: primaryColor, // Dynamic primary color
        foregroundColor: Colors.white,
        tooltip: 'Add New Assignment',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Sticky Illustration Header
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Your Daily Assignment!',
            subtitle: 'Stay on top of your daily tasks',
            illustration: Image.asset(
              "assets/images/assignmentpage.jpg",
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _buildAssignmentIllustration(),
            ),
          ),

          // Main white card with full width
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: isLoading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          TranslatedText(
                            'Loading assignments...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : assignmentList.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              const TranslatedText(
                                'No assignments found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TranslatedText(
                                'Check back later for new assignments',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 20, right: 20, top: 0, bottom: 16),
                          itemCount: assignmentList.length,
                          itemBuilder: (context, index) {
                            final assignment = assignmentList[index];
                            return _buildAssignmentCard(
                                assignment, secondaryColor);
                          },
                        ),
            ),
          ),
        ],
      ),
);
  }

  Widget _buildAssignmentIllustration() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Stack(
        children: [
          // Large yellow pencil
          Positioned(
            right: 0,
            top: 5,
            child: Container(
              width: 12,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.yellow[600],
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          // Pencil tip (black)
          Positioned(
            right: -2,
            top: 3,
            child: Container(
              width: 16,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          // Pencil eraser (pink)
          Positioned(
            right: 0,
            bottom: 3,
            child: Container(
              width: 12,
              height: 8,
              decoration: BoxDecoration(
                color: Colors.pink[300],
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          // Person figure (blue jacket, dark pants, raised hand)
          Positioned(
            left: 10,
            bottom: 5,
            child: SizedBox(
              width: 20,
              height: 30,
              child: Stack(
                children: [
                  // Body (blue jacket)
                  Positioned(
                    left: 4,
                    top: 8,
                    child: Container(
                      width: 12,
                      height: 15,
                      decoration: BoxDecoration(
                        color: Colors.blue[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Head
                  Positioned(
                    left: 6,
                    top: 0,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.brown[300],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  // Raised hand
                  Positioned(
                    right: 0,
                    top: 10,
                    child: Container(
                      width: 4,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.brown[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Legs (dark pants)
                  Positioned(
                    left: 5,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    bottom: 0,
                    child: Container(
                      width: 3,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Clipboard with checkmarks
          Positioned(
            left: 0,
            top: 10,
            child: Container(
              width: 24,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.grey[400]!, width: 1.5),
              ),
              child: Stack(
                children: [
                  // Red clip at top
                  Positioned(
                    top: 1,
                    left: 10,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.red[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Checklist lines with red checkmarks
                  ...List.generate(4, (index) {
                    return Positioned(
                      left: 4,
                      top: 8 + (index * 5),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 1.5,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 3),
                          Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.red[600],
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentCard(DailyAssignment assignment, Color headerColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white, // White background inside
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header strip with subject name and action buttons
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: headerColor, // Dynamic secondary color
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${assignment.subjectName} (${assignment.subjectCode})',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _editAssignment(assignment),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteAssignment(assignment),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        child: const Icon(
                          Icons.delete,
                          size: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Content section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Title', assignment.title),
                _buildInfoRow('Submission Date', assignment.formattedDate),
                
                if (assignment.formattedEvaluationDate.isNotEmpty)
                  _buildInfoRow('Evaluation Date', assignment.formattedEvaluationDate),
                  
                if (assignment.remark.isNotEmpty)
                  _buildInfoRow('Remark', assignment.remark),

                if (assignment.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const TranslatedText(
                    'Description:',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    assignment.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ],
                
                if (_hasAttachment(assignment)) ...[
                  const SizedBox(height: 16),
                  _buildAttachmentTile(assignment),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = math.min(110.0, constraints.maxWidth * 0.35);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: TranslatedText(
                  '$label:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 10,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editAssignment(DailyAssignment assignment) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddEditDailyAssignmentPage(assignment: assignment),
      ),
    );
    if (result == true) {
      loadDailyAssignments();
    }
  }

  void _deleteAssignment(DailyAssignment assignment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Delete Assignment'),
        content: TranslatedText('Are you sure you want to delete "${assignment.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close confirmation dialog

              _showDeleteLoadingDialog();

              try {
                

                // Validate assignment ID
                if (assignment.id.isEmpty || assignment.id.trim().isEmpty) {
                  _hideDeleteLoadingDialog();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Invalid assignment ID. Please refresh the list and try again.',
                        ),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                  return;
                }

                final studentId = await AuthService.getStudentId();
                
                

                final result = await ApiService.deleteDailyAssignment(
                  assignment.id.trim(),
                  studentId: studentId,
                  studentSessionId: assignment.studentSessionId,
                );

                

                // Dismiss loading dialog
                _hideDeleteLoadingDialog();

                final dynamic status = result['status'];
                final bool isSuccess =
                    status == '1' || status == 1 || status == true;

                if (isSuccess) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['msg'] ?? 'Assignment deleted successfully',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                  // Reload assignments list
                  if (mounted) {
                    await loadDailyAssignments();
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          result['msg'] ?? 'Failed to delete assignment',
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } catch (e) {
                

                // Dismiss loading dialog if still showing
                _hideDeleteLoadingDialog();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Error deleting assignment: ${e.toString()}',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                      action: SnackBarAction(
                        label: 'Retry',
                        textColor: Colors.white,
                        onPressed: () {
                          _deleteAssignment(assignment);
                        },
                      ),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const TranslatedText('Delete'),
          ),
        ],
      ),
    );
  }

  void _addNewAssignment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const AddEditDailyAssignmentPage(assignment: null),
      ),
    );
    if (result == true) {
      loadDailyAssignments();
    }
  }

  void _showDeleteLoadingDialog() {
    if (!mounted || _isDeleteLoaderVisible) return;
    _isDeleteLoaderVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WillPopScope(
        onWillPop: () async => false,
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const TranslatedText(
                  'Deleting assignment...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).whenComplete(() {
      _isDeleteLoaderVisible = false;
    });
  }

  void _hideDeleteLoadingDialog() {
    if (!_isDeleteLoaderVisible) return;
    if (!mounted) {
      _isDeleteLoaderVisible = false;
      return;
    }
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  List<DailyAssignment> _deduplicateAssignments(
    List<DailyAssignment> assignments,
  ) {
    final Map<String, DailyAssignment> uniqueAssignments = {};
    final List<DailyAssignment> fallbackAssignments = [];

    for (final assignment in assignments) {
      final id = assignment.id.trim();
      if (id.isEmpty) {
        fallbackAssignments.add(assignment);
      } else {
        uniqueAssignments[id] = assignment;
      }
    }

    // Preserve insertion order for unique IDs and append entries without IDs
    final deduped = uniqueAssignments.values.toList();
    deduped.addAll(fallbackAssignments);
    return deduped;
  }

  List<DailyAssignment> _sortAssignments(
    List<DailyAssignment> assignments,
  ) {
    assignments.sort(
      (a, b) => _resolveSortDate(b).compareTo(_resolveSortDate(a)),
    );
    return assignments;
  }

  DateTime _resolveSortDate(DailyAssignment assignment) {
    final candidates = [
      assignment.date,
      assignment.createdAt,
      assignment.updatedAt,
    ];

    for (final candidate in candidates) {
      final parsed = _tryParseDate(candidate);
      if (parsed != null) return parsed;
    }

    // Fallback to epoch to ensure items without dates go last
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  DateTime? _tryParseDate(String? raw) {
    if (raw == null) return null;
    final value = raw.trim();
    if (value.isEmpty) return null;

    DateTime? parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    // Handle dd/MM/yyyy or dd-MM-yyyy formats
    final normalized = value.replaceAll('/', '-');
    final parts = normalized.split('-');
    if (parts.length == 3) {
      try {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        var year = int.parse(parts[2]);
        if (year < 100) {
          year += 2000;
        }
        return DateTime(year, month, day);
      } catch (_) {
        // Continue to next fallback
      }
    }

    return null;
  }

  bool _hasAttachment(DailyAssignment assignment) {
    return assignment.attachment.trim().isNotEmpty;
  }

  Widget _buildAttachmentTile(DailyAssignment assignment) {
    final fileName = _attachmentFileName(assignment);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.attachment,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                TranslatedText(
                  'Tap download to view attachment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => _openAttachment(assignment),
            icon: const Icon(Icons.download, size: 18),
            label: const TranslatedText('Download'),
          ),
        ],
      ),
    );
  }

  Future<void> _openAttachment(DailyAssignment assignment) async {
    try {
      // CRITICAL: Use THIS assignment's data for file download
      // File download must match: assignment ID, title, subject, date from THIS assignment
      
      
      
      
      
      
      
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                TranslatedText('Preparing attachment for: ${assignment.title}'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final urlString = await _resolveAttachmentUrl(assignment);
      if (urlString.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const TranslatedText('Attachment not available for this assignment. Please check the attachment data.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        
        return;
      }

      

      // Validate and parse URL
      Uri uri;
      try {
        uri = Uri.parse(urlString);
      } catch (e) {
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid attachment URL format: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if URL is valid
      if (!uri.hasScheme || !uri.scheme.startsWith('http')) {
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid attachment URL scheme: ${uri.scheme}'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Check if it's a PDF file
      final isPDF = urlString.toLowerCase().endsWith('.pdf') || 
                    assignment.attachment.toLowerCase().endsWith('.pdf');

      bool launched = false;
      Object? lastError;

      if (isPDF) {
        // Open PDF in-app with dedicated viewer
        try {
          if (!mounted) return;
          
          final fileName = _attachmentFileName(assignment);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PDFViewerPage(
                documentUrl: urlString,
                documentTitle: fileName,
              ),
            ),
          );
          launched = true;
          
        } catch (e) {
          lastError = e;
          
        }
      } else {
        // Open all other documents in-app with universal viewer
        try {
          if (!mounted) return;
          
          final fileName = _attachmentFileName(assignment);
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => DocumentViewerPage(
                documentUrl: urlString,
                documentTitle: fileName,
              ),
            ),
          );
          launched = true;
          
        } catch (e) {
          lastError = e;
          
        }
      }

      if (!mounted) return;

      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Attachment opened successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText(
              'Could not open attachment.\nURL: ${urlString.length > 50 ? '${urlString.substring(0, 50)}...' : urlString}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Details',
              textColor: Colors.white,
              onPressed: () {
                
                
                
                
              },
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening attachment: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<String> _resolveAttachmentUrl(DailyAssignment assignment) async {
    // CRITICAL: Use assignment-specific data (from API) for file download
    // File download must match: assignment ID, title, subject, date from THIS assignment
    
    
    
    
    
    
    

    String rawPath = assignment.attachment.trim();
    if (rawPath.isEmpty) {
      
      return '';
    }

    // Prefer full URLs as-is
    if (rawPath.startsWith('http://') || rawPath.startsWith('https://')) {
      
      return rawPath;
    }

    // Get base URL using UrlManager (consistent with other modules)
    String baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      // Fallback to AppConfig
      baseUrl = await AppConfig.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return '';
      }
    }

    // Normalize base URL (remove trailing slash, we'll add it back)
    baseUrl = baseUrl.trim();
    final normalizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    // Extract exact filename from API path (do NOT trim or modify filename)
    // Split by '/' and take the last part, which is the filename
    final pathParts = rawPath.split('/');
    final exactFileName = pathParts.isNotEmpty ? pathParts.last : rawPath;
    
    // Force path to: uploads/homework/daily_assignment/{exact_filename}
    final forcedPath = 'uploads/homework/daily_assignment/$exactFileName';
    
    
    

    final fullUrl = '$normalizedBase/$forcedPath';
    
    return fullUrl;
  }

  String _attachmentFileName(DailyAssignment assignment) {
    final raw = assignment.attachment.trim();
    if (raw.isEmpty) return 'Document';
    final parts = raw.split('/');
    final name = parts.isNotEmpty ? parts.last : raw;
    if (name.isEmpty) return raw;
    return name;
  }
}
