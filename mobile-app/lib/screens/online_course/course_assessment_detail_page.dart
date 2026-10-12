import 'package:flutter/material.dart';
import 'course_assessment_taking_page.dart';
import '../../widgets/translated_text.dart';

class CourseAssessmentDetailPage extends StatefulWidget {
  final Map<String, dynamic> item;
  final String courseTitle;

  const CourseAssessmentDetailPage({
    super.key,
    required this.item,
    required this.courseTitle,
  });

  @override
  State<CourseAssessmentDetailPage> createState() => _CourseAssessmentDetailPageState();
}

class _CourseAssessmentDetailPageState extends State<CourseAssessmentDetailPage> {
  @override
  void initState() {
    super.initState();
    
    // Debug: Print all available ID fields to identify the correct one
    
    
    
    
    
    
    
    
    
    
    
    
    // Check if there's useful information to display
    final totalQuestions = widget.item['total_question']?.toString() ?? 'N/A';
    
    // If no useful info (Questions = N/A), skip directly to quiz
    if (totalQuestions == 'N/A' || totalQuestions.isEmpty || totalQuestions == '0') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToQuiz();
      });
    }
  }

  void _navigateToQuiz() {
    // Helper to validate ID strings
    bool isValidId(dynamic id) {
      if (id == null) return false;
      final s = id.toString().trim().toLowerCase();
      return s.isNotEmpty && s != '0' && s != 'null' && s != 'undefined';
    }

    // Determine if this is a quiz or exam based on 'type' PRIORITY
    final String type = widget.item['type']?.toString().toLowerCase() ?? '';
    bool isQuiz;

    if (type == 'exam') {
      isQuiz = false; // Strictly Exam
    } else if (type == 'quiz') {
      isQuiz = true;  // Strictly Quiz
    } else {
      // Fallback: Check checking is_quiz flag or IDs
      isQuiz = (widget.item['is_quiz']?.toString() == '1');
      
      if (!isQuiz) {
         // If still not identified, use ID presence heuristics
         if (isValidId(widget.item['quiz_id']) && !isValidId(widget.item['course_exam_id'])) {
            isQuiz = true;
         }
      }
    }
    
    String? quizId;
    
    // For EXAMS: prioritize course_exam_id
    if (!isQuiz) {
      if (isValidId(widget.item['course_exam_id'])) {
        quizId = widget.item['course_exam_id'].toString();
        
      }
    }
    
    // For QUIZZES or if exam ID not found: use quiz ID resolution
    if (quizId == null) {
      if (isValidId(widget.item['quiz_id'])) {
        quizId = widget.item['quiz_id'].toString();
      } else if (isValidId(widget.item['quiz id'])) {
        quizId = widget.item['quiz id'].toString();
      } else if (isValidId(widget.item['quizid'])) {
        quizId = widget.item['quizid'].toString();
      } else if (isValidId(widget.item['online_quiz_id'])) {
        quizId = widget.item['online_quiz_id'].toString();
      } else if (isValidId(widget.item['course_quizzes_id'])) {
        quizId = widget.item['course_quizzes_id'].toString();
      } else if (isValidId(widget.item['lesson_quiz_id'])) {
        quizId = widget.item['lesson_quiz_id'].toString();
      } else if (isValidId(widget.item['id'])) {
        quizId = widget.item['id'].toString();
      }
    }
                   
    final title = widget.item['quiz_title']?.toString() ?? 
                  widget.item['course_exam_name']?.toString() ?? 
                  widget.item['title']?.toString() ?? 
                  'Assessment';
    
    final duration = widget.item['duration']?.toString() ?? 
                    widget.item['exam_duration']?.toString() ??
                    widget.item['time_duration']?.toString() ?? 
                    widget.item['duration_minutes']?.toString() ?? 
                    '00:00:00';

    

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => CourseAssessmentTakingPage(
          assessmentId: quizId ?? '',
          title: title,
          isQuiz: isQuiz,
          duration: duration,
          rawItem: widget.item,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // RESOLVE ID: User explicitly says use quiz_id for value 55
    final quizId = widget.item['quiz_id']?.toString() ?? 
                   widget.item['quiz id']?.toString() ?? 
                   widget.item['quizid']?.toString() ?? 
                   widget.item['id']?.toString() ?? '';
                   
    final title = widget.item['quiz_title']?.toString() ?? widget.item['title']?.toString() ?? 'Assessment';
    final isQuiz = widget.item['type']?.toString().toLowerCase() == 'quiz' || (widget.item['is_quiz']?.toString() == '1');
    
    // Duration
    final duration = widget.item['duration']?.toString() ?? 
                    widget.item['time_duration']?.toString() ?? 
                    widget.item['duration_minutes']?.toString() ?? 
                    '00:00:00';

    return Scaffold(
      appBar: AppBar(
        title: Text(isQuiz ? 'Quiz Details' : 'Exam Details'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.courseTitle, 
              style: TextStyle(
                color: Colors.blue[600], 
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title, 
              style: const TextStyle(
                fontSize: 24, 
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 32),
            
            _buildInfoCard(
              icon: Icons.timer,
              label: 'Duration',
              value: duration == '00:00:00' ? 'No Time Limit' : duration,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              icon: Icons.help_outline,
              label: 'Questions',
              value: widget.item['total_question']?.toString() ?? 'N/A',
            ),
            
            const SizedBox(height: 40),
            const Text(
              'Instructions:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              widget.item['quiz_instruction']?.toString() ?? widget.item['description']?.toString() ?? 'Please read each question carefully and select the best answer.',
              style: TextStyle(color: Colors.grey[700], height: 1.5),
            ),
            
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _navigateToQuiz,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('START ASSESSMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue[600]),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ],
      ),
    );
  }
}
