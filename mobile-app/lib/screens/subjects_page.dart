import 'package:flutter/material.dart';
import '../services/api/homework_api.dart';
import '../services/api/lesson_api.dart';
import '../services/auth_service.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class SubjectsPage extends StatefulWidget {
  const SubjectsPage({super.key});

  @override
  State<SubjectsPage> createState() => _SubjectsPageState();
}

class _SubjectsPageState extends State<SubjectsPage> {
  List<Map<String, dynamic>> subjects = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadSubjects();
  }

  Future<void> loadSubjects() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final studentId = await AuthService.getStudentId();
      if (studentId.isEmpty) {
        throw Exception('No student ID found. Please login again.');
      }
      
      
      // Try getSubjectList first
      var data = await HomeworkApi.getSubjectList(studentId);
      
      
      List<Map<String, dynamic>> subjectsList = [];
      
      // Check multiple possible keys for subjects
      if (data['subjects'] != null && (data['subjects'] as List).isNotEmpty) {
        subjectsList = List<Map<String, dynamic>>.from(data['subjects']);
        
      } else if (data['subject_list'] != null && (data['subject_list'] as List).isNotEmpty) {
        subjectsList = List<Map<String, dynamic>>.from(data['subject_list']);
        
      } else if (data['data'] != null && (data['data'] as List).isNotEmpty) {
        subjectsList = List<Map<String, dynamic>>.from(data['data']);
        
      } else if (data['result'] != null && (data['result'] as List).isNotEmpty) {
        subjectsList = List<Map<String, dynamic>>.from(data['result']);
        
      }
      
      // If no subjects found, try syllabus API as fallback
      if (subjectsList.isEmpty) {
        
        try {
          final syllabusData = await LessonApi.getSyllabusSubjects(studentId);
          
          
          if (syllabusData['subjects'] != null && (syllabusData['subjects'] as List).isNotEmpty) {
            final syllabusSubjects = List<Map<String, dynamic>>.from(syllabusData['subjects']);
            // Map syllabus subjects to the expected format
            subjectsList = syllabusSubjects.map((subject) {
              return {
                'name': subject['subject_name'] ?? subject['name'] ?? 'Unknown',
                'code': subject['subject_code'] ?? subject['code'] ?? 'N/A',
                'id': subject['subject_group_subject_id'] ?? subject['id'] ?? '',
                'teacher': subject['teacher_name'] ?? subject['teacher'] ?? 'Not assigned',
                'grade': subject['grade'] ?? 'N/A',
                'attendance': subject['attendance'] ?? 'N/A',
                'credits': subject['credits'] ?? 'N/A',
                'schedule': subject['schedule'] ?? 'Not specified',
                'room': subject['room'] ?? 'Not specified',
                'description': subject['description'] ?? '',
                'assignments': subject['assignments'] ?? '0',
                'exams': subject['exams'] ?? '0',
              };
            }).toList();
            
          } else if (syllabusData['data'] != null && (syllabusData['data'] as List).isNotEmpty) {
            final syllabusSubjects = List<Map<String, dynamic>>.from(syllabusData['data']);
            subjectsList = syllabusSubjects.map((subject) {
              return {
                'name': subject['subject_name'] ?? subject['name'] ?? 'Unknown',
                'code': subject['subject_code'] ?? subject['code'] ?? 'N/A',
                'id': subject['subject_group_subject_id'] ?? subject['id'] ?? '',
                'teacher': subject['teacher_name'] ?? subject['teacher'] ?? 'Not assigned',
                'grade': subject['grade'] ?? 'N/A',
                'attendance': subject['attendance'] ?? 'N/A',
                'credits': subject['credits'] ?? 'N/A',
                'schedule': subject['schedule'] ?? 'Not specified',
                'room': subject['room'] ?? 'Not specified',
                'description': subject['description'] ?? '',
                'assignments': subject['assignments'] ?? '0',
                'exams': subject['exams'] ?? '0',
              };
            }).toList();
            
          }
        } catch (syllabusError) {
          
        }
      }
      
      if (!mounted) return;
      
      setState(() {
        subjects = subjectsList;
        isLoading = false;
        if (subjects.isEmpty) {
          errorMessage = 'No subjects found. Please contact your school administrator.';
        }
      });
      
      
    } catch (e) {
      if (!mounted) return;
      
      
      
      setState(() {
        errorMessage = 'Error loading subjects: $e';
        isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TranslatedText('Subjects'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Subjects',
            subtitle: 'Explore your academic subjects',
            illustration: const Icon(
              Icons.subject,
              size: 60,
              color: Colors.blue,
            ),
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : errorMessage != null
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading data',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: loadSubjects,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (subjects.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No subjects found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        return _buildSubjectCard(subject);
      },
    );
  }

  Widget _buildSubjectCard(Map<String, dynamic> subject) {
    final grade = subject['grade'] ?? 'N/A';
    final attendance = subject['attendance'] ?? 'N/A';
    
    Color gradeColor;
    switch (grade) {
      case 'A+':
      case 'A':
        gradeColor = Colors.green;
        break;
      case 'A-':
      case 'B+':
        gradeColor = Colors.blue;
        break;
      case 'B':
      case 'B-':
        gradeColor = Colors.orange;
        break;
      case 'C+':
      case 'C':
        gradeColor = Colors.yellow[700]!;
        break;
      default:
        gradeColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    _getSubjectIcon(subject['name']),
                    color: Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject['name'] ?? 'Unknown Subject',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Code: ${subject['code'] ?? 'N/A'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Teacher: ${subject['teacher'] ?? 'Not assigned'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: gradeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: gradeColor),
                      ),
                      child: Text(
                        'Grade: $grade',
                        style: TextStyle(
                          color: gradeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attendance: $attendance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Subject Details
            _buildInfoSection('Course Information', [
              _buildInfoRow('Credits', subject['credits'] ?? 'N/A'),
              _buildInfoRow('Schedule', subject['schedule'] ?? 'Not specified'),
              _buildInfoRow('Room', subject['room'] ?? 'Not specified'),
            ]),
            
            const SizedBox(height: 12),
            
            // Description
            if (subject['description'] != null && subject['description'].toString().isNotEmpty)
              _buildInfoSection('Description', [
                Text(
                  subject['description'],
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ]),
            
            const SizedBox(height: 12),
            
            // Performance Summary
            _buildPerformanceSummary(subject),
            
            const SizedBox(height: 12),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showSubjectDetails(subject);
                    },
                    icon: const Icon(Icons.info, size: 16),
                    label: const Text('Details'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      _showAssignments(subject);
                    },
                    icon: const Icon(Icons.assignment, size: 16),
                    label: const Text('Assignments'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      side: const BorderSide(color: Colors.green),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceSummary(Map<String, dynamic> subject) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Performance Summary',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Assignments',
                  subject['assignments'] ?? '0',
                  Colors.blue,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Exams',
                  subject['exams'] ?? '0',
                  Colors.orange,
                ),
              ),
              Expanded(
                child: _buildSummaryItem(
                  'Attendance',
                  subject['attendance'] ?? 'N/A',
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSubjectIcon(String? subjectName) {
    if (subjectName == null) return Icons.book;
    
    switch (subjectName.toLowerCase()) {
      case 'mathematics':
      case 'math':
        return Icons.functions;
      case 'science':
        return Icons.science;
      case 'english':
      case 'english literature':
        return Icons.menu_book;
      case 'history':
        return Icons.history_edu;
      case 'art':
      case 'art & design':
        return Icons.palette;
      case 'physical education':
      case 'pe':
        return Icons.sports_soccer;
      case 'geography':
        return Icons.public;
      case 'chemistry':
        return Icons.science;
      case 'physics':
        return Icons.science;
      case 'biology':
        return Icons.biotech;
      default:
        return Icons.book;
    }
  }

  void _showSubjectDetails(Map<String, dynamic> subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${subject['name']} - Details'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Subject Code', subject['code'] ?? 'Not specified'),
              _buildInfoRow('Teacher', subject['teacher'] ?? 'Not assigned'),
              _buildInfoRow('Credits', subject['credits'] ?? 'Not specified'),
              _buildInfoRow('Schedule', subject['schedule'] ?? 'Not specified'),
              _buildInfoRow('Room', subject['room'] ?? 'Not specified'),
              _buildInfoRow('Grade', subject['grade'] ?? 'Not available'),
              _buildInfoRow('Attendance', subject['attendance'] ?? 'Not available'),
              _buildInfoRow('Assignments', subject['assignments'] ?? '0'),
              _buildInfoRow('Exams', subject['exams'] ?? '0'),
              if (subject['description'] != null && subject['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Description',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(subject['description']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAssignments(Map<String, dynamic> subject) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${subject['name']} - Assignments'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Assignments: ${subject['assignments'] ?? '0'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Total Exams: ${subject['exams'] ?? '0'}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'This feature will show detailed assignment and exam information.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 
