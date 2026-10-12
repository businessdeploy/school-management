import 'package:flutter/material.dart';
import '../models/online_exam.dart';
import 'package:schoolapp/services/api/online_exam_api.dart';
import 'package:flutter_html/flutter_html.dart';
import '../widgets/translated_text.dart';
import '../services/auth_service.dart';

class OnlineExamResultPage extends StatefulWidget {
  final OnlineExam exam;

  const OnlineExamResultPage({super.key, required this.exam});

  @override
  State<OnlineExamResultPage> createState() => _OnlineExamResultPageState();
}

class _OnlineExamResultPageState extends State<OnlineExamResultPage> {
  bool _loading = true;
  Map<String, dynamic>? _resultData;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  Future<void> _fetchResult() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final onlineexamStudentId = widget.exam.onlineexamStudentId;
      final examId = widget.exam.id;
      final studentId = await AuthService.getStudentId();

      if (onlineexamStudentId.isEmpty || examId.isEmpty) {
        throw Exception('Student ID or Exam ID missing');
      }

      final response = await OnlineExamApi.getOnlineExamResult(
        onlineexamStudentId, 
        examId,
        studentId: studentId.isNotEmpty ? studentId : null,
      );

      final status = response['status']?.toString();
      // Check for status 1 OR if we have valid result data
      if (status == '1' || status == 'success' || status == '200' || response['result'] != null) {
        setState(() {
          _resultData = response['result'];
          _loading = false;
          
          if (_resultData != null && _resultData!['question_result'] != null) {
             
          }
        });
      } else {
        setState(() {
          _error = response['message']?.toString() ?? 'Failed to load result';
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const TranslatedText('Exam Result')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const TranslatedText('Exam Result')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchResult,
                  child: const TranslatedText('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final result = _resultData;
    
    // Robust key extraction helper - checks top level and nested "exam" object
    String pick(List<String> keys) {
      if (result == null) return 'N/A';
      
      // 1. Try top level
      for (final key in keys) {
        if (result.containsKey(key) == true && result[key] != null) {
          return result[key]!.toString();
        }
      }
      
      // 2. Try inside "exam" map if it exists
      if (result.containsKey('exam') == true && result['exam'] is Map) {
        final examMap = result['exam'] as Map;
        for (final key in keys) {
          if (examMap.containsKey(key) && examMap[key] != null) {
            return examMap[key]!.toString();
          }
        }
      }
      
      return 'N/A';
    }

    final totalQuestions = pick(['total_question', 'total_questions', 'questions_count']);
    final correctAnswers = pick(['correct_ans', 'correct_answers', 'correct']);
    final wrongAnswers = pick(['wrong_ans', 'wrong_answers', 'wrong']);
    final scoreResult = pick(['score', 'marks', 'obtained_marks', 'exam_total_scored']);
    final percentage = pick(['percentage', 'result_percentage', 'score_percentage']);
    final passingPercentageStr = pick(['passing_percentage', 'pass_percentage']);
    
    // Use passing percentage from API if available, otherwise fallback to widget
    final displayPassingPercentage = passingPercentageStr == 'N/A' 
        ? widget.exam.passingPercentage 
        : passingPercentageStr;
        
    // If percentage is still N/A, try to calculate it
    String displayPercentage = percentage == 'N/A' ? '0' : percentage;
    if (displayPercentage.endsWith('%')) {
      displayPercentage = displayPercentage.substring(0, displayPercentage.length - 1);
    }
    
    // 1. Prioritize calculation from Correct/Total if available (most reliable for MCQs)
    double? calcFromQuestions;
    if (totalQuestions != 'N/A' && correctAnswers != 'N/A') {
      try {
        final total = double.parse(totalQuestions);
        final correct = double.parse(correctAnswers);
        if (total > 0) {
          calcFromQuestions = (correct / total * 100);
        }
      } catch (_) {}
    }

    // 2. If API percentage is missing or suspicious (e.g. 0 or > 100), use calculation
    bool isSuspicious = (displayPercentage == '0' || displayPercentage == 'N/A');
    try {
       final pValue = double.parse(displayPercentage);
       if (pValue > 100.1 || pValue < 0) isSuspicious = true;
    } catch (_) { isSuspicious = true; }

    if (isSuspicious && calcFromQuestions != null) {
       displayPercentage = calcFromQuestions.toStringAsFixed(2);
    } else if (isSuspicious) {
       // Try (score / total_marks) * 100 as last resort
       final totalMarksStr = pick(['exam_total_marks', 'total_marks']);
       final scoreStr = scoreResult;
       if (totalMarksStr != 'N/A' && scoreStr != 'N/A') {
          try {
             final totalMarks = double.parse(totalMarksStr);
             final score = double.parse(scoreStr);
             if (totalMarks > 0) {
                double p = (score / totalMarks * 100);
                // If it's still > 100, might be because score is already a percentage
                if (p > 100.1 && score <= 100.1) p = score;
                displayPercentage = p.toStringAsFixed(2);
             }
          } catch (_) {}
       }
    }

    // Final safety: normalize display string
    if (displayPercentage.endsWith('.00')) {
       displayPercentage = displayPercentage.substring(0, displayPercentage.length - 3);
    }
    if (displayPercentage == 'N/A') displayPercentage = '0';

    // Determine pass/fail status
    final examStatus = pick(['exam_status', 'result_status', 'status']).toLowerCase();
    
    bool calculatedPassed = false;
    try {
      final p = double.parse(displayPercentage);
      final pp = double.parse(displayPassingPercentage);
      calculatedPassed = p >= pp;
    } catch (_) {}

    final isPassed = examStatus == 'pass' || examStatus == 'passed' || examStatus == 'success' || 
                    (examStatus == 'n/a' && calculatedPassed);
    
    final displayStatus = examStatus == 'n/a' 
        ? (calculatedPassed ? 'PASSED' : 'FAILED') 
        : examStatus.toUpperCase();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const TranslatedText(
              'Exam Result: ',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            Flexible(
              child: Text(
                widget.exam.exam,
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green[600],
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Result header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 64,
                      color: Colors.amber[600],
                    ),
                    const SizedBox(height: 16),
                    const TranslatedText(
                      'Exam Completed!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.exam.exam,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Score card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const TranslatedText(
                      'Your Score',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Score display
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.green[600]!,
                          width: 4,
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '$displayPercentage%',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.green[600] : Colors.red[600],
                              ),
                            ),
                            Text(
                              displayStatus,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isPassed ? Colors.green[600] : Colors.red[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Score details
                    _buildScoreDetail('Total Questions', totalQuestions),
                    _buildScoreDetail('Correct Answers', correctAnswers),
                    _buildScoreDetail('Wrong Answers', wrongAnswers),
                    _buildScoreDetail('Passing Percentage', '$displayPassingPercentage%'),
                    _buildScoreDetail('Your Percentage', '$displayPercentage%'),
                    if (scoreResult != '0' && scoreResult != 'N/A') _buildScoreDetail('Marks Obtained', scoreResult),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Exam details
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TranslatedText(
                      'Exam Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildDetailRow('Exam From:', widget.exam.formattedExamFrom),
                    _buildDetailRow('Exam To:', widget.exam.formattedExamTo),
                    _buildDetailRow('Duration:', widget.exam.formattedDuration),
                    _buildDetailRow('Status:', widget.exam.status),
                    _buildDetailRow('Attempted:', widget.exam.isAttempted == '1' ? 'Yes' : 'No'),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Action buttons
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to detailed result view
                          _showDetailedResult();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText(
                          'View Detailed Result',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const TranslatedText(
                          'Back to Exams',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TranslatedText(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
          SizedBox(
            width: 100,
            child: TranslatedText(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailedResult() {
    final result = _resultData;
    final questionsRaw = result?['question_result'] ?? result?['questions'] ?? result?['question_list'];
    
    if (questionsRaw == null || questionsRaw is! List || questionsRaw.isEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const TranslatedText('Detailed Result'),
          content: const TranslatedText(
            'Detailed question-wise breakdown is not available for this exam.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const TranslatedText('Close'),
            ),
          ],
        ),
      );
      return;
    }

    final List questions = questionsRaw;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const TranslatedText('Detailed Result'),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: questions.length,
            itemBuilder: (context, index) {
              final q = questions[index];
              final questionTitle = q['question']?.toString() ?? 'Question';
              final selectOption = q['select_option']?.toString() ?? 
                                   q['select_ans']?.toString() ?? 
                                   q['answer']?.toString();
              final String displaySelectOption = (selectOption == null || selectOption.isEmpty) 
                  ? '(No Answer Recorded)' 
                  : selectOption;
              
              final correctOption = q['correct_ans']?.toString() ?? 
                                   q['correct']?.toString() ?? 
                                   q['correct_answer']?.toString() ?? 
                                   'N/A';
              
              // Only mark as correct if we actually have an answer
              final isCorrect = (selectOption != null && selectOption.isNotEmpty) && 
                                selectOption.toLowerCase() == correctOption.toLowerCase();

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Q${index + 1}:',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Html(data: questionTitle),
                      const Divider(),
                      const SizedBox(height: 8),
                      // Helper to get option text
                      _buildAnswerRow('Your Answer: ', displaySelectOption, q, isCorrect: isCorrect, isUserAnswer: true),
                      _buildAnswerRow('Correct Answer: ', correctOption, q, isCorrect: true, isUserAnswer: false),
                    ],
                  ),
                ),
              );
            },
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
  }

  Widget _buildAnswerRow(String label, String optionKey, Map q, {required bool isCorrect, required bool isUserAnswer}) {
    String displayText = optionKey;
    Color? textColor;
    
    if (optionKey == '(No Answer Recorded)') {
       textColor = Colors.red[700];
    } else {
        // Resolve option text if it's one of the standard keys
        final standardKeys = ['opt_a', 'opt_b', 'opt_c', 'opt_d', 'opt_e'];
        if (standardKeys.contains(optionKey.toLowerCase())) {
           final val = q[optionKey.toLowerCase()];
           if (val != null && val.toString().isNotEmpty) {
              displayText = val.toString();
           } else {
              // Option key exists (e.g. opt_a) but text is empty
              displayText = "Option ${optionKey.split('_').last.toUpperCase()} (Text Missing)";
           }
        } else if (optionKey.toLowerCase() == 'true' || optionKey.toLowerCase() == 'false') {
           displayText = optionKey.toUpperCase();
        }
    }
    
    // Set color: User answer gets green/red based on correctness. Correct answer is always green.
    if (textColor == null) {
        if (isUserAnswer) {
            textColor = isCorrect ? Colors.green[700] : Colors.red[700];
        } else {
            textColor = Colors.green[700];
        }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            label, 
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
          ),
          Expanded(
            child: Html(
              data: displayText,
              style: {
                "body": Style(
                  fontSize: FontSize(12),
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  margin: Margins.zero,
                  padding: HtmlPaddings.zero,
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}
