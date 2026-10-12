import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import '../services/auth_service.dart';
import '../services/api_service.dart';
import '../utils/url_manager.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';
import 'exam_schedule_page.dart';
import 'exam_result_page.dart';

class ExaminationPage extends StatefulWidget {
  const ExaminationPage({super.key});

  @override
  State<ExaminationPage> createState() => _ExaminationPageState();
}

class _ExaminationPageState extends State<ExaminationPage> {
  List<Map<String, dynamic>> examList = [];
  List<Map<String, dynamic>> activeExams = [];
  List<Map<String, dynamic>> closedExams = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadExamList();
  }

  Future<void> _loadExamList() async {
    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();

      
      
      
      

      // Validate student ID
      if (studentId.isEmpty) {
        if (!mounted) return;
        setState(() {
          error = 'Student ID not found. Please login again.';
          isLoading = false;
        });
        return;
      }

      // Get examination data from API
      final response = await ApiService.getExamList(studentId);

      
      
      
      

      if (!mounted) return;

      List<Map<String, dynamic>> examListData = [];

      // Check for examSchedule first (as per API spec)
      if (response['examSchedule'] != null &&
          response['examSchedule'] is List) {
        examListData = List<Map<String, dynamic>>.from(
          response['examSchedule'],
        );
        
      } else if (response['status'] == 1 && response['data'] != null) {
        if (response['data'] is List) {
          examListData = List<Map<String, dynamic>>.from(response['data']);
          
        } else if (response['data'] is Map &&
            response['data']['examSchedule'] != null) {
          examListData = List<Map<String, dynamic>>.from(
            response['data']['examSchedule'],
          );
          
        }
      }

      

      // Separate exams into active and closed
      List<Map<String, dynamic>> activeList = [];
      List<Map<String, dynamic>> closedList = [];

      for (int i = 0; i < examListData.length; i++) {
        final exam = examListData[i];
        final examName =
            exam['exam'] ?? exam['exam_name'] ?? exam['name'] ?? 'Unknown';
        final examActive =
            exam['exam_active']?.toString() ??
            exam['is_active']?.toString() ??
            '1';
        final resultPublished = exam['result_publish']?.toString() ?? '0';

        

        // Check if exam is closed
        bool isClosed = false;

        // Priority 1: Check if result is published
        if (resultPublished == '1' ||
            resultPublished == 'true' ||
            resultPublished == 1) {
          isClosed = true;
          
        }
        // Priority 2: Check exam_active status
        else if (examActive == '0' ||
            examActive == 'false' ||
            examActive == 0 ||
            examActive == false) {
          isClosed = true;
          
        }
        // Priority 3: Check exam dates
        else if (exam['exam_to'] != null) {
          try {
            final examToStr = exam['exam_to'].toString();
            if (examToStr.isNotEmpty) {
              DateTime? examToDate;
              try {
                examToDate = DateTime.parse(examToStr);
              } catch (e) {
                try {
                  examToDate = DateTime.parse('$examToStr 23:59:59');
                } catch (e2) {
                  
                }
              }

              if (examToDate != null) {
                final now = DateTime.now();
                // Add 1 day buffer
                if (now.isAfter(examToDate.add(const Duration(days: 1)))) {
                  isClosed = true;
                  
                } else {
                  
                }
              }
            }
          } catch (e) {
            
          }
        }

        if (isClosed) {
          closedList.add(exam);
        } else {
          activeList.add(exam);
        }
      }

      

      setState(() {
        examList = examListData;
        activeExams = activeList;
        closedExams = closedList;
        isLoading = false;
      });
    } catch (e) {
      
      
      

      if (!mounted) return;
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText(
          'Examinations',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: const [],
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Examination',
            subtitle: 'View schedules and exam results',
            illustration: Image.asset(
              'assets/images/examinationpage.jpg',
              fit: BoxFit.contain,
            ),
          ),

          // Scrollable Content
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadExamList,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.only(top: 40),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (error != null)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.error_outline,
                                size: 64,
                                color: Colors.red[300],
                              ),
                              const SizedBox(height: 16),
                              TranslatedText(
                                'Failed to load examinations',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.red[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                error!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.red[400],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadExamList,
                                child: const TranslatedText('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (activeExams.isEmpty && closedExams.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.assignment_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              TranslatedText(
                                'No examinations',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TranslatedText(
                                'No examination data found for this student',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Active Exams Section
                            if (activeExams.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16, top: 10),
                                child: TranslatedText(
                                  'Active & Upcoming Exams',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              ...activeExams.map((exam) => _buildExamCard(exam)),
                              const SizedBox(height: 20),
                            ],

                            // Closed Exams Section
                            if (closedExams.isNotEmpty) ...[
                              const Padding(
                                padding: EdgeInsets.only(bottom: 16, top: 10),
                                child: TranslatedText(
                                  'Closed/Result Published',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              ...closedExams.map((exam) => _buildExamCard(exam)),
                              const SizedBox(height: 20),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildExamCard(Map<String, dynamic> exam) {
    final examName = exam['name'] ?? exam['exam'] ?? 'Unknown Exam';
    final description = exam['description'] ?? '';
    final examId = exam['exam_group_class_batch_exam_id'] ?? exam['id'] ?? '';
    final resultPublished =
        exam['result_publish'] == '1' ||
        exam['result_publish'] == 1 ||
        exam['status'] == 'Active';

    final isClosed = closedExams.contains(exam);
    final downloadPath = _getDownloadPath(exam);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with exam title and status
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isClosed ? Colors.green[50] : Colors.blue[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    examName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (resultPublished)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green[600],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const TranslatedText(
                      'Result Out',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Body with description and buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Description - Only show if not empty
                if (description.isNotEmpty) ...[
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => _navigateToExamSchedule(examId, examName, downloadPath),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.red[400]!, width: 1.5),
                          foregroundColor: Colors.red[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText(
                          'Exam Schedule',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (downloadPath.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => _downloadExamSchedule(downloadPath),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[600],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ElevatedButton(
                        onPressed: resultPublished
                            ? () => _navigateToExamResult(examId, examName)
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: TranslatedText(
                          resultPublished ? 'Exam Result' : 'Not Published',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
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
    );
  }

  void _navigateToExamSchedule(String examId, String examName, String downloadUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExamSchedulePage(
              examId: examId, 
              examName: examName,
              downloadUrl: downloadUrl.isNotEmpty ? downloadUrl : null,
            ),
      ),
    );
  }

  void _navigateToExamResult(String examId, String examName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ExamResultPage(examId: examId, examName: examName),
      ),
    );
  }

  /// Resolve potential download path from exam data
  String _getDownloadPath(Map<String, dynamic> exam) {
    const keys = [
      'attachment',
      'file',
      'exam_schedule_url',
      'schedule_file',
      'document',
      'pdf_url',
    ];

    for (final key in keys) {
      if (exam[key] != null) {
        final str = exam[key].toString().trim();
        if (str.isNotEmpty && str.toLowerCase() != 'null') {
          return str;
        }
      }
    }
    return '';
  }

  Future<void> _downloadExamSchedule(String rawPath) async {
    try {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: TranslatedText('Opening exam schedule...'),
          duration: Duration(seconds: 2),
        ),
      );

      final urlString = await _resolveScheduleUrl(rawPath);
      if (urlString.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Document URL not available.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final launched = await launchUrlString(
        urlString,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: TranslatedText('Could not open document.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      
    }
  }

  Future<String> _resolveScheduleUrl(String path) async {
    try {
      var trimmed = path.trim();
      if (trimmed.isEmpty) return '';
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return '';

      trimmed = trimmed.replaceAll('\\', '/');
      if (trimmed.startsWith('/')) trimmed = trimmed.substring(1);
      if (!trimmed.startsWith('uploads/')) trimmed = 'uploads/$trimmed';

      return '$baseUrl/$trimmed';
    } catch (e) {
      return '';
    }
  }
}
