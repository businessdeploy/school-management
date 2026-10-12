import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/lesson_plan.dart';
import '../utils/url_manager.dart';
import '../utils/response_validator.dart';
import 'auth_service.dart';
import 'api/lesson_api.dart';

class LessonPlanService {
  /// Get syllabus subjects with correct subject IDs
  static Future<List<Map<String, dynamic>>> getSyllabusSubjects(String studentId) async {
    try {
      final response = await LessonApi.getSyllabusStatus(studentId);
      
      if (response['status'] == 1 && response['data'] != null) {
        final subjects = List<Map<String, dynamic>>.from(response['data']['subjects'] ?? []);
        return subjects;
      } else {
        return _getMockSyllabusSubjects();
      }
    } catch (e) {
      return _getMockSyllabusSubjects();
    }
  }

  /// Mock syllabus subjects data
  static List<Map<String, dynamic>> _getMockSyllabusSubjects() {
    return [
      {
        'subject_group_subject_id': '142',
        'subject_name': 'English',
        'subject_code': '210',
        'total': '5',
        'total_complete': '3'
      },
      {
        'subject_group_subject_id': '147',
        'subject_name': 'Drawing',
        'subject_code': '200',
        'total': '2',
        'total_complete': '1'
      },
      {
        'subject_group_subject_id': '149',
        'subject_name': 'Elective 1',
        'subject_code': '101',
        'total': '2',
        'total_complete': '1'
      },
      {
        'subject_group_subject_id': '150',
        'subject_name': 'Elective 2',
        'subject_code': '102',
        'total': '2',
        'total_complete': '1'
      }
    ];
  }

  /// Fetch lesson plan data for a specific student and date range
  static Future<Map<String, List<LessonPlan>>> getLessonPlan(
    String studentId, 
    DateTime dateFrom, 
    DateTime dateTo
  ) async {
    try {
      final response = await LessonApi.getLessonPlan(studentId);
      
      if (response['status'] == 1 && response['timetable'] != null) {
        final Map<String, List<LessonPlan>> weeklyLessons = {};
        final timetable = response['timetable'];
        
        // Process each day of the week
        final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
        
        for (String day in days) {
          if (timetable[day] != null && timetable[day] is List) {
            try {
              final dayLessons = (timetable[day] as List)
                  .map((item) => LessonPlan.fromJson(item))
                  .toList();
              weeklyLessons[day] = dayLessons;
            } catch (e) {
              weeklyLessons[day] = [];
            }
          } else {
            weeklyLessons[day] = [];
          }
        }
        
        return weeklyLessons;
      } else {
        return _emptyWeeklyLessonPlanData();
      }
    } catch (e) {
      return _emptyWeeklyLessonPlanData();
    }
  }

  /// Fetch weekly lesson plan data for a specific student and week
  static Future<List<LessonPlan>> getWeeklyLessonPlan(
    String studentId,
    DateTime weekStart,
  ) async {
    try {
      final headers = await AuthService.getApiHeaders();
      final baseUrl = await UrlManager.getBaseUrl();

      // Calculate week end date (7 days from start)
      final weekEnd = weekStart.add(const Duration(days: 6));

      // Format dates for API
      final dateFrom =
          '${weekStart.year}-${weekStart.month.toString().padLeft(2, '0')}-${weekStart.day.toString().padLeft(2, '0')}';
      final dateTo =
          '${weekEnd.year}-${weekEnd.month.toString().padLeft(2, '0')}-${weekEnd.day.toString().padLeft(2, '0')}';

      // Use the lesson plan endpoint with date range
      final url = Uri.parse('$baseUrl/api/webservice/getLessonPlan');

      // Per cURL, lesson plan body expects only student_id, date_from, date_to
      final body = jsonEncode({
        'student_id': studentId,
        'date_from': dateFrom,
        'date_to': dateTo,
      });


      final response = await http.post(url, headers: headers, body: body);


      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJsonMap(
          response.body,
          'weekly lesson plan',
        );

        // Check for different possible response structures
        List<dynamic> lessonData = [];

        if (data['data'] != null && data['data'] is List) {
          lessonData = data['data'];
        } else if (data['lesson_plans'] != null &&
            data['lesson_plans'] is List) {
          lessonData = data['lesson_plans'];
        } else if (data['lessons'] != null && data['lessons'] is List) {
          lessonData = data['lessons'];
        } else if (data['result'] != null && data['result'] is List) {
          lessonData = data['result'];
        } else {
        }

        if (lessonData.isNotEmpty) {
          final lessonPlans =
              lessonData.map((item) => LessonPlan.fromJson(item)).toList();
          return lessonPlans;
        } else {
          return <LessonPlan>[];
        }
      } else {
        return <LessonPlan>[];
      }
    } catch (e) {
      return <LessonPlan>[];
    }
  }

  /// Get lesson plans for a specific date
  static List<LessonPlan> getLessonsForDate(
    List<LessonPlan> allLessons,
    DateTime date,
  ) {
    return allLessons.where((lesson) {
      try {
        final lessonDate = DateTime.parse(lesson.date);
        return lessonDate.year == date.year &&
            lessonDate.month == date.month &&
            lessonDate.day == date.day;
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Format date for display
  static String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  /// Get day name from weekday number
  static String getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  /// Test lesson plan API connectivity and response format
  static Future<Map<String, dynamic>> testLessonPlanApi(String studentId) async {
    try {
      final response = await LessonApi.getLessonPlan(studentId);
      
      return {
        'success': true,
        'status': response['status'],
        'message': response['message'],
        'has_data': response['timetable'] != null,
        'timetable_keys': response['timetable'] != null ? (response['timetable'] as Map).keys.toList() : [],
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }



  /// Get mock weekly lesson plan data for testing
  static Map<String, List<LessonPlan>> getMockWeeklyLessonPlanData() {
    return {
      'Monday': [
        LessonPlan(
          id: '1',
          subjectId: '142', // English subject ID
          subjectName: 'English',
          subjectCode: 'ENG',
          topicName: 'Wonderland',
          lessonName: 'Alice In Wonderland',
          description: 'Introduction to Alice in Wonderland',
          date: '2025-07-28',
          timeFrom: '9:00 AM',
          timeTo: '09:45 AM',
          className: 'Class 5',
          section: 'A',
          teacherName: 'Sarah Johnson',
          isActive: '1',
          createdAt: '2025-03-31 11:29:03',
          updatedAt: '2025-03-31 11:29:03',
          attachment: '',
          presentation: '',
          video: '',
        ),
        LessonPlan(
          id: '2',
          subjectId: '143', // Mathematics subject ID
          subjectName: 'Mathematics',
          subjectCode: 'MATH',
          topicName: 'Algebra Basics',
          lessonName: 'Introduction to Algebra',
          description: 'Basic algebraic concepts and equations',
          date: '2025-07-28',
          timeFrom: '10:00 AM',
          timeTo: '10:45 AM',
          className: 'Class 5',
          section: 'A',
          teacherName: 'John Smith',
          isActive: '1',
          createdAt: '2025-03-31 11:29:03',
          updatedAt: '2025-03-31 11:29:03',
          attachment: '',
          presentation: '',
          video: '',
        ),
        LessonPlan(
          id: '3',
          subjectId: '147', // Hindi subject ID
          subjectName: 'Hindi',
          subjectCode: 'HIN',
          topicName: 'Hindi Grammar',
          lessonName: 'Basic Hindi Grammar',
          description: 'Introduction to Hindi grammar and sentence structure',
          date: '2025-07-28',
          timeFrom: '11:00 AM',
          timeTo: '11:45 AM',
          className: 'Class 5',
          section: 'A',
          teacherName: 'Mrs. Priya Sharma',
          isActive: '1',
          createdAt: '2025-03-31 11:29:03',
          updatedAt: '2025-03-31 11:29:03',
          attachment: '',
          presentation: '',
          video: '',
        ),
      ],
      'Tuesday': [
        LessonPlan(
          id: '4',
          subjectId: '144', // Science subject ID
          subjectName: 'Science',
          subjectCode: 'SCI',
          topicName: 'Photosynthesis',
          lessonName: 'Plant Life Processes',
          description: 'Understanding how plants make food',
          date: '2025-07-29',
          timeFrom: '9:00 AM',
          timeTo: '09:45 AM',
          className: 'Class 5',
          section: 'A',
          teacherName: 'Dr. Emily Brown',
          isActive: '1',
          createdAt: '2025-03-31 11:29:03',
          updatedAt: '2025-03-31 11:29:03',
          attachment: '',
          presentation: '',
          video: '',
        ),
      ],
      'Wednesday': [
        LessonPlan(
          id: '5',
          subjectId: '145', // History subject ID
          subjectName: 'History',
          subjectCode: 'HIST',
          topicName: 'Ancient Civilizations',
          lessonName: 'Egyptian Pyramids',
          description: 'Understanding ancient Egyptian culture and architecture',
          date: '2025-07-30',
          timeFrom: '10:30 AM',
          timeTo: '11:15 AM',
          className: 'Class 5',
          section: 'A',
          teacherName: 'Prof. Michael Davis',
          isActive: '1',
          createdAt: '2025-03-31 11:29:03',
          updatedAt: '2025-03-31 11:29:03',
          attachment: '',
          presentation: '',
          video: '',
        ),
      ],
      'Thursday': [
        LessonPlan(
          id: '6',
          subjectId: '146', // Geography subject ID
          subjectName: 'Geography',
          subjectCode: 'GEO',
          topicName: 'Continents and Oceans',
          lessonName: 'World Geography',
          description: 'Understanding the world\'s continents and major oceans',
          date: '2025-07-31',
          timeFrom: '9:00 AM',
          timeTo: '09:45 AM',
          className: 'Class 5',
          section: 'A',
          teacherName: 'Ms. Lisa Wilson',
          isActive: '1',
          createdAt: '2025-03-31 11:29:03',
          updatedAt: '2025-03-31 11:29:03',
          attachment: '',
          presentation: '',
          video: '',
        ),
      ],
      'Friday': [],
      'Saturday': [],
      'Sunday': [],
    };
  }

  /// Internal helper: empty weekly structure without any static/mock lessons
  static Map<String, List<LessonPlan>> _emptyWeeklyLessonPlanData() {
    return {
      'Monday': [],
      'Tuesday': [],
      'Wednesday': [],
      'Thursday': [],
      'Friday': [],
      'Saturday': [],
      'Sunday': [],
    };
  }

  /// Get mock lesson plan data for testing (legacy method)
  static List<LessonPlan> getMockLessonPlanData() {
    final weeklyData = getMockWeeklyLessonPlanData();
    final List<LessonPlan> allLessons = [];
    for (var lessons in weeklyData.values) {
      allLessons.addAll(lessons);
    }
    return allLessons;
  }

}
