import 'package:flutter/material.dart';
import '../models/lesson_plan.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';
import 'package:provider/provider.dart';
import '../providers/app_config_provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/translated_text.dart';
import 'syllabus_detail_page.dart';
import '../widgets/enterprise_ui_components.dart';

class LessonPlanPage extends StatefulWidget {
  const LessonPlanPage({super.key});

  @override
  State<LessonPlanPage> createState() => _LessonPlanPageState();
}

class _LessonPlanPageState extends State<LessonPlanPage> {
  Map<String, List<LessonPlan>> weeklyLessons = {};
  bool isLoading = true;
  String? errorMessage;
  DateTime selectedWeekStart = DateTime.now();

  @override
  void initState() {
    super.initState();
    loadLessonPlan();
  }

  String _formatDate(DateTime date) {
    // Format: 27 Oct 2025
    const monthNames = [
      'Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = monthNames[date.month - 1];
    return '$day $month ${date.year}';
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return 'Unknown';
    }
  }

  Future<void> loadLessonPlan() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      
      
      
      

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();
      

      // Get base URL
      final baseUrl = await AppConfig.getBaseUrl();
      if (baseUrl.isEmpty) {
        throw Exception('No base URL configured');
      }
      

      // Get headers
      final headers = await AppConfig.getCompleteHeaders();
      

      // Make API call
      final url = Uri.parse('$baseUrl/api/webservice/getlessonplan');
      final body = jsonEncode({'student_id': studentId});
      
      
      

      final response = await http.post(url, headers: headers, body: body).timeout(
        const Duration(seconds: 15),
      );

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        
        if (data['status'] == 1 && data['timetable'] != null) {
          final timetable = data['timetable'] as Map<String, dynamic>;
          
          
          final lessons = <String, List<LessonPlan>>{};
          
          for (final dayEntry in timetable.entries) {
            final dayName = dayEntry.key;
            final dayLessonsData = dayEntry.value as List<dynamic>;
            
            
            
            final dayLessons = <LessonPlan>[];
            for (final lessonData in dayLessonsData) {
              if (lessonData is Map<String, dynamic>) {
                try {
                  final lesson = LessonPlan.fromJson(lessonData);
                  dayLessons.add(lesson);
                  
                } catch (e) {
                  
                }
              }
            }
            
            lessons[dayName] = dayLessons;
          }
          
          
          
          
          if (!mounted) return;
          
          setState(() {
            weeklyLessons = lessons;
            isLoading = false;
          });
        } else {
          throw Exception('No timetable data in API response');
        }
      } else {
        throw Exception('API returned status ${response.statusCode}');
      }
    } catch (e) {
      
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to load lesson plan: $e';
      });
    }
  }

  void _previousWeek() {
    setState(() {
      selectedWeekStart = selectedWeekStart.subtract(const Duration(days: 7));
    });
    loadLessonPlan();
  }

  void _nextWeek() {
    setState(() {
      selectedWeekStart = selectedWeekStart.add(const Duration(days: 7));
    });
    loadLessonPlan();
  }

  void _resetToCurrentWeek() {
    setState(() {
      selectedWeekStart = DateTime.now();
    });
    
    loadLessonPlan();
  }

  Future<void> _testApiDirectly() async {
    try {
      
      
      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();
      
      // Get base URL
      final baseUrl = await AppConfig.getBaseUrl();
      if (baseUrl.isEmpty) {
        throw Exception('No base URL configured');
      }
      
      // Get headers
      final headers = await AppConfig.getCompleteHeaders();
      
      // Make API call
      final url = Uri.parse('$baseUrl/api/webservice/getlessonplan');
      final body = jsonEncode({'student_id': studentId});
      
      
      
      
      
      final response = await http.post(url, headers: headers, body: body).timeout(
        const Duration(seconds: 10),
      );
      
      
      
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Test Results'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: ${response.statusCode}'),
                Text('URL: $url'),
                Text('Body: $body'),
                const SizedBox(height: 8),
                const Text('Response:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(response.body, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                loadLessonPlan();
              },
              child: const Text('Reload'),
            ),
          ],
        ),
      );
    } catch (e) {
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('API Test Error'),
          content: Text('Error: $e'),
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

  Widget _buildDayCard(String dayName, DateTime date, List<LessonPlan> dayLessons) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                  TranslatedText(
                    dayName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                const SizedBox(width: 8),
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (dayLessons.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${dayLessons.length} ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const TranslatedText(
                          'lessons',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          
          // Lessons content
          if (dayLessons.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              child: const Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 48,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 8),
                    TranslatedText(
                      'No lessons scheduled',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: dayLessons.map((lesson) => _buildLessonCard(lesson)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLessonCard(LessonPlan lesson) {
    final appConfig = Provider.of<AppConfigProvider>(context);
    final secondaryColor = appConfig.secondaryColorObj;

    return InkWell(
      onTap: () {
        if (lesson.subjectId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SyllabusDetailPage(
                subjectSyllabusId: lesson.subjectId,
                lessonName: lesson.lessonName,
                topicName: lesson.topicName,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: TranslatedText('Syllabus details not available')),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueGrey[50],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            lesson.subjectName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (lesson.video.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.play_circle_fill,
                              color: Colors.red, size: 18),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: secondaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${lesson.timeFrom} - ${lesson.timeTo}',
                      style: TextStyle(
                        fontSize: 11,
                        color: secondaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lesson.lessonName.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 80,
                          child: TranslatedText(
                            'Lesson',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ': ${lesson.lessonName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (lesson.topicName.isNotEmpty) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                          width: 80,
                          child: TranslatedText(
                            'Topic',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ': ${lesson.topicName}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get theme colors
    final appConfig = Provider.of<AppConfigProvider>(context);
    final primaryColor = appConfig.primaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const TranslatedText('Lesson Plan'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadLessonPlan,
            tooltip: 'Reload',
          ),
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: _resetToCurrentWeek,
            tooltip: 'Current Week',
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _testApiDirectly,
            tooltip: 'Test API',
          ),
        ],
      ),
      body: Column(
        children: [
          // Sticky Illustration Header
          EnterpriseUIComponents.buildHeaderWithIllustration(
            title: 'Your Lesson Plan is here!',
            subtitle: 'View your weekly academic schedule',
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
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Week navigation
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    color: primaryColor.withValues(alpha: 0.05),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.chevron_left, color: primaryColor),
                          onPressed: _previousWeek,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TranslatedText(
                              'Week of',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text(
                              ' ${_formatDate(selectedWeekStart)}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.chevron_right, color: primaryColor),
                          onPressed: _nextWeek,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Loading or Error State
                  if (isLoading)
                    const Padding(
                      padding: EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          TranslatedText(
                            'Loading lesson plan...',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  else if (errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 100),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 64,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          const TranslatedText(
                            'Error loading lesson plan',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            errorMessage!,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton(
                            onPressed: loadLessonPlan,
                            child: const TranslatedText('Retry'),
                          ),
                        ],
                      ),
                    )
                  else
                    // Daily Schedule Cards
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 20),
                      itemCount: 7,
                      itemBuilder: (context, index) {
                        final date = selectedWeekStart.add(Duration(days: index));
                        final dayName = _getDayName(date.weekday);
                        final dayLessons = weeklyLessons[dayName] ?? [];
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _buildDayCard(dayName, date, dayLessons),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
