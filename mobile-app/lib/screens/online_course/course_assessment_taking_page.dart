import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../services/auth_service.dart';
import '../../utils/url_manager.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../widgets/translated_text.dart';
import '../../services/api/quiz_api.dart';

class CourseAssessmentTakingPage extends StatefulWidget {
  final String assessmentId;
  final String title;
  final bool isQuiz;
  final String duration;
  final Map<String, dynamic> rawItem;

  const CourseAssessmentTakingPage({
    super.key,
    required this.assessmentId,
    required this.title,
    this.isQuiz = true,
    this.duration = '00:00:00',
    required this.rawItem,
  });

  @override
  State<CourseAssessmentTakingPage> createState() => _CourseAssessmentTakingPageState();
}

class _CourseAssessmentTakingPageState extends State<CourseAssessmentTakingPage> {
  bool isLoading = true;
  String? error;
  List<dynamic> questions = [];
  Map<String, String> answers = {};
  int currentIndex = 0;
  
  Timer? _timer;
  Duration remainingTime = Duration.zero;
  bool hasTimer = false;
  
  String? debugCurl;
  String? debugResponse;

  @override
  void initState() {
    super.initState();
    _initializeDuration();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _initializeDuration() {
    if (widget.duration.isNotEmpty && widget.duration != '00:00:00') {
      try {
        final parts = widget.duration.split(':');
        if (parts.length == 3) {
          remainingTime = Duration(
            hours: int.parse(parts[0]),
            minutes: int.parse(parts[1]),
            seconds: int.parse(parts[2]),
          );
        } else if (parts.length == 2) {
          remainingTime = Duration(
            minutes: int.parse(parts[0]),
            seconds: int.parse(parts[1]),
          );
        }
        hasTimer = remainingTime.inSeconds > 0;
      } catch (e) {
        
        hasTimer = false;
      }
    } else {
      hasTimer = false;
    }
  }

  Future<void> _loadQuestions() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final studentId = await AuthService.getStudentId();
      final baseUrl = await UrlManager.getBaseUrl();
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      Uri url;
      String body;
      bool success = false;
      List<dynamic> qList = [];

      // STRICT API SEPARATION based on user request and cURL
      if (widget.isQuiz) {
          // --- QUIZ FLOW ---
          url = Uri.parse('$baseUrl/api/webservice/getquestionbyquizid');
          body = jsonEncode({
            'student_id': studentId,
            'quiz_id': widget.assessmentId,
          });
      } else {
          // --- EXAM FLOW ---
          // Use getOnlineCourseQuestion directly as requested
          url = Uri.parse('$baseUrl/api/webservice/getOnlineCourseQuestion');
          body = jsonEncode({
             'user_type': 'student',
             'student_id': studentId,
             'exam_id': widget.assessmentId, // Send as String match user cURL
          });
      }
      
      debugCurl = "curl -X POST \"$url\" -H \"Content-Type: application/json\" ... -d '$body'";
      
      var response = await http.post(url, headers: headers, body: body);
      debugResponse = response.body;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (widget.isQuiz) {
           qList = data['questionlist'] ?? data['questions'] ?? [];
           if (data['status'] == 1 || data['status'] == '1' || qList.isNotEmpty) {
              success = true;
           }
        } else {
           // Exam Response Parsing
           if (data['result'] != null && data['result']['question_list'] != null) {
              qList = data['result']['question_list'];
              success = true;
           } else if (data['questions'] != null) {
              qList = data['questions'];
              success = true;
           } else if (data['exam'] != null && data['exam']['questions'] != null) {
                // ... same parsing logic as before ...
               var rawQuestions = data['exam']['questions'] as List;
               List<Map<String, dynamic>> normalizedList = [];
               for (var q in rawQuestions) {
                 if (q is Map<String, dynamic>) {
                   var newQ = Map<String, dynamic>.from(q);
                   if (newQ['opt_a'] != null) newQ['option_1'] = newQ['opt_a'];
                   if (newQ['opt_b'] != null) newQ['option_2'] = newQ['opt_b'];
                   if (newQ['opt_c'] != null) newQ['option_3'] = newQ['opt_c'];
                   if (newQ['opt_d'] != null) newQ['option_4'] = newQ['opt_d'];
                   if (newQ['opt_e'] != null) newQ['option_5'] = newQ['opt_e'];
                   if (newQ['correct'] != null) newQ['correct_answer'] = newQ['correct'];
                   normalizedList.add(newQ);
                 }
               }
               qList = normalizedList;
               success = true;
           }
        }
      }

      if (success && qList.isNotEmpty) {
        if (mounted) {
           setState(() {
            questions = qList;
            isLoading = false;
            if (hasTimer) _startTimer();
          });
        }
      } else {
        if (mounted) {
           setState(() {
            // Check if response was HTML (server error) to show cleaner message
            if (debugResponse != null && debugResponse!.trim().startsWith('<')) {
               error = 'Questions not found (Server Error)';
            } else {
               error = 'No questions found for assessment ID ${widget.assessmentId}';
            }
            isLoading = false;
          });
        }
      }

    } catch (e) {
      if (mounted) {
         setState(() {
          // If it's a format exception (likely HTML response), show "Not Found" message
          if (e is FormatException) {
             error = 'Questions not found for this quiz.';
          } else {
             error = 'Error: $e';
          }
          isLoading = false;
        });
      }
    }
  }

  void _startTimer() {
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
        _submitAssessment();
      }
    });
  }

  Future<void> _submitAssessment() async {
    setState(() => isLoading = true);
    
    try {
      final studentId = await AuthService.getStudentId();
      Map<String, dynamic> result;

      // Prepare answers list for the API
      List<Map<String, dynamic>> answersList = [];
      answers.forEach((qIndex, selectedOption) {
        final int index = int.parse(qIndex);
        if (index < questions.length) {
          final question = questions[index];
          answersList.add({
            'question_id': question['question_id']?.toString() ?? question['id']?.toString(),
            'question_type': question['question_type']?.toString() ?? 'singlechoice',
            'select_option': selectedOption, // Changed from select_answer to key match cURL
          });
        }
      });

      if (widget.isQuiz) {
        result = await QuizApi.submitQuizAnswers(
          quizId: widget.assessmentId,
          studentId: studentId,
          rows: answersList,
        );
      } else {
        // Exam submission using saveOnlineCourseExam
        // cURL: {"student_id":"83","guest_id":"0","usertype":"student","exam_id":"10","rows":[...]}
        // We pass keys that match the cURL requirements.
        result = await QuizApi.saveOnlineCourseExam(
          examId: widget.assessmentId,
          studentId: studentId,
          rows: answersList,
        );
      }

      if (mounted) {
        setState(() => isLoading = false);
        if (result['status'] == 1 || result['status'] == '1') {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Assessment submitted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result['message'] ?? 'Failed to submit assessment')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: widget.isQuiz ? Colors.purple[700] : Colors.blue[900],
        foregroundColor: Colors.white,
        actions: [
          if (hasTimer)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Text(
                  _formatDuration(remainingTime),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? _buildErrorView()
              : _buildQuestionView(),
    );
  }

  Widget _buildErrorView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(error ?? 'Unknown error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          const Divider(),
          const Text('Debug info:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text(debugCurl ?? 'No cURL available', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[200],
            child: Text(debugResponse ?? 'No response available', style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _loadQuestions, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildQuestionView() {
    if (questions.isEmpty) return const Center(child: Text('No questions available'));

    final question = questions[currentIndex];
    final questionText = question['question'] ?? question['question_text'] ?? '';
    final options = [
      question['option_1'],
      question['option_2'],
      question['option_3'],
      question['option_4'],
      question['option_5'],
    ].where((o) => o != null && o.toString().isNotEmpty).toList();

    return Column(
      children: [
        LinearProgressIndicator(value: (currentIndex + 1) / questions.length),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Question ${currentIndex + 1} of ${questions.length}', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(questionText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 24),
                if (question['question_type'] == 'descriptive')
                  _buildDescriptiveAnswerBox(question)
                else
                  ...options.map((option) => _buildOptionTile(option.toString())),
              ],
            ),
          ),
        ),
        _buildNavigationButtons(),
      ],
    );
  }

  Widget _buildDescriptiveAnswerBox(Map<String, dynamic> question) {
    final currentAnswer = answers[currentIndex.toString()] ?? '';
    return TextField(
      controller: TextEditingController(text: currentAnswer)..selection = TextSelection.fromPosition(TextPosition(offset: currentAnswer.length)),
      maxLines: 8,
      decoration: InputDecoration(
        hintText: 'Type your answer here...',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      onChanged: (value) {
        answers[currentIndex.toString()] = value;
      },
    );
  }

  Widget _buildOptionTile(String option) {
    final isSelected = answers[currentIndex.toString()] == option;
    return GestureDetector(
      onTap: () => setState(() => answers[currentIndex.toString()] = option),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue[50] : Colors.white,
          border: Border.all(color: isSelected ? Colors.blue : Colors.grey[300]!, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(width: 12),
            Expanded(child: Text(option, style: TextStyle(fontSize: 16, color: isSelected ? Colors.blue[900] : Colors.black87))),
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationButtons() {
    final isLast = currentIndex == questions.length - 1;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (currentIndex > 0)
            TextButton(onPressed: () => setState(() => currentIndex--), child: const Text('PREVIOUS'))
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: isLast ? _submitAssessment : () => setState(() => currentIndex++),
            style: ElevatedButton.styleFrom(backgroundColor: isLast ? Colors.green : Colors.blue, foregroundColor: Colors.white),
            child: Text(isLast ? 'SUBMIT' : 'NEXT'),
          ),
        ],
      ),
    );
  }
}
