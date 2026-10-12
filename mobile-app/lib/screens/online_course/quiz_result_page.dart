import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/quiz_model.dart';
import '../../services/api/quiz_api.dart';

class QuizResultPage extends StatefulWidget {
  final Quiz quiz;
  final Map<String, dynamic> result;

  const QuizResultPage({
    Key? key,
    required this.quiz,
    required this.result,
  }) : super(key: key);

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage> {
  QuizResult? quizResult;
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _processResult();
  }

  void _processResult() {
    // Create QuizResult from the response
    quizResult = QuizResult(
      resultId: widget.result['result_id']?.toString() ?? '',
      quizId: widget.quiz.quizId,
      studentId: widget.result['student_id']?.toString() ?? '',
      totalMarks: double.tryParse(widget.result['total_marks']?.toString() ?? '0') ?? 0.0,
      obtainedMarks: double.tryParse(widget.result['obtained_marks']?.toString() ?? '0') ?? 0.0,
      percentage: double.tryParse(widget.result['percentage']?.toString() ?? '0') ?? 0.0,
      grade: widget.result['grade']?.toString() ?? 'N/A',
      status: widget.result['status']?.toString() ?? 'fail',
      submittedAt: DateTime.now(),
      timeSpentSeconds: int.tryParse(widget.result['time_spent_seconds']?.toString() ?? '0'),
      questionResults: [],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (quizResult == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Results'),
        ),
        body: const Center(
          child: Text('No results available'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Quiz Results',
          style: TextStyle(
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildScoreCard(),
            _buildPerformanceMetrics(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[600]!,
            Colors.blue[400]!,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Text(
                  widget.quiz.quizTitle,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  widget.quiz.sectionName,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quiz ID: ${widget.quiz.quizId}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard() {
    final percentage = quizResult!.percentage;
    final grade = quizResult!.grade;
    final status = quizResult!.status;
    
    Color scoreColor;
    IconData statusIcon;
    String statusText;

    if (percentage >= 80) {
      scoreColor = Colors.green;
      statusIcon = Icons.emoji_events;
      statusText = 'Excellent!';
    } else if (percentage >= 60) {
      scoreColor = Colors.orange;
      statusIcon = Icons.thumb_up;
      statusText = 'Good!';
    } else {
      scoreColor = Colors.red;
      statusIcon = Icons.sentiment_dissatisfied;
      statusText = 'Need Improvement';
    }

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Circular progress indicator
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: percentage / 100,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                  strokeWidth: 8,
                ),
              ),
              Column(
                children: [
                  Icon(
                    statusIcon,
                    size: 32,
                    color: scoreColor,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${percentage.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Score details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildScoreItem(
                'Obtained',
                '${quizResult!.obtainedMarks.toStringAsFixed(1)}',
                Colors.green,
              ),
              _buildScoreItem(
                'Total',
                '${quizResult!.totalMarks.toStringAsFixed(1)}',
                Colors.blue,
              ),
              _buildScoreItem(
                'Grade',
                grade,
                Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Status message
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: scoreColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  status == 'pass' ? Icons.check_circle : Icons.cancel,
                  color: scoreColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scoreColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceMetrics() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            'Performance Summary',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricRow(
            'Status',
            quizResult!.status == 'pass' ? 'Passed' : 'Failed',
            quizResult!.status == 'pass' ? Colors.green : Colors.red,
            Icons.check_circle,
          ),
          const SizedBox(height: 12),
          if (quizResult!.timeSpentSeconds != null)
            _buildMetricRow(
              'Time Spent',
              _formatDuration(quizResult!.timeSpentSeconds!),
              Colors.blue,
              Icons.timer,
            ),
          const SizedBox(height: 12),
          _buildMetricRow(
            'Submitted At',
            _formatDateTime(quizResult!.submittedAt),
            Colors.grey,
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: color,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // View Details button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _viewDetailedResults,
              icon: const Icon(Icons.list_alt),
              label: const Text('View Detailed Results'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Back to Quiz List button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Quiz List'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: BorderSide(color: Colors.grey[400]!),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${remainingSeconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${remainingSeconds}s';
    } else {
      return '${remainingSeconds}s';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _viewDetailedResults() {
    // Navigate to detailed results page (placeholder for now)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Detailed results view coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }
}
