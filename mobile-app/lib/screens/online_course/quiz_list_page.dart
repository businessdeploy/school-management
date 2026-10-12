import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quiz_model.dart';
import '../../services/api/quiz_api.dart';
import '../../services/auth_service.dart';

class QuizListPage extends StatefulWidget {
  final String courseId;
  final String courseName;

  const QuizListPage({
    Key? key,
    required this.courseId,
    required this.courseName,
  }) : super(key: key);

  @override
  State<QuizListPage> createState() => _QuizListPageState();
}

class _QuizListPageState extends State<QuizListPage> {
  List<Quiz> quizzes = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadQuizzes();
  }

  Future<void> _loadQuizzes() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final profile = await AuthService.getUserProfile();
      final studentId = profile['student_id']?.toString() ?? '';

      
      

      final response = await QuizApi.getCourseCurriculum(
        courseId: widget.courseId,
        studentId: studentId,
      );

      if (response['status'] == 1) {
        final List<dynamic> quizList = response['quiz_list'] ?? [];
        
        setState(() {
          quizzes = quizList.map((quiz) => Quiz.fromJson(quiz)).toList();
          isLoading = false;
        });

        
      } else {
        setState(() {
          errorMessage = response['message'] ?? 'Failed to load quizzes';
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = 'Error loading quizzes: $e';
        isLoading = false;
      });
      
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.courseName} - Quizzes',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: Colors.blue[600],
        foregroundColor: Colors.white,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: _loadQuizzes,
        child: _buildBody(),
      ),
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
              'Loading Quizzes...',
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
              'Error Loading Quizzes',
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
              onPressed: _loadQuizzes,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
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

    if (quizzes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Quizzes Available',
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
                'There are no quizzes available for this course yet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: quizzes.length,
      itemBuilder: (context, index) {
        final quiz = quizzes[index];
        return _buildQuizCard(quiz, index);
      },
    );
  }

  Widget _buildQuizCard(Quiz quiz, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: () => _navigateToQuiz(quiz),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _getQuizColor(quiz.status),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getQuizIcon(quiz.status),
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quiz.quizTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            quiz.sectionName,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _buildInfoChip(
                      'Quiz ID: ${quiz.quizId}',
                      Icons.tag,
                      Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    if (quiz.totalQuestions != null)
                      _buildInfoChip(
                        '${quiz.totalQuestions} Questions',
                        Icons.help_outline,
                        Colors.green,
                      ),
                    const Spacer(),
                    _buildStatusChip(quiz.status),
                  ],
                ),
                if (quiz.totalMarks != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        'Total Marks: ${quiz.totalMarks}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (quiz.obtainedMarks != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          'Score: ${quiz.obtainedMarks}',
                          style: TextStyle(
                            fontSize: 13,
                            color: _getScoreColor(quiz.obtainedMarks!, quiz.totalMarks!),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String label;
    IconData icon;

    switch (status) {
      case 'completed':
        color = Colors.green;
        label = 'Completed';
        icon = Icons.check_circle;
        break;
      case 'expired':
        color = Colors.red;
        label = 'Expired';
        icon = Icons.error;
        break;
      case 'in_progress':
        color = Colors.orange;
        label = 'In Progress';
        icon = Icons.pending;
        break;
      default:
        color = Colors.blue;
        label = 'Available';
        icon = Icons.play_circle;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getQuizColor(String? status) {
    switch (status) {
      case 'completed':
        return Colors.green;
      case 'expired':
        return Colors.red;
      case 'in_progress':
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  IconData _getQuizIcon(String? status) {
    switch (status) {
      case 'completed':
        return Icons.check_circle;
      case 'expired':
        return Icons.error;
      case 'in_progress':
        return Icons.pending;
      default:
        return Icons.play_circle;
    }
  }

  Color _getScoreColor(double obtained, double total) {
    final percentage = (obtained / total) * 100;
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  void _navigateToQuiz(Quiz quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizAttemptPage(
          quiz: quiz,
        ),
      ),
    );
  }
}

// Import the QuizAttemptPage (we'll create this next)
class QuizAttemptPage extends StatelessWidget {
  final Quiz quiz;

  const QuizAttemptPage({
    Key? key,
    required this.quiz,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder for now - we'll implement this next
    return Scaffold(
      appBar: AppBar(
        title: Text(quiz.quizTitle),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.quiz,
              size: 64,
              color: Colors.blue,
            ),
            const SizedBox(height: 16),
            Text(
              'Quiz Attempt Page',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Quiz ID: ${quiz.quizId}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
