import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/api/lesson_api.dart';
import 'lesson_plan_detail_page.dart';
import '../models/lesson_plan.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import '../widgets/enterprise_ui_components.dart';
import '../widgets/translated_text.dart';

class LessonPage extends StatefulWidget {
  const LessonPage({super.key});

  @override
  State<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends State<LessonPage> {
  List<Map<String, dynamic>> weeklyLessonPlans = [];
  String _extractSubjectSyllabusId(Map<String, dynamic> lesson) {
    final candidates = [
      'subject_syllabus_id',
      'subject_syllabusid',
      'subjectSyllabusId',
      'subject_group_subject_id',
      'subject_group_class_sections_id',
      'subject_id',
      'id',
    ];
    for (final key in candidates) {
      if (!lesson.containsKey(key)) continue;
      final value = lesson[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty && text.toLowerCase() != 'null') {
        return text;
      }
    }
    return '';
  }

  bool isLoading = true;
  String? errorMessage;
  late DateTime selectedWeekStart; // Will be initialized in initState

  @override
  void initState() {
    super.initState();
    selectedWeekStart =
        _getCurrentWeekStart(); // Initialize to Monday of current week
    weeklyLessonPlans.clear();
    loadWeeklyLessonPlans();
  }

  Future<void> loadWeeklyLessonPlans() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      
      final studentId = await AuthService.getStudentId();
      
      // Calculate date range for the selected week
      final dateFrom = selectedWeekStart;
      final dateTo = selectedWeekStart.add(const Duration(days: 6));

      // Use the robust LessonApi
      final result = await LessonApi.getLessonPlan(studentId, dateFrom, dateTo);

      if (!mounted) return;

      if (result['status'] == 1 || result['status'] == '1' || result['status'] == '200') {
        final timetable = result['timetable'] as Map<String, dynamic>;
        final lessonItems = <Map<String, dynamic>>[];

        for (final dayEntry in timetable.entries) {
          final dayName = dayEntry.key;
          final dayLessonsData = dayEntry.value as List<dynamic>;

          for (final lessonData in dayLessonsData) {
            if (lessonData is Map<String, dynamic>) {
              try {
                final lesson = LessonPlan.fromJson(lessonData);
                lessonItems.add({
                  'id': lesson.id,
                  'subject_syllabus_id': lesson.subjectId,
                  'subject_name': lesson.subjectName,
                  'subject_code': lesson.subjectCode,
                  'lesson_name': lesson.lessonName,
                  'topic_name': lesson.topicName,
                  'time_from': lesson.timeFrom,
                  'time_to': lesson.timeTo,
                  'teacher_name': lesson.teacherName,
                  'class_name': lesson.className,
                  'section': lesson.section,
                  'date': lesson.date,
                  'day': dayName,
                  'description': lesson.description,
                  'is_active': lesson.isActive,
                  'created_at': lesson.createdAt,
                  'updated_at': lesson.updatedAt,
                  'attachment': lesson.attachment,
                });
              } catch (e) {
                
              }
            }
          }
        }

        setState(() {
          weeklyLessonPlans = lessonItems;
          isLoading = false;
        });
      } else {
        setState(() {
          weeklyLessonPlans = [];
          errorMessage = result['message']?.toString();
          isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = 'Error loading weekly lesson plans: $e';
        isLoading = false;
      });
    }
  }

  void _previousWeek() {
    setState(() {
      selectedWeekStart = selectedWeekStart.subtract(const Duration(days: 7));
    });
    loadWeeklyLessonPlans();
  }

  void _nextWeek() {
    setState(() {
      selectedWeekStart = selectedWeekStart.add(const Duration(days: 7));
    });
    loadWeeklyLessonPlans();
  }

  void _resetToCurrentWeek() {
    setState(() {
      selectedWeekStart = _getCurrentWeekStart();
    });
    
    loadWeeklyLessonPlans();
  }

  DateTime _getCurrentWeekStart() {
    final now = DateTime.now();
    // Get Monday of current week (weekday 1 = Monday)
    final daysFromMonday = (now.weekday - 1) % 7;
    return DateTime(now.year, now.month, now.day - daysFromMonday);
  }

  String _getWeekRangeText() {
    final endOfWeek = selectedWeekStart.add(const Duration(days: 6));
    return '${selectedWeekStart.day.toString().padLeft(2, '0')}/${selectedWeekStart.month.toString().padLeft(2, '0')}/${selectedWeekStart.year} - ${endOfWeek.day.toString().padLeft(2, '0')}/${endOfWeek.month.toString().padLeft(2, '0')}/${endOfWeek.year}';
  }

  String _formatDateString(String dateStr) {
    if (dateStr.isEmpty) return '';
    
    try {
      // CRITICAL: Always format as DD/MM/YYYY (NO time)
      // Remove time component if present (split by space and take first part)
      final datePart = dateStr.trim().split(' ').first;
      
      DateTime? dt;
      
      // Handle YYYY-MM-DD format (e.g., "2025-12-11" or "2025-12-11 11:31:09")
      if (datePart.contains('-')) {
        dt = DateTime.tryParse(datePart);
      } 
      // Handle DD/MM/YYYY format
      else if (datePart.contains('/')) {
        final p = datePart.split('/');
        if (p.length == 3) {
          final d = int.tryParse(p[0]) ?? 1;
          final m = int.tryParse(p[1]) ?? 1;
          final y = int.tryParse(p[2]) ?? DateTime.now().year;
          dt = DateTime(y, m, d);
        }
      }
      
      if (dt == null) {
        // If parsing fails, try to extract date from string
        final parsed = DateTime.tryParse(datePart);
        if (parsed != null) {
          dt = parsed;
        } else {
          return datePart; // Return date part only (time removed)
        }
      }
      
      // Format as DD/MM/YYYY (NO time, NO month names)
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (e) {
      // If parsing fails, return date part only (time removed)
      final datePart = dateStr.trim().split(' ').first;
      return datePart;
    }
  }

  List<Map<String, dynamic>> _getLessonsForDay(String day) {
    final dayIndex = _getDayIndex(day);
    if (dayIndex == -1) return [];

    final dayDate = selectedWeekStart.add(Duration(days: dayIndex));

    final dayLessons = weeklyLessonPlans.where((lesson) {
      final lessonDateStr = lesson['date']?.toString();
      if (lessonDateStr == null) return false;

      DateTime? lessonDate;

      if (lessonDateStr.contains('/')) {
        final parts = lessonDateStr.split('/');
        if (parts.length == 3) {
          final d = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final y = int.tryParse(parts[2]) ?? 0;
          if (d > 0 && m > 0 && y > 0) {
            lessonDate = DateTime(y, m, d);
          }
        }
      } else if (lessonDateStr.contains('-')) {
        lessonDate = DateTime.tryParse(lessonDateStr);
      }

      if (lessonDate != null) {
        return lessonDate.year == dayDate.year &&
            lessonDate.month == dayDate.month &&
            lessonDate.day == dayDate.day;
      }
      return false;
    }).toList();

    return dayLessons;
  }

  int _getDayIndex(String day) {
    const dayMap = {
      'Monday': 0,
      'Tuesday': 1,
      'Wednesday': 2,
      'Thursday': 3,
      'Friday': 4,
      'Saturday': 5,
      'Sunday': 6,
    };
    return dayMap[day] ?? -1;
  }

  @override
  Widget build(BuildContext context) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lesson Plan', style: TextStyle(color: Colors.white)),
        backgroundColor: primaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.today, color: Colors.white),
            onPressed: _resetToCurrentWeek,
            tooltip: 'Current Week',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              weeklyLessonPlans.clear();
              loadWeeklyLessonPlans();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline,
                              size: 48, color: Colors.orange),
                          const SizedBox(height: 16),
                          Text(
                            errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: loadWeeklyLessonPlans,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      // Sticky Illustration Header
                      EnterpriseUIComponents.buildHeaderWithIllustration(
                        title: 'Your Lessons are here!',
                        subtitle: 'Access your lessons and study materials',
                        illustration: Image.asset(
                          'assets/images/lessonplanpage.jpg',
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.menu_book_outlined,
                            color: primaryColor,
                            size: 40,
                          ),
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: Column(
                            children: [
                              if (weeklyLessonPlans.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                        color: Colors.orange
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(Icons.event_busy,
                                          color: Colors.orange),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'No lessons are scheduled for this week.',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 8),
                              _buildWeekNavigation(),
                              const SizedBox(height: 16),
                              ..._buildDailySchedules(),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildWeekNavigation() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousWeek,
            icon: const Icon(Icons.arrow_back, color: Colors.black87),
          ),
          Text(
            _getWeekRangeText(),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          IconButton(
            onPressed: _nextWeek,
            icon: const Icon(Icons.arrow_forward, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildDailySchedules() {
    final days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days.map((day) {
      final dayLessons = _getLessonsForDay(day);
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildDaySchedule(day, dayLessons),
      );
    }).toList();
  }

  Widget _buildDaySchedule(String day, List<Map<String, dynamic>> lessons) {
    final appConfig = Provider.of<AppConfigProvider>(context, listen: false); // Listen false since it's inside build map (but actually it's a method call from build, so it's fine)
    // Better to pass colors or get them here. Since we are in a method of State, we can access context.
    final primaryColor = appConfig.primaryColorObj;
    
    final rawDate = lessons.isNotEmpty
        ? lessons.first['date']?.toString() ?? ''
        : '';
    final date = _formatDateString(rawDate);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                if (date.isNotEmpty)
                  Text(
                    date,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Subject',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Text(
                        'Syllabus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (lessons.isNotEmpty)
                  ...lessons.map((lesson) => _buildLessonRow(lesson))
                else
                  Row(
                    children: const [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Not Scheduled',
                          style: TextStyle(fontSize: 14, color: Colors.red),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          '-',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          '-',
                          style: TextStyle(fontSize: 14, color: Colors.grey),
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

  Widget _buildLessonRow(Map<String, dynamic> lesson) {
    final appConfig = Provider.of<AppConfigProvider>(context, listen: false);
    final secondaryColor = appConfig.secondaryColorObj;
    final primaryColor = appConfig.primaryColorObj;

    final subjectName =
        lesson['subject_name'] ?? lesson['name'] ?? 'Unknown Subject';
    final subjectCode = lesson['subject_code'] ?? lesson['code'] ?? '';
    final timeFrom = lesson['time_from'] ?? '';
    final timeTo = lesson['time_to'] ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '$subjectName ($subjectCode)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '$timeFrom - $timeTo',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
          Expanded(
            flex: 1,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () {
                // Extract subject_syllabus_id (dynamic from API)
                final subjectSyllabusId = _extractSubjectSyllabusId(
                  Map<String, dynamic>.from(lesson),
                );
                

                if (subjectSyllabusId.isEmpty) {
                  
                }

                // Extract attachment - use the same comprehensive extraction as LessonPlan model
                String attachment = '';
                final attachmentKeys = [
                  'attachment',
                  'document',
                  'file',
                  'file_name',
                  'upload_file',
                  'attached_file',
                  'material',
                  'syllabus_attachment',
                  'lesson_attachment',
                  'lesson_plan_attachment',
                  'attached_document',
                  'document_file',
                  'file_path',
                  'file_url',
                  'uploaded_file',
                  'uploaded_file_url',
                  'file_url_path',
                  'document_path',
                  'attachment_path',
                  'lesson_file',
                  'syllabus_file',
                ];
                
                // Check direct keys
                for (final key in attachmentKeys) {
                  if (lesson[key] != null &&
                      lesson[key].toString().trim().isNotEmpty &&
                      lesson[key].toString().toLowerCase() != 'null') {
                    attachment = lesson[key].toString().trim();
                    
                    break;
                  }
                }
                
                // If not found, check nested structures
                if (attachment.isEmpty && lesson['attachment_data'] is Map) {
                  final attachmentData = lesson['attachment_data'] as Map<String, dynamic>;
                  for (final key in attachmentKeys) {
                    if (attachmentData[key] != null &&
                        attachmentData[key].toString().trim().isNotEmpty &&
                        attachmentData[key].toString().toLowerCase() != 'null') {
                      attachment = attachmentData[key].toString().trim();
                      
                      break;
                    }
                  }
                }
                
                if (attachment.isEmpty && lesson['file_info'] is Map) {
                  final fileInfo = lesson['file_info'] as Map<String, dynamic>;
                  for (final key in attachmentKeys) {
                    if (fileInfo[key] != null &&
                        fileInfo[key].toString().trim().isNotEmpty &&
                        fileInfo[key].toString().toLowerCase() != 'null') {
                      attachment = fileInfo[key].toString().trim();
                      
                      break;
                    }
                  }
                }
                
                if (attachment.isEmpty) {
                  
                  
                } else {
                  
                }

                // Extract presentation
                String presentation = '';
                final presentationKeys = ['presentation', 'presentation_file', 'ppt'];
                for (final key in presentationKeys) {
                  if (lesson[key] != null && lesson[key].toString().trim().isNotEmpty) {
                    presentation = lesson[key].toString().trim();
                    break;
                  }
                }

                // Extract video
                String video = '';
                final videoKeys = ['video', 'video_url', 'youtube_url', 'youtube_video', 'url', 'lecture_video'];
                for (final key in videoKeys) {
                  if (lesson[key] != null && lesson[key].toString().trim().isNotEmpty) {
                    video = lesson[key].toString().trim();
                    break;
                  }
                }

                // Create LessonPlan object from lesson data
                final lessonPlan = LessonPlan(
                  id: lesson['id']?.toString() ?? '1',
                  subjectId:
                      subjectSyllabusId, // Use the preserved subject_syllabus_id (dynamic from API)
                  subjectName: subjectName,
                  subjectCode: subjectCode,
                  topicName:
                      lesson['topic_name']?.toString() ?? 'School Day\'s',
                  lessonName:
                      lesson['lesson_name']?.toString() ??
                      lesson['topic_name']?.toString() ??
                      'First Day at School',
                  description:
                      lesson['description']?.toString() ??
                      'A general objective is a statement that communicates the overall goal of a project in a single sentence, focusing on the broad outcome rather than specific actions.',
                  date: lesson['date']?.toString() ?? '06/09/2025',
                  timeFrom: timeFrom,
                  timeTo: timeTo,
                  className: lesson['class_name']?.toString() ?? 'Class 1',
                  section: lesson['section']?.toString() ?? 'A',
                  teacherName:
                      lesson['teacher_name']?.toString() ?? 'Teacher Name',
                  isActive: lesson['is_active']?.toString() ?? '1',
                  createdAt:
                      lesson['created_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  updatedAt:
                      lesson['updated_at']?.toString() ??
                      DateTime.now().toIso8601String(),
                  attachment: attachment,
                  presentation: presentation,
                  video: video,
                );

                

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        LessonPlanDetailPage(lessonPlan: lessonPlan),
                  ),
                );
              },
              child: Tooltip(
                message: 'Click to view lesson details',
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: primaryColor.withValues(alpha: 0.05),
                  ),
                  child: Image.asset(
                    'assets/images/ic_nav_subject.png',
                    width: 24,
                    height: 24,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
