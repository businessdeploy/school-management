import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/services.dart';
import '../../models/quiz_model.dart';
import '../../services/api/quiz_api.dart';
import '../../services/auth_service.dart';
import 'quiz_result_page.dart';

class QuizAttemptPage extends StatefulWidget {
  final Quiz quiz;

  const QuizAttemptPage({
    Key? key,
    required this.quiz,
  }) : super(key: key);

  @override
  State<QuizAttemptPage> createState() => _QuizAttemptPageState();
}

class _QuizAttemptPageState extends State<QuizAttemptPage> {
  List<QuizQuestion> questions = [];
  Map<int, String> selectedAnswers = {};
  bool isLoading = true;
  String? errorMessage;
  int currentQuestionIndex = 0;
  PageController pageController = PageController();
  Timer? _timer;
  int _remainingSeconds = 0;
  bool _isSubmitting = false;

  // Quiz info
  late int _totalQuestions;
  late int _durationMinutes;
  late DateTime _startTime;

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    pageController.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final profile = await AuthService.getUserProfile();
      final studentId = profile['student_id']?.toString() ?? '';

      
      

      final response = await QuizApi.getQuestionsByQuizId(
        quizId: widget.quiz.quizId,
        studentId: studentId,
      );

      if (response['status'] == 1) {
        final List<dynamic> questionsList = response['questions'] ?? [];
        final quizInfo = response['quiz_info'] ?? {};
        
        setState(() {
          questions = questionsList.map((q) => QuizQuestion.fromJson(q)).toList();
          _totalQuestions = questions.length;
          // Duration Fallbacks
          final durationVal = quizInfo['duration_minutes'] ?? 
                             quizInfo['duration'] ?? 
                             quizInfo['time_duration'] ?? 
                             0;
          _durationMinutes = int.tryParse(durationVal.toString()) ?? 0;
          _remainingSeconds = _durationMinutes * 60;
          isLoading = false;
        });

        
        
        
        _startTimer();
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load questions';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading questions: $e';
        isLoading = false;
      });
      
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _submitQuiz(); // Auto-submit when time is up
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.quiz.quizTitle,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_durationMinutes > 0)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _remainingSeconds <= 60 ? Colors.red : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.timer,
                    size: 16,
                    color: _remainingSeconds <= 60 ? Colors.white : Colors.blue[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(_remainingSeconds),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _remainingSeconds <= 60 ? Colors.white : Colors.blue[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
            ),
            SizedBox(height: 16),
            Text(
              'Loading Quiz...',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Quiz',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Go Back'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Progress bar
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Question ${currentQuestionIndex + 1} of $_totalQuestions',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    '${(_getProgressPercentage()).toStringAsFixed(0)}% Complete',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: _getProgressPercentage() / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
              ),
            ],
          ),
        ),
        // Question content
        Expanded(
          child: PageView.builder(
            controller: pageController,
            onPageChanged: (index) {
              setState(() {
                currentQuestionIndex = index;
              });
            },
            itemCount: questions.length,
            itemBuilder: (context, index) {
              return _buildQuestionPage(questions[index], index);
            },
          ),
        ),
        // Navigation buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Previous button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: currentQuestionIndex > 0
                      ? () {
                          pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    disabledBackgroundColor: Colors.grey[300],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Submit button (only on last question)
              if (currentQuestionIndex == questions.length - 1)
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _showSubmitDialog,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isSubmitting ? 'Submitting...' : 'Submit Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                )
              else
                // Next button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionPage(QuizQuestion question, int index) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.help_outline,
                        color: Colors.blue[600],
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Question ${index + 1}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${question.marks.toStringAsFixed(1)} Marks',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  question.questionText,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Answer options
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Answer:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 12),
                ...question.options.asMap().entries.map((entry) {
                  final optionIndex = entry.key;
                  final optionText = entry.value;
                  final isSelected = selectedAnswers[index] == optionText;
                  
                  return _buildOption(optionIndex, optionText, isSelected, index);
                }).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(int optionIndex, String optionText, bool isSelected, int questionIndex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            selectedAnswers[questionIndex] = optionText;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? Colors.blue[600]! : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? Colors.blue[50] : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.blue[600]! : Colors.grey[400]!,
                    width: 2,
                  ),
                  color: isSelected ? Colors.blue[600] : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                        Icons.check,
                        size: 12,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${String.fromCharCode(65 + optionIndex)}. $optionText',
                  style: TextStyle(
                    fontSize: 14,
                    color: isSelected ? Colors.blue[600] : Colors.black87,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _getProgressPercentage() {
    return ((currentQuestionIndex + 1) / _totalQuestions) * 100;
  }

  void _showSubmitDialog() {
    final unansweredQuestions = _getUnansweredQuestions();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Quiz'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unansweredQuestions.isNotEmpty) ...[
              Text(
                'You have ${unansweredQuestions.length} unanswered question(s):',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              ...unansweredQuestions.map((q) => Text(
                '• Question ${q + 1}',
                style: const TextStyle(fontSize: 13),
              )).toList(),
              const SizedBox(height: 16),
            ],
            const Text(
              'Are you sure you want to submit your quiz?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitQuiz();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  List<int> _getUnansweredQuestions() {
    List<int> unanswered = [];
    for (int i = 0; i < questions.length; i++) {
      if (!selectedAnswers.containsKey(i) || selectedAnswers[i]!.isEmpty) {
        unanswered.add(i);
      }
    }
    return unanswered;
  }

  Future<void> _submitQuiz() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final profile = await AuthService.getUserProfile();
      final studentId = profile['student_id']?.toString() ?? '';

      // Prepare answers list
      List<Map<String, dynamic>> answers = [];
      for (int i = 0; i < questions.length; i++) {
        answers.add({
          'question_id': questions[i].questionId,
          'question_type': questions[i].questionType,
          'select_answer': selectedAnswers[i] ?? '',
        });
      }

      

      final response = await QuizApi.submitQuizAnswers(
        quizId: widget.quiz.quizId,
        studentId: studentId,
        rows: answers,
      );

      if (response['status'] == 1) {
        _timer?.cancel();
        
        // Navigate to results page
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QuizResultPage(
                quiz: widget.quiz,
                result: response,
              ),
            ),
          );
        }
      } else {
        setState(() {
          _isSubmitting = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to submit quiz'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error submitting quiz: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

