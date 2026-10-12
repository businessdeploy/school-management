import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../services/api/timetable_api.dart';
import '../services/auth_service.dart';
import '../config/app_config.dart';
import '../models/lesson_plan.dart';
import '../providers/app_config_provider.dart';
import '../widgets/translated_text.dart';
import '../widgets/enterprise_ui_components.dart';

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  String schoolName = '';
  String schoolLogo = '';
  bool isLoading = true;
  String? error;
  Map<String, dynamic>? timetableData;

  final List<String> _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  @override
  void initState() {
    super.initState();
    loadSchoolInfo();
    loadTimetable();
  }

  Future<void> loadSchoolInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final logoUrl = await AppConfig.getAppLogo();
    setState(() {
      schoolName = prefs.getString('site_url') ?? 'Prime School';
      schoolLogo = logoUrl;
    });
  }

  Future<void> loadTimetable() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final studentId = await AuthService.getStudentId();
      final data = await TimetableApi.getClassSchedule(studentId);

      setState(() {
        timetableData = data;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Provider.of<AppConfigProvider>(context).primaryColorObj;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const TranslatedText(
          'Class Timetable',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? EnterpriseUIComponents.buildLoadingIndicator(
              message: 'Loading timetable...',
            )
          : error != null
              ? EnterpriseUIComponents.buildErrorState(
                  error: error!,
                  onRetry: loadTimetable,
                )
              : Column(
                  children: [
                    // Enterprise Header (Sticky)
                    EnterpriseUIComponents.buildHeaderWithIllustration(
                      title: 'Class Timetable',
                      subtitle: 'Check your daily class schedule',
                      illustration: Image.asset(
                        'assets/images/timetablepage.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Container(
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.calendar_month, color: primaryColor, size: 32),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            const SizedBox(height: 12),
                            // Vertical List of Days with Tabular Layout
                            ..._buildDailySchedules(primaryColor),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _buildDailySchedules(Color primaryColor) {
    if (timetableData == null || timetableData!['timetable'] == null) {
      return [
        EnterpriseUIComponents.buildEmptyState(
          title: 'No Data',
          message: 'Timetable information is not available.',
          icon: Icons.calendar_today_outlined,
        )
      ];
    }

    final timetable = timetableData!['timetable'] as Map<String, dynamic>;
    
    return _days.map((day) {
      final schedule = timetable[day] as List<dynamic>? ?? [];
      return _buildDaySection(day, schedule, primaryColor);
    }).toList();
  }

  Widget _buildDaySection(String day, List<dynamic> schedule, Color primaryColor) {
    final bool isToday = _isToday(day);


    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Day Header (Using Theme Secondary Color)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey[50], // Standard slate-grey header
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
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor, // Use Primary Color for TODAY
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'TODAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Tabular Period List
          if (schedule.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'No classes scheduled',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Table Header
                   Row(
                    children: const [
                      Expanded(
                        flex: 5,
                        child: Text(
                          'Time',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Subject',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Room No.',
                          textAlign: TextAlign.right,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  
                  // Table Rows
                  ...schedule.map((item) => _buildPeriodRow(Map<String, dynamic>.from(item))),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPeriodRow(Map<String, dynamic> item) {
    LessonPlan? lesson;
    try {
      lesson = LessonPlan.fromJson(item);
    } catch (_) {}

    String subjectName = _extractSubjectName(item);
    String subjectCode = _extractSubjectCode(item);
    
    if (subjectName.isEmpty && lesson != null && lesson.subjectName.isNotEmpty) {
      subjectName = lesson.subjectName;
    }
    if (subjectCode.isEmpty && lesson != null && lesson.subjectCode.isNotEmpty) {
      subjectCode = lesson.subjectCode;
    }

    String timeRange = _formatTimeRange(item);
    if (timeRange.isEmpty && lesson != null && (lesson.timeFrom.isNotEmpty || lesson.timeTo.isNotEmpty)) {
      final from = _formatTime(lesson.timeFrom);
      final to = _formatTime(lesson.timeTo);
      timeRange = (from.isNotEmpty && to.isNotEmpty) ? '$from - $to' : from.isNotEmpty ? from : to;
    }

    String roomNo = _extractRoomNo(item);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              timeRange,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  subjectName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14, 
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (subjectCode.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '($subjectCode)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              roomNo,
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(String day) {
    final now = DateTime.now();
    final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return day == weekdays[now.weekday - 1];
  }

  String _extractSubjectName(Map<String, dynamic> item) {
    final keys = ['subject_name', 'subjectName', 'subject', 'name', 'subject_title'];
    for (final key in keys) {
      final val = item[key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString().toLowerCase() != 'null') {
        return val.toString().trim();
      }
    }
    return '';
  }

  String _extractSubjectCode(Map<String, dynamic> item) {
    final keys = ['subject_code', 'subjectCode', 'code', 'subject_id'];
    for (final key in keys) {
      final val = item[key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString().toLowerCase() != 'null') {
        return val.toString().trim();
      }
    }
    return '';
  }

  String _extractRoomNo(Map<String, dynamic> item) {
    final keys = ['room_no', 'roomNo', 'room', 'class_room'];
    for (final key in keys) {
      final val = item[key];
      if (val != null && val.toString().trim().isNotEmpty && val.toString().toLowerCase() != 'null') {
        return val.toString().trim();
      }
    }
    return '-';
  }

  String _formatTimeRange(Map<String, dynamic> item) {
    String? fromTime;
    String? toTime;
    
    final fromKeys = ['time_from', 'timeFrom', 'start_time', 'from_time'];
    final toKeys = ['time_to', 'timeTo', 'end_time', 'to_time'];
    
    for (final key in fromKeys) {
      if (item[key] != null && item[key].toString().isNotEmpty) {
        fromTime = item[key].toString();
        break;
      }
    }
    for (final key in toKeys) {
      if (item[key] != null && item[key].toString().isNotEmpty) {
        toTime = item[key].toString();
        break;
      }
    }
    
    final from = _formatTime(fromTime);
    final to = _formatTime(toTime);
    
    if (from.isEmpty && to.isEmpty) return '';
    return '$from - $to';
  }

  String _formatTime(String? time) {
    if (time == null || time.isEmpty || time.toLowerCase() == 'null') return '';
    try {
      var cleanTime = time.trim();
      if (cleanTime.split(':').length == 3) cleanTime = cleanTime.substring(0, 5);
      if (cleanTime.toUpperCase().contains('AM') || cleanTime.toUpperCase().contains('PM')) return cleanTime;
      
      final parts = cleanTime.split(':');
      if (parts.length < 2) return cleanTime;
      
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final suffix = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
    } catch (_) {
      return time;
    }
  }
}
