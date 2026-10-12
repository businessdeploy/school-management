import 'package:flutter/material.dart';
import '../services/api/lesson_api.dart';
import '../services/auth_service.dart';
import 'syllabus_detail_page.dart';

class LessonDetailPage extends StatefulWidget {
  final String subjectName;
  final String subjectCode;
  final String? subjectId;
  final String? classSectionId;

  const LessonDetailPage({
    super.key,
    required this.subjectName,
    required this.subjectCode,
    this.subjectId,
    this.classSectionId,
  });

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  List<Map<String, dynamic>> lessonTopics = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadLessonTopics();
  }

  Future<void> _loadLessonTopics() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      // Get dynamic values from syllabus API instead of using hardcoded fallbacks
      String finalSubjectId = '1';
      String classSectionId = '1';
      
      try {
        // Get dynamic values from syllabus API
        final studentId = await AuthService.getStudentId();
        final syllabusResponse = await LessonApi.getSyllabusSubjects(studentId);
        
        if (syllabusResponse['status'] == 1 && syllabusResponse['subjects'] != null) {
          final subjects = syllabusResponse['subjects'] as List;
          if (subjects.isNotEmpty) {
            // Find the subject that matches the current subject name
            final matchingSubject = subjects.firstWhere(
              (subject) => subject['subject_name'] == widget.subjectName,
              orElse: () => subjects.first, // Use first subject if no match found
            );
            
            finalSubjectId = matchingSubject['subject_group_subject_id']?.toString() ?? '1';
            classSectionId = matchingSubject['id']?.toString() ?? '1';
            
            
            
            
          }
        } else {
          
        }
      } catch (e) {
        
      }
      
      
      
      
      
      
      
      // Use specific subject ID and class section ID for this subject
      final response = await LessonApi.getLessonTopics(finalSubjectId, classSectionId);
      
      if (response['status'] == 1 && response['data'] != null) {
        final lessons = List<Map<String, dynamic>>.from(response['data']);
        
        
        // Check if the API data matches the subject name
        // If not, use subject-specific mock data instead
        final shouldUseMockData = _shouldUseMockData(widget.subjectName, lessons);
        
        if (shouldUseMockData) {
          
          setState(() {
            lessonTopics = [];
            isLoading = false;
          });
        } else if (lessons.isEmpty) {
          
          setState(() {
            lessonTopics = [];
            isLoading = false;
          });
        } else {
          // Convert lessons to topics format for display
          List<Map<String, dynamic>> allTopics = [];
          for (var lesson in lessons) {
            if (lesson['topics'] != null && (lesson['topics'] as List).isNotEmpty) {
              final topics = List<Map<String, dynamic>>.from(lesson['topics']);
              for (var topic in topics) {
                allTopics.add({
                  'id': topic['id'],
                  'topic_name': topic['name'],
                  'description': '${lesson['name']} - ${topic['name']}',
                  'status': topic['status'] == '1' ? 'completed' : 'pending',
                  'completion_percentage': topic['status'] == '1' ? 100 : 0,
                  'date': topic['complete_date'] ?? '',
                  'teacher_name': '${widget.subjectName} Teacher',
                  'duration': '45 minutes',
                  'lesson_type': 'Theory',
                  'lesson_name': lesson['name'],
                  'total_topics': lesson['total'],
                  'completed_topics': lesson['total_complete'],
                });
              }
            } else {
              // If lesson has no topics, show the lesson itself as a topic
              allTopics.add({
                'id': lesson['id'],
                'topic_name': lesson['name'],
                'description': '${lesson['name']} - No topics configured yet',
                'status': 'pending',
                'completion_percentage': 0,
                'date': '',
                'teacher_name': '${widget.subjectName} Teacher',
                'duration': '45 minutes',
                'lesson_type': 'Theory',
                'lesson_name': lesson['name'],
                'total_topics': lesson['total'] ?? '0',
                'completed_topics': lesson['total_complete'] ?? '0',
              });
            }
          }
          
          
          
          setState(() {
            lessonTopics = allTopics;
            isLoading = false;
          });
        }
      } else {
        
        // No mock data - show empty state
        setState(() {
          lessonTopics = [];
          isLoading = false;
        });
      }
    } catch (e) {
      
      setState(() {
        error = e.toString();
        isLoading = false;
        lessonTopics = [];
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          '${widget.subjectName} - Lesson Topics',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[800],
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Builder(
          builder: (context) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (error != null) {
              return _buildErrorState();
            }
            if (lessonTopics.isEmpty) {
              return _buildEmptyState();
            }
            return _buildLessonList();
          },
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.redAccent),
            const SizedBox(height: 16),
            Text(
              error ?? 'Something went wrong while loading lessons.',
              style: const TextStyle(fontSize: 14, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadLessonTopics,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_outlined, size: 52, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No lesson topics found for this subject.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadLessonTopics,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reload'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonList() {
    // Group topics by lesson name to mimic design (Lesson -> topics list)
    final Map<String, List<Map<String, dynamic>>> groupedLessons = {};
    for (final topic in lessonTopics) {
      final lessonName = topic['lesson_name']?.toString() ?? 'Lesson';
      groupedLessons.putIfAbsent(lessonName, () => []).add(topic);
    }

    final lessonEntries = groupedLessons.entries.toList();

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      itemCount: lessonEntries.length,
      itemBuilder: (context, index) {
        final entry = lessonEntries[index];
        return _buildLessonSection(entry.key, entry.value, index + 1);
      },
    );
  }

  Widget _buildLessonSection(String lessonName, List<Map<String, dynamic>> topics, int lessonIndex) {
    // Determine completion percent for header
    double completionPercentage = 0;
    if (topics.isNotEmpty) {
      final completed = topics.where((t) => (t['status'] ?? '').toString() == 'completed').length;
      completionPercentage = (completed / topics.length) * 100;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFFE7F3ED),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Colors.white,
                  child: Text(
                    lessonIndex.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lessonName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Text(
                  '${completionPercentage.round()}% Complete',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Column(
              children: [
                _buildLessonTableHeader(),
                const Divider(height: 12),
                ...topics.asMap().entries.map((entry) {
                  final topicIndex = entry.key + 1;
                  final topic = entry.value;
                  return _buildLessonTopicRow(
                    lessonIndex,
                    topicIndex,
                    topic,
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonTableHeader() {
    return Row(
      children: const [
        SizedBox(
          width: 40,
          child: Text(
            'No.',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            'Topic',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
        SizedBox(
          width: 90,
            child: Text(
            'Status',
            textAlign: TextAlign.end,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: Colors.black54,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLessonTopicRow(int lessonIndex, int topicIndex, Map<String, dynamic> topic) {
    final status = (topic['status'] ?? 'pending').toString().toLowerCase();
    Color statusColor;
    String statusLabel;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusLabel = 'Complete';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusLabel = 'Incomplete';
        break;
      default:
        statusColor = Colors.blue;
        statusLabel = 'In Progress';
    }

    final date = topic['date']?.toString() ?? '';
    final formattedDate = date.isNotEmpty ? '(${_formatDate(date)})' : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '$lessonIndex.$topicIndex',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  topic['topic_name']?.toString() ?? 'Topic',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                if (date.isNotEmpty)
                  Text(
                    '$statusLabel $formattedDate',
                    style: TextStyle(
                      fontSize: 12,
                      color: statusColor.withOpacity(0.8),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            width: 90,
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format date as DD/MM/YYYY (NO time)
  String _formatDate(String dateString) {
    if (dateString.isEmpty) return '';
    
    try {
      // CRITICAL: Always format as DD/MM/YYYY (NO time)
      // Remove time component if present (split by space and take first part)
      final datePart = dateString.trim().split(' ').first;
      
      // Handle YYYY-MM-DD format (e.g., "2025-12-11" or "2025-12-11 11:31:09")
      if (datePart.contains('-')) {
        final parts = datePart.split('-');
        if (parts.length == 3) {
          final year = parts[0];
          final month = parts[1];
          final day = parts[2];
          return '$day/$month/$year'; // Convert to DD/MM/YYYY
        }
      }
      
      // Handle DD/MM/YYYY format (already correct, just remove time if present)
      if (datePart.contains('/')) {
        final parts = datePart.split('/');
        if (parts.length == 3) {
          return datePart; // Already in DD/MM/YYYY format
        }
      }
      
      // Try to parse with DateTime (handles various formats)
      final parsed = DateTime.tryParse(datePart);
      if (parsed != null) {
        return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
      }
      
      return datePart; // Return date part only (time removed)
    } catch (e) {
      // If parsing fails, try to remove time and return date part
      final datePart = dateString.trim().split(' ').first;
      return datePart;
    }
  }

  /// Check if we should use mock data instead of API data
  bool _shouldUseMockData(String subjectName, List<Map<String, dynamic>> lessons) {
    // Always use real API data - don't filter by subject name
    // The API should return data for all subjects
    return false;
  }

}
