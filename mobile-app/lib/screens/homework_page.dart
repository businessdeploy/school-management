import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../providers/app_config_provider.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../models/homework.dart';
import 'login_page.dart';
import 'pdf_viewer_page.dart';
import 'document_viewer_page.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

const _homeworkUploadPrefix = 'uploads/homework/';

// Resolve document URL with support for:
// 1. Student submission: /uploads/homework/assignment/{{file_name}}
// 2. Homework attachment: /uploads/homework/daily_assignment/{{file_name}}
Future<String> _resolveDocumentUrl(String documentPath, {String? studentId, bool isTeacherAttachment = false}) async {
  final trimmedPath = documentPath.trim();
  if (trimmedPath.isEmpty) return '';

  final lowercasePath = trimmedPath.toLowerCase();
  // If already a full URL, return as-is
  if (lowercasePath.startsWith('http://') || lowercasePath.startsWith('https://')) {
    return Uri.encodeFull(trimmedPath);
  }

  final baseUrl = await _resolveBaseUrl();
  if (baseUrl.isEmpty) return '';

  String normalizedPath = trimmedPath;
  
  // Handle student submitted homework attachments
  // Extract filename and force path to /uploads/homework/assignment/
  if (!isTeacherAttachment) {
    final fileName = normalizedPath.split('/').last;
    // Force the path to /uploads/homework/assignment/
    normalizedPath = 'uploads/homework/assignment/$fileName';
  } else {
    // Handle teacher homework attachments and daily assignments
    if (normalizedPath.contains('uploads/homework/daily_assignment/')) {
      // Path already in correct format: uploads/homework/daily_assignment/{{file_name}}
    } else if (normalizedPath.contains('uploads/')) {
      // Path has uploads/ but not in expected format, use as-is
    } else {
      // Path is just filename or relative path
      final fileName = normalizedPath.split('/').last;
      // For teacher homework attachments: uploads/homework/daily_assignment/{{file_name}}
      normalizedPath = '$_homeworkUploadPrefix$fileName';
    }
  }

  // Remove leading slash if present (baseUrl already normalized)
  if (normalizedPath.startsWith('/')) {
    normalizedPath = normalizedPath.substring(1);
  }

  return Uri.encodeFull('$baseUrl/$normalizedPath');
}

Future<String> _resolveBaseUrl() async {
  var baseUrl = await UrlManager.getBaseUrl();
  if (baseUrl.isEmpty) {
    baseUrl = await AppConfig.getBaseUrl();
  }
  if (baseUrl.endsWith('/')) {
    baseUrl = baseUrl.substring(0, baseUrl.length - 1);
  }
  return baseUrl;
}

Future<void> _launchDocument(BuildContext context, String documentPath, {String? studentId, bool isTeacherAttachment = false}) async {
  if (documentPath.isEmpty) return;
  
  try {
    final resolvedUrl = await _resolveDocumentUrl(documentPath, studentId: studentId, isTeacherAttachment: isTeacherAttachment);
    if (resolvedUrl.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid document URL'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Check if it's a PDF file - use dedicated PDF viewer
    final isPDF = resolvedUrl.toLowerCase().endsWith('.pdf') || 
                  documentPath.toLowerCase().endsWith('.pdf');

    if (context.mounted) {
      // Extract filename for title
      final fileName = documentPath.split('/').last;
      
      if (isPDF) {
        // Use dedicated PDF viewer for better performance
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFViewerPage(
              documentUrl: resolvedUrl,
              documentTitle: fileName,
            ),
          ),
        );
      } else {
        // Use universal document viewer for all other file types
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentViewerPage(
              documentUrl: resolvedUrl,
              documentTitle: fileName,
            ),
          ),
        );
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  List<Homework> homeworkList = [];
  List<Homework> originalHomeworkList = []; // Added to preserve original list
  bool isLoading = true;
  String? errorMessage;
  String selectedStatus = 'pending';
  String selectedFilter = 'All'; // Changed default value
  List<String> subjectNames = []; // Added list to store subject names

  @override
  void initState() {
    super.initState();
    loadHomework();
  }

  // Static cache for subject names to avoid re-fetching all statuses
  static List<String> _cachedSubjectNames = ['All'];
  static DateTime? _subjectCacheTime;

  Future<void> loadHomework() async {
    try {

      final userProfile = await AuthService.getUserProfile();
      String studentId = userProfile['student_id'] ?? '';

      if (studentId.isEmpty) {
        final userId = userProfile['user_id'];
        if (userId != null && userId.isNotEmpty) {
          studentId = userId;
        } else {
          throw Exception('No student ID found. Please login again.');
        }
      }

      // Check if user has a token
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('User not authenticated. Please login again.');
      }

      // Fetch all three statuses in parallel for the subject list and the current view
      
      final results = await Future.wait([
        ApiService.getHomework(studentId, homeworkStatus: 'pending'),
        ApiService.getHomework(studentId, homeworkStatus: 'submitted'),
        ApiService.getHomework(studentId, homeworkStatus: 'evaluated'),
      ]);

      final List<Homework> allFetchedHomework = [];
      List<Homework> currentStatusHomework = [];

      // Process results and extract homework for current status
      for (int i = 0; i < results.length; i++) {
        final data = results[i];
        final status = ['pending', 'submitted', 'evaluated'][i];
        
        List<dynamic>? rawList;
        for (String key in ['homeworklist', 'homework_list', 'homework', 'data', 'homeworkList']) {
          if (data[key] != null && data[key] is List) {
            rawList = data[key] as List<dynamic>;
            break;
          }
        }

        if (rawList != null) {
          final items = rawList.map((item) => Homework.fromJson(item)).toList();
          allFetchedHomework.addAll(items);
          if (status == selectedStatus) {
            currentStatusHomework = items;
          }
        }
      }

      // Extract unique subjects from ALL fetched homework
      final Set<String> uniqueSubjects = {};
      for (var homework in allFetchedHomework) {
        if (homework.subjectName.isNotEmpty && homework.subjectCode.isNotEmpty) {
          uniqueSubjects.add('${homework.subjectName} (${homework.subjectCode})');
        }
      }

      final List<String> allSubjects = ['All', ...uniqueSubjects.toList()..sort()];
      _cachedSubjectNames = allSubjects;
      _subjectCacheTime = DateTime.now();

      // Update state
      setState(() {
        originalHomeworkList = currentStatusHomework;
        homeworkList = _applyLocalFilter(originalHomeworkList, selectedFilter);
        subjectNames = allSubjects;
        isLoading = false;
        errorMessage = null;
        
        if (!subjectNames.contains(selectedFilter)) {
          selectedFilter = 'All';
          homeworkList = List.from(originalHomeworkList);
        }
      });

    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        if (e.toString().contains('authenticated') || e.toString().contains('login')) {
          errorMessage = 'Please login again.';
        } else {
          errorMessage = 'Error loading homework: $e';
        }
        subjectNames = _cachedSubjectNames.length > 1 ? _cachedSubjectNames : _getDefaultSubjects();
      });
    }
  }

  // Get default subjects as fallback
  List<String> _getDefaultSubjects() {
    return [
      'All',
      'English (210)',
      'Mathematics (110)',
      'Science (111)',
      'Social Studies (212)',
      'Hindi (230)',
      'Computer (00220)',
      'Physics (301)',
      'Chemistry (302)',
      'Biology (303)',
      'History (401)',
      'Geography (402)',
      'Economics (501)',
      'Business Studies (502)',
      'Art (601)',
      'Music (602)',
      'Physical Education (701)',
    ];
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText('Homework'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              loadHomework();
            },
            tooltip: 'Refresh Homework',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Illustration Header
            EnterpriseUIComponents.buildHeaderWithIllustration(
              title: 'Your Homework is here!',
              subtitle: 'Track your assignments and submissions',
              illustration: Image.asset(
                'assets/images/homeworkpage.jpg',
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(
                  Icons.assignment_outlined,
                  color: primaryColor,
                  size: 40,
                ),
              ),
            ),

            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final horizontalPadding = constraints.maxWidth * 0.05;
                  final cardWidth = constraints.maxWidth.clamp(320.0, 1000.0);
                  
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.only(
                      left: horizontalPadding,
                      right: horizontalPadding,
                      top: 0,
                      bottom: 12,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: cardWidth),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFilters(constraints),
                            const SizedBox(height: 16),
                            _buildHomeworkList(),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(BoxConstraints constraints) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Filter Tabs (Left side, scrollable if needed)
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildFilterTab('pending', 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterTab('submitted', 'Submitted'),
                  const SizedBox(width: 8),
                  _buildFilterTab('evaluated', 'Evaluated'),
                ],
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Subject Dropdown (Right side, fixed width)
          SizedBox(
            width: 90,
            child: DropdownButtonHideUnderline(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                value: subjectNames.contains(selectedFilter) ? selectedFilter : 'All',
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4, // Reduced padding to match tab height
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                icon: const Icon(Icons.arrow_drop_down, size: 20),
                items: subjectNames.map((subject) {
                  return DropdownMenuItem<String>(
                    value: subject,
                    child: Text(
                      subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      selectedFilter = value;
                    });
                    _applyLocalFilterToCurrentList();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildHomeworkList() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (homeworkList.isEmpty) {
      return const Center(
        child: Text(
          'No homework found',
          style: TextStyle(
            fontSize: 16,
            color: Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: homeworkList.length,
      itemBuilder: (context, index) {
        final homework = homeworkList[index];
        return _buildHomeworkCard(homework);
      },
    );
  }

  Widget _buildFilterTab(String status, String label) {
    final isSelected = selectedStatus == status;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedStatus = status;
          selectedFilter = 'All'; // Reset subject filter when changing status
        });
        loadHomework();
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 70, maxWidth: 80),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? _getStatusColor(status, context) : Colors.grey[200],
          borderRadius: BorderRadius.circular(16),
          border: isSelected
              ? Border.all(color: _getStatusColor(status, context), width: 1)
              : null,
        ),
        child: TranslatedText(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: FontWeight.w600,
            fontSize: 10,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }


  Widget _buildFileRow(String label, String filePath, {String? studentId, bool isTeacherAttachment = false}) {
    final fileName = filePath.split('/').last;
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = math.min(120.0, constraints.maxWidth * 0.4);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  '$label:',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        fileName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 0,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: InkWell(
                          onTap: () => _launchDocument(context, filePath, studentId: studentId, isTeacherAttachment: isTeacherAttachment),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Provider.of<AppConfigProvider>(context).secondaryColorObj.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: Provider.of<AppConfigProvider>(context).secondaryColorObj.withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download,
                                  size: 14,
                                  color: Provider.of<AppConfigProvider>(context).primaryColorObj,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Download',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Provider.of<AppConfigProvider>(context).primaryColorObj,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHomeworkCard(Homework homework) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;

    // CRITICAL: For submitted homework, show actual submission date
    final formattedHomeworkDueDate = homework.validatedSubmissionDate;
    String formattedSubmittedAt = '';

    if (homework.submittedAt.isNotEmpty) {
      formattedSubmittedAt =
          homework.formatDateForDisplay(homework.submittedAt);
      // If status is submitted but no submitted_at, use today's date
      if (formattedSubmittedAt.isEmpty) {
        final now = DateTime.now();
        formattedSubmittedAt =
            '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
      }
    }

    // Priority: submitted_at > today's date (if submitted) > due date
    final submissionRowValue = formattedSubmittedAt.isNotEmpty
        ? formattedSubmittedAt
        : formattedHomeworkDueDate;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${homework.subjectName} (${homework.subjectCode})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (homework.status.toLowerCase() == 'pending' ||
                    homework.status.toLowerCase() == 'submitted') ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => _handleSubmitHomework(homework),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        homework.status.toLowerCase() == 'submitted'
                            ? 'RESUBMIT'
                            : 'SUBMIT',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInfoRow('Homework Date', homework.validatedHomeworkDate),
                _buildInfoRow('Submission Date', submissionRowValue),
                if (homework.evaluationDate.isNotEmpty &&
                    homework.status.toLowerCase() == 'evaluated')
                  _buildInfoRow('Evaluation Date',
                      homework.formatDateForDisplay(homework.evaluationDate)),
                _buildInfoRow('Created By', homework.createdByWithStaffId),
                if (homework.evaluatedByWithId.isNotEmpty &&
                    homework.status.toLowerCase() == 'evaluated')
                  _buildInfoRow('Evaluated By', homework.evaluatedByWithId),
                _buildInfoRow('Max Marks', homework.maxMarks),
                if (homework.marksObtained.isNotEmpty &&
                    homework.marksObtained != '0.00' &&
                    homework.marksObtained != '0')
                  _buildInfoRow('Marks Obtained', homework.marksObtained),
                if (homework.note.isNotEmpty)
                  _buildInfoRow('Evaluation Note', homework.note),
                const SizedBox(height: 12),

                // File attachments
                if (homework.attachedDocument.isNotEmpty)
                  _buildFileRow(
                    'Homework Attachment',
                    homework.attachedDocument,
                    isTeacherAttachment: true,
                  ),

                // Student submission attachment
                if (_hasSubmissionAttachment(homework))
                  _buildSubmissionAttachmentRow(homework, context),

                // Description (if available)
                if (homework.description.isNotEmpty) ...[
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText(
                        'Description: ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      Expanded(
                        child: Text(
                          _cleanHtmlText(homework.description),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],

                // Student Submission Message
                if (homework.studentDescription.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const TranslatedText(
                        'My Message: ',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87),
                      ),
                      Expanded(
                        child: Text(
                          homework.studentDescription,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = math.min(110.0, constraints.maxWidth * 0.35);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelWidth,
                child: Text(
                  '$label:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Check if homework has a submission attachment
  bool _hasSubmissionAttachment(Homework homework) {
    return homework.studentLogo.isNotEmpty ||
           homework.uploadedFileUrl.isNotEmpty;
  }
  
  // Get the submission attachment path (check multiple fields)
  String? _getSubmissionAttachment(Homework homework) {
    // Priority order: studentLogo > uploadedFileUrl > attachedDocument
    if (homework.studentLogo.isNotEmpty) {
      return homework.studentLogo;
    }
    if (homework.uploadedFileUrl.isNotEmpty) {
      return homework.uploadedFileUrl;
    }
    if (homework.attachedDocument.isNotEmpty) {
      return homework.attachedDocument;
    }
    return null;
  }
  
  // Build submission attachment row with download button
  Widget _buildSubmissionAttachmentRow(Homework homework, BuildContext context) {
    final attachmentPath = _getSubmissionAttachment(homework);
    if (attachmentPath == null || attachmentPath.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final fileName = attachmentPath.split('/').last;
    
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(Icons.attach_file, color: Provider.of<AppConfigProvider>(context).primaryColorObj, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  'My Submission:',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: () => _launchDocument(context, attachmentPath, studentId: homework.studentId, isTeacherAttachment: false),
            icon: const Icon(Icons.download, size: 16),
            label: const TranslatedText('Download'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Color _getStatusColor(String status, BuildContext context) {
    final appConfig = Provider.of<AppConfigProvider>(context, listen: false);
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'submitted':
        // Use a darker green for better visibility with white text
        return Colors.green.shade600;
      case 'evaluated':
        return appConfig.primaryColorObj;
      default:
        return Colors.grey;
    }
  }

  void _handleSubmitHomework(Homework initialHomework) async {
    Homework homework = initialHomework;

    // If it's a resubmission, fetch detailed data first as per user request
    if (initialHomework.status.toLowerCase() == 'submitted') {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final homeworkIdToFetch = initialHomework.homeworkId.isNotEmpty 
            ? initialHomework.homeworkId 
            : initialHomework.id;
            
        final response = await ApiService.getHomeworkById(homeworkIdToFetch);
        
        // Hide loading indicator
        if (mounted) Navigator.pop(context);

        // API might return success = true or status = 1
        final dynamic status = response['status'] ?? response['success'];
        final bool isSuccess = status == 1 || status == '1' || status == true;
        
        // If not explicit success, check if we got a homework object anyway (parsing fallback)
        final isHomeworkResponse = response.containsKey('homework') || response.containsKey('homework_detail');

        if (isSuccess || isHomeworkResponse) {
          // The response might contain the homework object in various keys
          var homeworkData = response['homework'] ?? response['homework_detail'] ?? response['data'];
          
          // If response is the homework object itself (direct return)
          if (homeworkData == null && response.containsKey('subject_name')) {
            homeworkData = response;
          }

          if (homeworkData != null && homeworkData is Map<String, dynamic>) {
             final Map<String, dynamic> mergedData = Map<String, dynamic>.from(homeworkData);
             
             // Merge top-level fields (like student_message) if they are siblings
             response.forEach((key, value) {
               if (!mergedData.containsKey(key) && 
                  key != 'homework' && 
                  key != 'homework_detail' && 
                  key != 'homeworklist' &&
                  key != 'data') {
                 mergedData[key] = value;
               }
             });

             // Explicitly check for message keys and force them if present
             final messageKeys = ['message', 'description', 'student_message', 'student_description', 'note', 'comment', 'student_answer'];
             for (final key in messageKeys) {
               if (response.containsKey(key) && response[key] != null && response[key].toString().isNotEmpty) {
                 mergedData[key] = response[key];
               }
             }
             
             // Check for common submission keys
             for (final key in ['student_homework', 'submission', 'student', 'student_submission', 'student_homework_data']) {
               if (response.containsKey(key)) {
                 mergedData[key] = response[key];
               }
             }
             
             homework = Homework.fromJson(mergedData);
          }
        } else {
        }
      } catch (e) {
        // Hide loading indicator on error
        if (mounted) Navigator.pop(context);
      }
    }

    if (!mounted) return;

    // Navigate to upload homework page
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadHomeworkPage(homework: homework),
      ),
    );

    // Refresh homework list if submission was successful
    if (result == true) {
      
      // CRITICAL: Switch to "submitted" tab to see the submitted homework
      if (mounted) {
        setState(() {
          selectedStatus = 'submitted';
          selectedFilter = 'All'; // Reset filter
        });
      }
      
      // Wait a moment for server to process the submission
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Reload from API to get the updated status, date, message, and file path (server-side)
      await loadHomework();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submission complete. Viewing submitted homework...'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }


  // Apply local filter to homework list (JavaScript-like instant filtering)
  List<Homework> _applyLocalFilter(List<Homework> homeworkList, String filter) {
    if (filter == 'All') {
      return homeworkList;
    }

    // Extract subject name and code from filter (e.g., "Computer (00220)")
    final RegExp regex = RegExp(r'^(.+?)\s*\((\d+)\)$');
    final match = regex.firstMatch(filter);

    if (match != null) {
      final subjectName = match.group(1)?.trim() ?? '';
      final subjectCode = match.group(2) ?? '';

      // Filter by subject
      return homeworkList.where((homework) {
        return homework.subjectName == subjectName &&
            homework.subjectCode == subjectCode;
      }).toList();
    }

    return homeworkList;
  }

  // Apply local filter to current list (for dropdown changes)
  void _applyLocalFilterToCurrentList() {
    // CRITICAL: Always filter from originalHomeworkList (the complete, unfiltered dataset)
    // This ensures the dropdown filter works correctly even after search or other operations
    // that may have modified homeworkList
    
    
    // If originalHomeworkList is empty, we need to reload from API
    // This should not happen in normal operation, but we handle it gracefully
    if (originalHomeworkList.isEmpty) {
      loadHomework();
      return;
    }

    // ALWAYS filter from originalHomeworkList - never from homeworkList
    // This ensures we're filtering from the complete dataset, not from already-filtered results
    final filtered = _applyLocalFilter(originalHomeworkList, selectedFilter);
    
    setState(() {
      homeworkList = filtered;
      // CRITICAL: Never modify originalHomeworkList here - it's the immutable source of truth
      // originalHomeworkList should only be modified in loadHomework()
    });
    
    
    // Verify we're filtering from the correct source
    if (filtered.length > originalHomeworkList.length) {
    }
  }

  String _cleanHtmlText(String htmlText) {
    // Remove HTML tags and clean up the text
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll('&nbsp;', ' ') // Replace HTML entities
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .trim();
  }

}

// Upload Homework Page
class UploadHomeworkPage extends StatefulWidget {
  final Homework homework;

  const UploadHomeworkPage({super.key, required this.homework});

  @override
  State<UploadHomeworkPage> createState() => _UploadHomeworkPageState();
}

class _UploadHomeworkPageState extends State<UploadHomeworkPage> {
  final TextEditingController messageController = TextEditingController();
  String? selectedFile;
  String? selectedFilePath;
  String? existingSubmissionUrl;
  String? existingSubmissionFileName;
  bool hasExistingSubmission = false;
  bool _isLoadingExistingPreview = false;
  Color? _secondaryColor;

  static const Set<String> _unsupportedImageExtensions = {
    '.heic',
    '.heif',
    '.heics',
    '.heifs',
    '.heix',
    '.hevx',
  };

  @override
  void initState() {
    super.initState();
    _loadColors();
    if (widget.homework.studentDescription.isNotEmpty) {
      final msg = widget.homework.studentDescription;
      final lowerMsg = msg.toLowerCase();
      const invalidMsgs = {'success', '1', 'true', 'ok', 'null'};
      if (!invalidMsgs.contains(lowerMsg)) {
        messageController.text = msg;
      }
    }
    if (widget.homework.studentLogo.isNotEmpty) {
      hasExistingSubmission = true;
      final raw = widget.homework.studentLogo;
      final parts = raw.split('/');
      existingSubmissionFileName = parts.isNotEmpty ? parts.last : raw;
    }
    _hydrateExistingSubmission();
    
    // Always fetch detailed homework by ID for potential resubmission as per user request
    // This ensures we get the latest message and attachment from the server
    _fetchDetailedHomework();
  }

  Future<void> _fetchDetailedHomework() async {
    final homeworkIdToFetch = widget.homework.homeworkId.isNotEmpty 
        ? widget.homework.homeworkId 
        : widget.homework.id;
        
    if (homeworkIdToFetch.isEmpty) return;

    try {
      final response = await ApiService.getHomeworkById(homeworkIdToFetch);
      
      final dynamic status = response['status'] ?? response['success'];
      final bool isSuccess = status == 1 || status == '1' || status == true;
      final bool isHomeworkResponse = response.containsKey('homework') || 
                                      response.containsKey('homework_detail') || 
                                      response.containsKey('homeworklist') ||
                                      response.containsKey('subject_name');

      if (isSuccess || isHomeworkResponse) {
        var homeworkData = response['homework'] ?? 
                           response['homework_detail'] ?? 
                           response['homeworklist'] ?? 
                           response['data'];
        if (homeworkData == null && response.containsKey('subject_name')) {
          homeworkData = response;
        }
        
        if (homeworkData != null && homeworkData is Map<String, dynamic>) {
           final Map<String, dynamic> mergedData = Map<String, dynamic>.from(homeworkData);
           
           response.forEach((key, value) {
             if (!mergedData.containsKey(key) && 
                 key != 'homework' && 
                 key != 'homework_detail' && 
                 key != 'homeworklist' && 
                 key != 'data') {
               mergedData[key] = value;
             }
           });

           final messageKeys = ['message', 'student_message', 'student_description', 'note', 'comment', 'student_answer'];
           for (final key in messageKeys) {
             if (response.containsKey(key) && response[key] != null && response[key].toString().isNotEmpty) {
               mergedData[key] = response[key];
             }
           }
           
           for (final key in ['student_homework', 'submission', 'student', 'student_submission', 'student_homework_data']) {
             if (response.containsKey(key)) {
               mergedData[key] = response[key];
             }
           }
           
           final updatedHomework = Homework.fromJson(mergedData);
           
           if (mounted) {
             setState(() {
                final newMsg = updatedHomework.studentDescription;
                final lowerMsg = newMsg.toLowerCase();
                const invalidMsgs = {'success', '1', 'true', 'ok', 'null'};
                
                if (newMsg.isNotEmpty && !invalidMsgs.contains(lowerMsg)) {
                  messageController.text = newMsg;
                } else {
                  // Fallback to top-level keys if nested mapping failed
                  for (final key in [
                    'student_message', 'message', 'student_description', 
                    'student_note', 'comment', 'student_answer', 'msg'
                  ]) {
                    final val = response[key]?.toString() ?? '';
                    final lowerVal = val.toLowerCase();
                    if (val.isNotEmpty && !invalidMsgs.contains(lowerVal)) {
                       messageController.text = val;
                       break;
                    }
                  }
                }
               
               if (updatedHomework.studentLogo.isNotEmpty && !hasExistingSubmission) {
                 hasExistingSubmission = true;
                 final raw = updatedHomework.studentLogo;
                 final parts = raw.split('/');
                 existingSubmissionFileName = parts.isNotEmpty ? parts.last : raw;
                 _hydrateExistingSubmission();
               }
             });
           }
        }
      }
    } catch (e) {
    }
  }

  Future<void> _loadColors() async {
    final colorHex = await AppConfig.getSecondaryColor();
    if (colorHex.isNotEmpty && mounted) {
      setState(() {
        _secondaryColor = _parseColor(colorHex);
      });
    }
  }

  Color? _parseColor(String hexColor) {
    try {
      if (hexColor.isEmpty) return null;
      hexColor = hexColor.replaceAll('#', '');
      if (hexColor.length == 6) {
        return Color(int.parse('0xFF$hexColor'));
      } else if (hexColor.length == 8) {
        return Color(int.parse('0x$hexColor'));
      }
    } catch (e) {
    }
    return null;
  }

  Future<String> _ensureSupportedFile(XFile file) async {
    final extension = p.extension(file.path).toLowerCase();
    if (!_unsupportedImageExtensions.contains(extension)) {
      return file.path;
    }

    try {
      final bytes = await file.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        throw Exception('Unsupported image format: $extension');
      }

      final tempDir = await getTemporaryDirectory();
      final safeName =
          '${p.basenameWithoutExtension(file.path)}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = p.join(tempDir.path, safeName);

      final convertedBytes = img.encodeJpg(decoded, quality: 90);
      final convertedFile = await File(
        newPath,
      ).writeAsBytes(convertedBytes, flush: true);

      return convertedFile.path;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _handleImageSelection(
    XFile? image, {
    bool fromCamera = false,
  }) async {
    if (image == null) return;
    try {
      final processedPath = await _ensureSupportedFile(image);
      final fileName = p.basename(processedPath);
      setState(() {
        selectedFile = '${fromCamera ? 'Photo' : 'Image'}: $fileName';
        selectedFilePath = processedPath;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fromCamera ? 'Photo ready: $fileName' : 'Image selected: $fileName',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText('Upload Homework'),
        backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          // Main white card
          Expanded(
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onLongPress: () {
                                  showDialog(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const TranslatedText('Debug Info'),
                                      content: SingleChildScrollView(
                                        child: Text(
                                          'JSON Data:\n${const JsonEncoder.withIndent('  ').convert(widget.homework.toJson())}\n\n'
                                          'Student Description: ${widget.homework.studentDescription}\n'
                                          'Status: ${widget.homework.status}',
                                          style: const TextStyle(fontSize: 10),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context),
                                          child: const TranslatedText('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: const TranslatedText(
                                  'Upload Homework from here!',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${widget.homework.subjectName} (${widget.homework.subjectCode})',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Upload illustration - using same icon as homework page
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Provider.of<AppConfigProvider>(context).secondaryColorObj.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Image.asset(
                            'assets/images/ic_dashboard_homework.png',
                            width: 40,
                            height: 40,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    
                    const SizedBox(height: 10),

                    // Message input
                    TextField(
                      controller: messageController,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Message',
                        hintText: 'Add a message (optional)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: Provider.of<AppConfigProvider>(context).primaryColorObj,
                            width: 2,
                          ),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    // Documents section
                    const TranslatedText(
                      'Documents',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // File selection card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          if (hasExistingSubmission && selectedFile == null)
                            _buildExistingPreview()
                          else ...[
                            Icon(
                              Icons.cloud_upload,
                              size: 48,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 10),
                          ],
                          Text(
                            _fileLabelText(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight:
                                  hasExistingSubmission && selectedFile == null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _selectFile,
                                  icon: const Icon(Icons.folder_open, size: 18),
                                  label: const Text(
                                    'Choose',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
                                    foregroundColor: Colors.white,
                                    fixedSize: const Size(double.infinity, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _takePhoto,
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  label: const Text(
                                    'Take Photo',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green[600],
                                    foregroundColor: Colors.white,
                                    fixedSize: const Size(double.infinity, 48),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (selectedFile != null &&
                              hasExistingSubmission &&
                              existingSubmissionUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    selectedFile = null;
                                    selectedFilePath = null;
                                  });
                                },
                                icon: const Icon(Icons.undo, size: 18),
                                label: const Text('Keep current upload'),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Submit button
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(20),
            child: ElevatedButton(
              onPressed: _submitHomework,
              style: ElevatedButton.styleFrom(
                backgroundColor: Provider.of<AppConfigProvider>(context).primaryColorObj,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'SUBMIT',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          

        ],
      ),
    );
  }

  Widget _buildPreviousMessage() {
    final msg = widget.homework.studentDescription.isNotEmpty 
        ? widget.homework.studentDescription 
        : messageController.text;
        
    if (msg.isEmpty) return const SizedBox.shrink();
    
    final invalidMsgs = {'success', '1', 'true', 'ok', 'null'};
    if (invalidMsgs.contains(msg.toLowerCase())) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TranslatedText(
          'Previous Message',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            msg,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[800],
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _hydrateExistingSubmission() async {
    final rawPath = widget.homework.studentLogo;
    if (rawPath.isEmpty) {
      return;
    }

    setState(() => _isLoadingExistingPreview = true);

    try {
      if (!rawPath.startsWith('http')) {
        final baseUrl = await UrlManager.getBaseUrl();
        if (baseUrl.isEmpty) {
          if (!mounted) return;
          setState(() => _isLoadingExistingPreview = false);
          return;
        }

        final sanitized = rawPath.startsWith('/')
            ? rawPath.substring(1)
            : rawPath;
        final normalizedBase = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
        final resolved = Uri.parse(
          normalizedBase,
        ).resolve(sanitized).toString();

        if (!mounted) return;
        setState(() {
          existingSubmissionUrl = resolved;
          _isLoadingExistingPreview = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          existingSubmissionUrl = rawPath;
          _isLoadingExistingPreview = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingExistingPreview = false);
    }
  }

  Widget _buildExistingPreview() {
    if (_isLoadingExistingPreview) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: CircularProgressIndicator(),
      );
    }

    if (existingSubmissionUrl == null) {
      return Column(
        children: [
          Icon(Icons.cloud_done, size: 48, color: Colors.green[400]),
          const SizedBox(height: 8),
        ],
      );
    }

    final bool looksLikeImage = _isImageFile(
      existingSubmissionFileName ?? existingSubmissionUrl!,
    );

    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: looksLikeImage
              ? Image.network(
                  existingSubmissionUrl!,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _buildNonImagePreview(),
                )
              : _buildNonImagePreview(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildNonImagePreview() {
    return Container(
      height: 160,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.insert_drive_file, color: Colors.blue[400], size: 36),
          const SizedBox(height: 8),
          Text(
            existingSubmissionFileName ?? 'Existing attachment',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  bool _isImageFile(String? fileName) {
    if (fileName == null) return false;
    final lower = fileName.toLowerCase();
    return lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.webp');
  }

  String _fileLabelText() {
    if (selectedFile != null) {
      return selectedFile!;
    }
    if (hasExistingSubmission && existingSubmissionFileName != null) {
      return 'Click to Change Document';
    }
    return 'Upload New Document';
  }

  void _selectFile() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      await _handleImageSelection(image);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _takePhoto() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      await _handleImageSelection(image, fromCamera: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking photo: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _submitHomework() async {
    // Allow submission with either message or file or both
    // The API will handle the default message if both are empty
    final hasMessage = messageController.text.trim().isNotEmpty;
    final hasFile = selectedFilePath != null && selectedFilePath!.isNotEmpty;
    final hasExistingServerFile =
        hasExistingSubmission && widget.homework.studentLogo.isNotEmpty;

    if (!hasMessage && !hasFile && !hasExistingServerFile) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add a message or select an image to upload'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (widget.homework.id.isEmpty) {
        throw Exception(
          'Homework reference missing. Please refresh the homework list.',
        );
      }

      // Prefer student id returned with homework payload to avoid mismatches
      String studentId = widget.homework.studentId;
      if (studentId.isEmpty) {
        final userProfile = await AuthService.getUserProfile();
        studentId = userProfile['student_id'] ?? '';
        if (studentId.isEmpty) {
          final userId = userProfile['user_id'];
          if (userId != null && userId.isNotEmpty) {
            studentId = userId;
          } else {
            throw Exception('No student ID found. Please login again.');
          }
        }
      }

      // Prepare message - send only the user's message, not file info
      // The file is sent separately in the multipart request
      String message = messageController.text.trim();
      if (message.isEmpty) {
        message = 'Homework Upload'; // Default message as per API spec
      }

      // Debug information

      // Use homeworkId (which should be the homework_id from API)
      // If homeworkId is empty, fall back to id
      final homeworkIdToUse = widget.homework.homeworkId.isNotEmpty 
          ? widget.homework.homeworkId 
          : widget.homework.id;
      
      if (homeworkIdToUse.isEmpty) {
        throw Exception('Homework ID is missing. Please refresh the homework list.');
      }
      

      // Submit homework using API
      final result = await ApiService.submitHomework(
        studentId,
        homeworkIdToUse,
        message,
        selectedFilePath,
      );

      // Hide loading indicator
      Navigator.pop(context);


      final dynamic status = result['status'];
      final bool isSuccess = status == 1 || status == '1' || status == true;

      if (isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Homework submitted successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        // Navigate back after a short delay
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pop(
            context,
            true,
          ); // Return true to indicate successful submission
        }
      } else {
        // Extract error message from various possible locations
        String errorMessage =
            result['validate_storage']?.toString() ??
            result['msg']?.toString() ??
            result['message']?.toString() ??
            result['error']?.toString() ??
            'Failed to submit homework';

        // If message is still generic, try to get more details
        if (errorMessage == 'Failed to submit homework' &&
            result.containsKey('data')) {
          final data = result['data'];
          if (data is Map) {
            errorMessage =
                data['msg']?.toString() ??
                data['message']?.toString() ??
                errorMessage;
          }
        }
        
        // Check if we have a detailed error object that wasn't formatted
        if (result['error'] != null && errorMessage == 'Failed to submit homework') {
           if (result['error'] is Map) {
             final errorMap = result['error'] as Map;
             final List<String> parts = [];
             errorMap.forEach((k, v) => parts.add('$k: $v'));
             if (parts.isNotEmpty) errorMessage = parts.join('\n');
           } else {
             errorMessage = result['error'].toString();
           }
        }


        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                errorMessage.isNotEmpty
                    ? errorMessage
                    : 'Failed to submit homework. Please check your connection and try again.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Retry',
                textColor: Colors.white,
                onPressed: () => _submitHomework(),
              ),
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      // Hide loading indicator
      if (mounted) {
        Navigator.pop(context);
      }


      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}

