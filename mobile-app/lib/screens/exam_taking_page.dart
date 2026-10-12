import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter/services.dart';
import '../models/online_exam.dart';
import '../services/api/online_exam_api.dart';
import '../services/api/course_api.dart';
import '../services/auth_service.dart';
import 'package:schoolapp/widgets/translated_text.dart';
import 'online_exam_result_page.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

class ExamTakingPage extends StatefulWidget {
  final OnlineExam onlineExam;
  final String studentId;

  final bool isCourseExam;

  const ExamTakingPage({
    super.key,
    required this.onlineExam,
    this.studentId = '',
    this.isCourseExam = false,
    this.curriculumCurl,
    this.curriculumRawData,
  });

  final String? curriculumCurl;
  final String? curriculumRawData;

  @override
  State<ExamTakingPage> createState() => _ExamTakingPageState();
}

class _ExamTakingPageState extends State<ExamTakingPage> {
  // ... (keep state variables)
  List<Map<String, dynamic>> questions = [];
  Map<String, String> answers = {};
  bool isLoading = true;
  String? error;
  int currentQuestionIndex = 0;
  Duration remainingTime = const Duration(hours: 0);
  bool hasTimer = true;
  Timer? _timer;
  bool isExamSubmitted = false;
  String? lastRawResponse;
  String? lastCurl;
  List<Map<String, String>> attemptHistory = [];
  bool showDebugInfo = false;
  bool showCurriculumInfo = false;
  String? actualOnlineExamStudentId;
  Map<String, String?> questionAttachments = {}; // question_id -> file_path

  @override
  void initState() {
    super.initState();
    _loadExamQuestions();
    _startTimer();
  }

  // ... (keep dispose and timer)
  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (!hasTimer) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (remainingTime.inSeconds > 0) {
        if (mounted) {
          setState(() {
            remainingTime = Duration(seconds: remainingTime.inSeconds - 1);
          });
        }
      } else {
        timer.cancel();
        _submitExam();
      }
    });
  }

  Future<void> _loadExamQuestions() async {
    try {
      setState(() {
        isLoading = true;
        error = null;

        // Initialize duration from onlineExam
        if (widget.onlineExam.duration.isNotEmpty && widget.onlineExam.duration != '00:00:00') {
          try {
            final parts = widget.onlineExam.duration.split(':');
            if (parts.length == 3) {
              remainingTime = Duration(
                hours: int.parse(parts[0]),
                minutes: int.parse(parts[1]),
                seconds: int.parse(parts[2]),
              );
              hasTimer = remainingTime.inSeconds > 0;
            } else if (parts.length == 2) {
              remainingTime = Duration(
                minutes: int.parse(parts[0]),
                seconds: int.parse(parts[1]),
              );
              hasTimer = remainingTime.inSeconds > 0;
            } else {
              hasTimer = false;
            }
          } catch (e) {
            hasTimer = false;
          }
        } else {
          hasTimer = false;
        }
      });

      // Get student ID if not provided
      final studentId = widget.studentId.isEmpty 
          ? await AuthService.getStudentId() 
          : widget.studentId;

      // ID Fallback Logic
      // 1. Try widget.onlineExam.id (usually lesson_quiz_id)
      // 2. Try widget.onlineExam.rawExam['id'] (usually item ID, e.g. 230)
      // 3. Try widget.onlineExam.rawExam['course_exam_id'] (if different)
      
      
      
      final List<String> candidateIds = [];
      
      // CRITICAL: Ensure the ID passed from previous screen is tried
      if (widget.onlineExam.id.isNotEmpty) {
        candidateIds.add(widget.onlineExam.id);
      }

      // PRECEDENCE RULES:
      // 1. If it's an EXAM, prioritize course_exam_id
      // 2. If it's an ASSIGNMENT, prioritize course_assignment_id
      // 3. If it's a QUIZ, prioritize quiz_id/course_quizzes_id
      
      final type = widget.onlineExam.rawExam['type']?.toString().toLowerCase() ?? '';
      
      if (type == 'exam') {
        if (widget.onlineExam.rawExam.containsKey('course_exam_id')) {
          final ceid = widget.onlineExam.rawExam['course_exam_id'].toString();
          if (!candidateIds.contains(ceid)) candidateIds.add(ceid);
        }
      } else if (type == 'assignment') {
        if (widget.onlineExam.rawExam.containsKey('course_assignment_id')) {
          final caid = widget.onlineExam.rawExam['course_assignment_id'].toString();
          if (!candidateIds.contains(caid)) candidateIds.add(caid);
        }
      } else if (type == 'quiz') {
        if (widget.onlineExam.rawExam.containsKey('quiz_id')) {
          final qid = widget.onlineExam.rawExam['quiz_id'].toString();
          if (!candidateIds.contains(qid)) candidateIds.add(qid);
        }
        if (widget.onlineExam.rawExam.containsKey('quiz id')) {
          final qid = widget.onlineExam.rawExam['quiz id'].toString();
          if (!candidateIds.contains(qid)) candidateIds.add(qid);
        }
      }

      
      Map<String, dynamic> response = {};
      bool foundQuestions = false;

      attemptHistory.clear();
      
      for (final quizId in candidateIds) {
        try {
          if (widget.isCourseExam) {
            // ALL assessments in a course curriculum (quizzes AND exams) use this API
            response = await CourseApi.getQuestionByQuizId(studentId, quizId);
            
            // FALLBACK: If CourseApi failed or returned no questions, try the standard OnlineExamApi
            final resultExam = response['exam'] ?? response['result'];
            final hasQuestions = resultExam != null && 
                                resultExam['questions'] != null && 
                                (resultExam['questions'] as List).isNotEmpty;

            if ((response['status'] != 1 && response['status'] != '1' && !hasQuestions) || !hasQuestions) {
              final fallbackResponse = await OnlineExamApi.getOnlineExamQuestion(studentId, quizId);
              
              final fallbackExam = fallbackResponse['exam'] ?? fallbackResponse['result'];
              if ((fallbackResponse['status'] == 1 || fallbackResponse['status'] == '1') && 
                  fallbackExam != null && 
                  fallbackExam['questions'] != null && 
                  (fallbackExam['questions'] as List).isNotEmpty) {
                response = fallbackResponse;
              }
            }
          } else {
            // General online exams (outside of courses)
            response = await OnlineExamApi.getOnlineExamQuestion(studentId, quizId);
          }
          
          // Capture debug info
          final currentRaw = response['debug_raw_body']?.toString() ?? 'N/A';
          final currentCurl = response['debug_curl']?.toString() ?? 'N/A';
          
          attemptHistory.add({
            'id': quizId,
            'curl': currentCurl,
            'raw': currentRaw,
            'status': response['status']?.toString() ?? '0',
            'message': response['message']?.toString() ?? 'No message',
          });
          
          // Check if we actually got questions - prioritize data presence over status field
          final resultExam = response['exam'] ?? response['result'];
          final hasActualQuestions = resultExam != null && 
                                     resultExam['questions'] != null && 
                                     (resultExam['questions'] as List).isNotEmpty;

          if (hasActualQuestions || response['status'] == 1 || response['status'] == '1') {
            if (hasActualQuestions) {
              foundQuestions = true;
              break; 
            }
          }
        } catch (e) {
          
        }
      }

      // Check if we exhausted all candidates without success
      if (!foundQuestions) {
        
        setState(() {
          error = 'No questions found.\n(Tried IDs: ${candidateIds.join(", ")})\nLast error: ${response['message']}';
          isLoading = false;
        });
        return;
      }

      // Check for questions in the API response structure
      List<Map<String, dynamic>> questionsList = [];
      
      if (foundQuestions) {
        final resultExam = response['exam'] ?? response['result'];
        questionsList = List<Map<String, dynamic>>.from(resultExam['questions']);

        // CRITICAL: Extract the actual onlineexam_student_id required for submission
        // This ID is the unique link between student and exam, often different from record_id
        final serverSubmissionId = resultExam['onlineexam_student_id']?.toString();
        if (serverSubmissionId != null && serverSubmissionId.isNotEmpty) {
          actualOnlineExamStudentId = serverSubmissionId;
        }
      } else {
        // ... (existing error handling for no questions)
        
        // Improve error message to show what WAS found
        String debugInfo = 'Keys: ${response.keys.toList()}';
        if (response['exam'] != null) {
           debugInfo += '\nExam Keys: ${response['exam'].keys.toList()}';
        }
        
        setState(() {
          error = 'No questions found for this exam.\nTried IDs: $candidateIds\n(Debug: $debugInfo)';
          isLoading = false;
        });
        return;
      }

      // Process questions to match the expected format
      for (int i = 0; i < questionsList.length; i++) {
        final question = questionsList[i];
        
        // Convert API format to our expected format
        List<Map<String, String>> options = [];
        String questionType = question['question_type'] ?? 'singlechoice';
        
        // Determine the "True" ID that the API wants for submission
        // Per user screenshot, the "id" field (e.g. 3179) should be used as onlineexam_question_id
        final String resolvedId = (question['id'] ?? question['onlineexam_question_id'] ?? question['question_id'] ?? '').toString();
        question['resolved_id'] = resolvedId;

        // Handle different question types
        if (questionType == 'true_false') {
          options = [
            {'id': 'True', 'text': 'True'},
            {'id': 'False', 'text': 'False'}
          ];
        } else if (questionType == 'singlechoice') {
          // Rule: Support both 'opt_a'..'opt_e' and 'option_1'..'option_5'
          // Standard smartschool format
          final standardOpts = ['opt_a', 'opt_b', 'opt_c', 'opt_d', 'opt_e'];
          // Course Quiz specific format (normalized from getquestionbyquizid)
          final courseQuizOpts = ['option_1', 'option_2', 'option_3', 'option_4', 'option_5'];
          
          for (int idx = 0; idx < standardOpts.length; idx++) {
            final optKey = standardOpts[idx];
            final optionKey = courseQuizOpts[idx];
            
            final String? standardVal = question[optKey]?.toString();
            final String? courseVal = question[optionKey]?.toString();
            
            final String text = (standardVal != null && standardVal.isNotEmpty && standardVal != 'null') 
                ? standardVal 
                : (courseVal != null && courseVal.isNotEmpty && courseVal != 'null') ? courseVal : '';

            if (text.isNotEmpty) {
              // We map everything to opt_a, opt_b, etc. for submission consistency if needed,
              // OR we use the key that was found. 
              // Most submission APIs expect the key (opt_a, opt_b) OR the value.
              // For getquestionbyquizid, the correct_answer is 'option_4', so we should stick to 'option_X' if it's a quiz.
              final String finalId = (courseVal != null && courseVal.isNotEmpty) ? optionKey : optKey;
              
              options.add({
                'id': finalId,
                'text': text,
              });
            }
          }
        }
        
        // Update question with processed data
        question['options'] = options;
        question['type'] = questionType == 'descriptive' ? 'descriptive' : 'multiple_choice';
        question['question'] = question['question'].toString();
      }

      if (questionsList.isNotEmpty) {
        // Rule 5: Use remaining_duration from API if available
        Duration duration = remainingTime;
        final apiRemaining = response['exam']?['remaining_duration']?.toString();
        if (apiRemaining != null && apiRemaining.isNotEmpty) {
          final parts = apiRemaining.split(':');
          if (parts.length == 3) {
            final h = int.parse(parts[0]);
            final m = int.parse(parts[1]);
            final s = int.parse(parts[2]);
            duration = Duration(hours: h, minutes: m, seconds: s);
          }
        }

        setState(() {
          questions = questionsList;
          remainingTime = duration;
          isLoading = false;
        });
        _startTimer();
      } else {
        setState(() {
          error = 'No questions found for this exam. Please check with your teacher or try again later.';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load exam questions: $e';
        isLoading = false;
      });
    }
  }

  String _stripHtml(String htmlString) {
    if (htmlString.isEmpty) return '';
    // Simple regex to strip HTML tags
    return htmlString.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  void _submitExam() async {
    if (isExamSubmitted) {
      return;
    }

    try {
      _timer?.cancel();
      
      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                const TranslatedText('Submitting exam...'),
              ],
            ),
          ),
        ),
      );

      // Use captured ID if available, otherwise fallback to widget ID
      final onlineexamStudentId = actualOnlineExamStudentId ?? widget.onlineExam.onlineexamStudentId;
      
      if (onlineexamStudentId.isEmpty) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: TranslatedText('Error: Exam ID not found. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (onlineexamStudentId.isEmpty) {
        // (Error notification already handled)
        return;
      }

      // Prepare answer rows for API
      List<Map<String, dynamic>> rows = [];
      for (var question in questions) {
        final resolvedId = (question['resolved_id'] ?? '').toString();
        final questionType = (question['question_type'] ?? question['type'] ?? 'singlechoice').toString();
        // answers[resolvedId] contains the select_option (e.g. opt_a, opt_b) or descriptive text
        final answer = answers[resolvedId] ?? '';

        if (resolvedId.isNotEmpty) {
          rows.add({
            'onlineexam_student_id': onlineexamStudentId,
            'question_type': questionType,
            'onlineexam_question_id': resolvedId,
            'select_option': answer,
          });
        }
      }

      // Submit exam answers to API
      final response = await OnlineExamApi.saveOnlineExamWithAttachments(
        onlineexamStudentId: onlineexamStudentId,
        rows: rows,
        attachments: questionAttachments,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      final status = response['status'];
      final message = response['message']?.toString() ?? 'Exam submitted successfully';

      if (status == 1 || status == '1') {
        setState(() {
          isExamSubmitted = true;
        });

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TranslatedText(
                      'Exam submitted successfully!',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );

          // Wait a moment then navigate to result page
          await Future.delayed(const Duration(seconds: 1));
          
          if (mounted) {
            // Navigate directly to result page
            // We use pushReplacement so the user can't go back to the exam taking page
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => OnlineExamResultPage(exam: widget.onlineExam),
              ),
            );
          }
        }
      } else {
        // Show error message
        final cleanMessage = _stripHtml(message);
        if (mounted) {
          // Show dialog for long error messages
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const TranslatedText('Submission Failed'),
              content: SingleChildScrollView(
                child: Text(cleanMessage),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const TranslatedText('Close'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog if still open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: TranslatedText('Submission Failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          widget.onlineExam.exam,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        backgroundColor: Colors.indigo[700],
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo[600]!, Colors.indigo[800]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (hasTimer)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: remainingTime.inSeconds < 300 
                    ? Colors.red[600] 
                    : Colors.green[600],
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: (remainingTime.inSeconds < 300 ? Colors.red : Colors.green)
                        .withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatDuration(remainingTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: isLoading
          ? _buildLoadingView()
          : error != null
              ? _buildErrorView()
              : isExamSubmitted
                  ? _buildSubmissionView()
                  : _buildExamInterface(),
    );
  }

  Widget _buildLoadingView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                shape: BoxShape.circle,
              ),
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo[600]!),
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            TranslatedText(
              'Loading Exam Questions...',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              'Please wait while we prepare your exam',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 24),
              TranslatedText(
                'Oops! Something went wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                error!,
                style: TextStyle(
                  fontSize: 14, // Slightly smaller
                  color: Colors.red[800], // Red for visibility
                  height: 1.5,
                  fontFamily: 'Courier', // Monospace for debug info
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _loadExamQuestions,
                  icon: const Icon(Icons.refresh),
                  label: const TranslatedText('Try Again'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // 1. QUIZ API DEBUGGING SECTION
              if (attemptHistory.isNotEmpty) ...[
                TextButton.icon(
                  onPressed: () => setState(() => showDebugInfo = !showDebugInfo),
                  icon: Icon(showDebugInfo ? Icons.keyboard_arrow_up : Icons.bug_report),
                  label: Text(showDebugInfo ? 'Hide Quiz API Debug' : 'Show Quiz API Debug (Attempts History)'),
                  style: TextButton.styleFrom(foregroundColor: Colors.indigo[700]),
                ),
                if (showDebugInfo)
                   ...attemptHistory.map((attempt) {
                     return Container(
                       margin: const EdgeInsets.only(bottom: 8),
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: Colors.indigo.withOpacity(0.2)),
                       ),
                       child: ExpansionTile(
                         initiallyExpanded: attempt == attemptHistory.last,
                         title: Text(
                           'Attempt Quiz ID: ${attempt['id']}',
                           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                         ),
                         subtitle: Text(
                           'Status: ${attempt['status']} (${attempt['message']})',
                           style: TextStyle(
                             fontSize: 11, 
                             color: attempt['status'] == '1' ? Colors.green : Colors.red[700],
                             fontWeight: FontWeight.w500
                           ),
                         ),
                         children: [
                           _buildDebugPanel(
                             'QUIZ API REQUEST (cURL):', 
                             attempt['curl'] ?? 'N/A', 
                             'QUIZ API RESPONSE (RAW):', 
                             attempt['raw'] ?? 'N/A'
                           ),
                         ],
                       ),
                     );
                   }).toList(),
              ],
              
              // 2. CURRICULUM API DEBUGGING SECTION
              if (widget.curriculumCurl != null || widget.curriculumRawData != null) ...[
                TextButton.icon(
                  onPressed: () => setState(() => showCurriculumInfo = !showCurriculumInfo),
                  icon: Icon(showCurriculumInfo ? Icons.keyboard_arrow_up : Icons.list_alt),
                  label: Text(showCurriculumInfo ? 'Hide Curriculum Debug' : 'Show Curriculum Debug (Source of IDs)'),
                  style: TextButton.styleFrom(foregroundColor: Colors.green[800]),
                ),
                if (showCurriculumInfo)
                   _buildDebugPanel(
                     'CURRICULUM REQUEST (cURL):', 
                     widget.curriculumCurl ?? 'N/A', 
                     'CURRICULUM RESPONSE (RAW):', 
                     widget.curriculumRawData ?? 'N/A'
                   ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

  Widget _buildDebugPanel(String reqTitle, String reqContent, String resTitle, String resContent) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.grey[300]!),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDebugSection(reqTitle, reqContent),
          const Divider(height: 16),
          _buildDebugSection(resTitle, resContent),
        ],
      ),
    );
  }

  Widget _buildDebugSection(String title, String content) {
    bool hasContent = content.isNotEmpty && content != 'N/A';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 9, color: Colors.blueGrey),
            ),
            if (hasContent)
             IconButton(
               icon: const Icon(Icons.copy, size: 14),
               padding: EdgeInsets.zero,
               constraints: const BoxConstraints(),
               onPressed: () {
                 Clipboard.setData(ClipboardData(text: content));
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                 );
               },
             ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white, 
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey[200]!)
          ),
          constraints: const BoxConstraints(maxHeight: 150),
          width: double.infinity,
          child: SingleChildScrollView(
            child: Text(
              content,
              style: TextStyle(
                fontFamily: 'Courier', 
                fontSize: 9, 
                color: hasContent ? Colors.black87 : Colors.grey
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmissionView() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25),
          topRight: Radius.circular(25),
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  size: 64,
                  color: Colors.green[400],
                ),
              ),
              const SizedBox(height: 24),
              TranslatedText(
                'Exam Submitted Successfully!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              TranslatedText(
                'Your answers have been saved. Results will be available soon.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.home),
                  label: const TranslatedText('Back to Exams'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamInterface() {
    if (questions.isEmpty) {
      return _buildErrorView();
    }

    return Column(
      children: [
        // Header with progress
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            children: [
              // Exam info section
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Exam title and description
                    Text(
                      widget.onlineExam.exam,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    if (widget.onlineExam.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Html(
                        data: widget.onlineExam.description,
                        style: {
                          "body": Style(
                            fontSize: FontSize(14),
                            color: Colors.grey[600],
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                          ),
                        },
                      ),
                    ],
                    const SizedBox(height: 12),
                    // Exam details row
                    Row(
                      children: [
                        // Passing percentage
                        if (widget.onlineExam.passingPercentage.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TranslatedText(
                                  'Pass: ',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  '${widget.onlineExam.passingPercentage}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Negative marking
                        if (widget.onlineExam.isNegMarking == '1') ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: TranslatedText(
                              'Negative Marking',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.red[700],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Question counter
              Container(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.indigo[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TranslatedText(
                            'Question',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo[700],
                            ),
                          ),
                          Text(
                            ' ${currentQuestionIndex + 1} ',
                             style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                            ),
                          ),
                          TranslatedText(
                            'of',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo[700],
                            ),
                          ),
                          Text(
                            ' ${questions.length}',
                             style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.indigo,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           Text(
                            '${((currentQuestionIndex + 1) / questions.length * 100).round()}% ',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green,
                            ),
                          ),
                          TranslatedText(
                            'Complete',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Progress bar
              Container(
                margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                child: LinearProgressIndicator(
                  value: (currentQuestionIndex + 1) / questions.length,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo[600]!),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ),
        
        // Question content
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _buildQuestionContent(),
            ),
          ),
        ),
        
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(25),
              topRight: Radius.circular(25),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (currentQuestionIndex > 0)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        currentQuestionIndex--;
                      });
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const TranslatedText('Previous'),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[400]!),
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              if (currentQuestionIndex > 0) const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: currentQuestionIndex < questions.length - 1
                    ? ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            currentQuestionIndex++;
                          });
                        },
                        icon: const Icon(Icons.arrow_forward),
                        label: const TranslatedText('Next Question'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: _submitExam,
                        icon: const Icon(Icons.check),
                        label: const TranslatedText('Submit Exam'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionContent() {
    if (questions.isEmpty) return const SizedBox();
    
    final question = questions[currentQuestionIndex];
    final questionText = question['question'] ?? 'No question text';
    final options = question['options'] ?? [];
    final questionType = question['type'] ?? 'multiple_choice';
    final String resolvedId = (question['resolved_id'] ?? '').toString();
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and text - matching 3rd image style
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[300]!, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  // Question number and marks
                  Row(
                    children: [
                      Text(
                        '${currentQuestionIndex + 1}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      if (question['marks'] != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.amber[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber[200]!),
                          ),
                          child: Text(
                            '${question['marks']} marks',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.amber[700],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                const SizedBox(height: 12),
                // Question text
                Html(
                  data: questionText,
                  style: {
                    "body": Style(
                      fontSize: FontSize(18),
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[800],
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
             // Answer options - matching 3rd image with radio buttons
             if (questionType == 'multiple_choice' && options.isNotEmpty) ...[
               ...options.map<Widget>((optionMap) {
                 final String optionId = optionMap['id'] ?? '';
                 final String optionText = optionMap['text'] ?? '';
                 final String rId = (question['resolved_id'] ?? '').toString();
                 final isSelected = answers[rId] == optionId;
                 
                 return Container(
                   margin: const EdgeInsets.only(bottom: 16),
                   child: InkWell(
                     onTap: () {
                       setState(() {
                         answers[rId] = optionId;
                       });
                     },
                     borderRadius: BorderRadius.circular(12),
                     child: Container(
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: Colors.white,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(
                           color: isSelected ? Colors.green[400]! : Colors.grey[300]!,
                           width: isSelected ? 2 : 1,
                         ),
                         boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.05),
                             blurRadius: 4,
                             offset: const Offset(0, 1),
                           ),
                         ],
                       ),
                       child: Row(
                         children: [
                           // Radio button
                           Container(
                             width: 24,
                             height: 24,
                             decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               border: Border.all(
                                 color: isSelected ? Colors.green[600]! : Colors.grey[400]!,
                                 width: 2,
                               ),
                             ),
                             child: isSelected
                                 ? Center(
                                     child: Container(
                                       width: 12,
                                       height: 12,
                                       decoration: BoxDecoration(
                                         color: Colors.green[600],
                                         shape: BoxShape.circle,
                                       ),
                                     ),
                                   )
                                 : null,
                           ),
                           const SizedBox(width: 16),
                           Expanded(
                             child: Html(
                               data: optionText,
                               style: {
                                 "body": Style(
                                   fontSize: FontSize(16),
                                   color: isSelected ? Colors.green[700] : Colors.grey[700],
                                   fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                   margin: Margins.zero,
                                   padding: HtmlPaddings.zero,
                                 ),
                               },
                             ),
                           ),
                         ],
                       ),
                     ),
                   ),
                 );
               }).toList(),
             ] else ...[
            // Text input for descriptive questions
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Attachments Section
                const TranslatedText(
                  'Attachment',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                
                InkWell(
                  onTap: () => _pickAttachment(resolvedId),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.cloud_upload_outlined, color: Colors.indigo[600], size: 32),
                        const SizedBox(height: 8),
                        if (questionAttachments[resolvedId] == null)
                          const TranslatedText(
                            'Tap to upload a file (image, PDF, etc.)',
                            style: TextStyle(fontSize: 13, color: Colors.grey),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  questionAttachments[resolvedId]!.split('/').last,
                                  style: TextStyle(
                                    fontSize: 13, 
                                    color: Colors.indigo[700],
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.red),
                                onPressed: () => _removeAttachment(resolvedId),
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                const TranslatedText(
                  'Answer:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        answers[resolvedId] = value;
                      });
                    },
                    maxLines: 5,
                    controller: TextEditingController(text: answers[resolvedId] ?? '')..selection = TextSelection.collapsed(offset: (answers[resolvedId] ?? '').length),
                    decoration: InputDecoration(
                      hintText: 'Enter your detailed answer here...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _pickAttachment(String questionId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          questionAttachments[questionId] = result.files.single.path;
        });
      
      }
    } catch (e) {
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  void _removeAttachment(String questionId) {
    setState(() {
      questionAttachments.remove(questionId);
    });
    
  }

  String _cleanHtmlText(String text) {
    // Remove HTML tags and clean the text
    return text
        .replaceAll(RegExp(r'<[^>]*>'), '') // Remove HTML tags
        .replaceAll(RegExp(r'&nbsp;'), ' ') // Replace &nbsp; with space
        .replaceAll(RegExp(r'&amp;'), '&') // Replace &amp; with &
        .replaceAll(RegExp(r'&lt;'), '<') // Replace &lt; with <
        .replaceAll(RegExp(r'&gt;'), '>') // Replace &gt; with >
        .replaceAll(RegExp(r'&quot;'), '"') // Replace &quot; with "
        .trim();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds";
  }

}