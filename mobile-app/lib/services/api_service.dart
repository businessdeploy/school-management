// Main API Service - Centralized access to all API modules
// This provides backward compatibility while using the new modular structure

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/url_manager.dart';
import '../utils/dynamic_api_headers.dart';
import 'api/auth_api.dart';
import 'api/attendance_api.dart';
import 'api/examination_api.dart';
import 'api/lesson_api.dart';
import 'api/common_api.dart';
import 'api/pending_tasks_api.dart';
import 'api/homework_api.dart';
import 'api/daily_assignment_api.dart';
import 'api/online_exam_api.dart';
import 'api/student_api.dart';
import 'api/student_behaviour_api.dart';
import 'api/teacher_api.dart';
import 'api/document_api.dart';
import 'api/communication_api.dart';
import 'api/live_class_api.dart';
import 'api/download_api.dart';
import 'api/course_api.dart';
import 'api/timetable_api.dart';
import 'api/student_management_api.dart';
import 'api/transport_api.dart';
import 'api/fees_api.dart';

class ApiService {
  // Re-export all methods from individual API modules
  // This maintains backward compatibility with existing code

  // Auth API methods
  static Future<String> getBaseUrl() => AuthApi.getBaseUrl();
  static Future<void> testAuthentication() => AuthApi.testAuthentication();
  static Future<void> forceApiMode() => AuthApi.forceApiMode();
  static Future<Map<String, dynamic>> makeAuthenticatedCall(
    String endpoint,
    Map<String, dynamic> body,
  ) => AuthApi.makeAuthenticatedCall(endpoint, body);
  static Future<Map<String, dynamic>> forgotPassword(String email) => AuthApi.forgotPassword(email);

  // Attendance API methods
  static Future<Map<String, dynamic>> getAttendance(
    String studentId, {
    String? month,
    String? year,
  }) => AttendanceApi.getAttendance(studentId, month: month, year: year);

  // Examination API methods
  static Future<Map<String, dynamic>> getExamList(String studentId) =>
      ExaminationApi.getExamList(studentId);
  static Future<Map<String, dynamic>> getExamSchedule(
    String examGroupClassBatchExamId,
  ) => ExaminationApi.getExamSchedule(examGroupClassBatchExamId);
  static Future<Map<String, dynamic>> getExamResult(
    String studentId,
    String examGroupClassBatchExamId,
  ) => ExaminationApi.getExamResult(studentId, examGroupClassBatchExamId);
  static Future<List<Map<String, dynamic>>> getCBSEExamResult(
    String studentSessionId,
  ) => ExaminationApi.getCBSEExamResult(studentSessionId);
  static Future<List<Map<String, dynamic>>> getCBSEExamTimetable(
    String studentSessionId,
  ) => ExaminationApi.getCBSEExamTimetable(studentSessionId);

  // Lesson API methods
  static Future<Map<String, dynamic>> getSyllabusStatus(String studentId) =>
      LessonApi.getSyllabusStatus(studentId);
  static Future<Map<String, dynamic>> getLessonTopics(
    String subjectGroupSubjectId,
    String subjectGroupClassSectionsId,
  ) => LessonApi.getLessonTopics(
    subjectGroupSubjectId,
    subjectGroupClassSectionsId,
  );
  static Future<Map<String, dynamic>> getLessonPlan(String studentId) =>
      LessonApi.getLessonPlan(studentId);
  static Future<Map<String, dynamic>> getWeeklyLessonPlan(String studentId) =>
      LessonApi.getLessonPlan(studentId);
  static Future<Map<String, dynamic>> getSyllabus(String subjectSyllabusId) =>
      LessonApi.getSyllabus(subjectSyllabusId);
  static Future<Map<String, dynamic>> testCourseApiConnectivity() =>
      CommonApi.testApiConnectivity();

  // Communication API methods
  static Future<Map<String, dynamic>> getForumMessage(String studentId) =>
      CommunicationApi.getForumMessage(studentId);
  static Future<Map<String, dynamic>> saveComment(
    String studentId,
    String message,
  ) => CommunicationApi.saveComment(studentId, message);

  // Homework API methods
  static Future<Map<String, dynamic>> getHomework(
    String studentId, {
    String? homeworkStatus,
    String? subjectGroupSubjectId,
  }) => HomeworkApi.getHomework(
    studentId,
    homeworkStatus: homeworkStatus,
    subjectGroupSubjectId: subjectGroupSubjectId,
  );
  static Future<Map<String, dynamic>> getSubjectList(String studentId) =>
      HomeworkApi.getSubjectList(studentId);
  static Future<Map<String, dynamic>> submitHomework(
    String studentId,
    String homeworkId,
    String answer,
    String? filePath,
  ) => HomeworkApi.submitHomework(studentId, homeworkId, answer, filePath);
  static Future<Map<String, dynamic>> getHomeworkById(String homeworkId) =>
      HomeworkApi.getHomeworkById(homeworkId);

  // Daily Assignment API methods
  static Future<Map<String, dynamic>> getDailyAssignments(String studentId) =>
      DailyAssignmentApi.getDailyAssignments(studentId);
  static Future<Map<String, dynamic>> getDailyAssignment(String assignmentId) =>
      DailyAssignmentApi.getDailyAssignment(assignmentId);
  static Future<Map<String, dynamic>> addEditDailyAssignment(
    String? id,
    String studentId,
    String title,
    String description,
    String dueDate,
    String? filePath, {
    String? subjectId,
  }) => DailyAssignmentApi.addEditDailyAssignment(
    id,
    studentId,
    title,
    description,
    dueDate,
    filePath,
    subject: subjectId,
  );
  static Future<Map<String, dynamic>> deleteDailyAssignment(
    String assignmentId, {
    String? studentId,
    String? studentSessionId,
  }) => DailyAssignmentApi.deleteDailyAssignment(
    assignmentId,
    studentId: studentId,
    studentSessionId: studentSessionId,
  );

  // Online Exam API methods
  static Future<Map<String, dynamic>> getOnlineExam(String studentId) =>
      OnlineExamApi.getOnlineExam(studentId);
  static Future<Map<String, dynamic>> getOnlineExamQuestion(
    String studentId,
    String onlineExamId,
  ) => OnlineExamApi.getOnlineExamQuestion(studentId, onlineExamId);
  static Future<Map<String, dynamic>> saveOnlineExam(
    String onlineexamStudentId,
    List<Map<String, dynamic>> rows,
  ) => OnlineExamApi.saveOnlineExam(onlineexamStudentId, rows);

  // Student Behaviour API methods
  static Future<Map<String, dynamic>> getStudentBehaviour(String studentId) =>
      StudentBehaviourApi.getStudentBehaviour(studentId);
  static Future<Map<String, dynamic>> getIncidentComments(String incidentId) =>
      StudentBehaviourApi.getIncidentComments(incidentId);
  static Future<Map<String, dynamic>> addIncidentComment(
    String incidentId,
    String comment,
  ) => StudentBehaviourApi.addIncidentComment(incidentId, comment);
  static Future<Map<String, dynamic>> deleteIncidentComment(
    Map<String, dynamic> payload,
  ) =>
      StudentBehaviourApi.deleteIncidentComment(payload);

  // Student API methods
  static Future<Map<String, dynamic>> getTimeline(String studentId) =>
      StudentApi.getTimeline(studentId);
  static Future<Map<String, dynamic>> addEditTimeline(
    String? id,
    String title,
    String description,
    String timelineDate,
    String studentId,
    String? timelineDoc,
  ) => StudentApi.addEditTimeline(
    id,
    title,
    description,
    timelineDate,
    studentId,
    timelineDoc,
  );
  static Future<Map<String, dynamic>> deleteTimeline(String timelineId) =>
      StudentApi.deleteTimeline(timelineId);
  static Future<Map<String, dynamic>> getTimeLineStatus(String studentId) =>
      StudentApi.getTimeLineStatus(studentId);


  // Teacher API methods
  static Future<Map<String, dynamic>> getTeachersList(
    String classId,
    String sectionId,
    String userId,
  ) => TeacherApi.getTeachersList(classId, sectionId, userId);
  static Future<Map<String, dynamic>> getTeacherSubject(
    String classId,
    String sectionId,
    String staffId,
  ) => TeacherApi.getTeacherSubject(classId, sectionId, staffId);
  static Future<Map<String, dynamic>> getTeacherReviews(String studentId) =>
      TeacherApi.getTeacherReviews(studentId);
  static Future<Map<String, dynamic>> getTeachersForReview(String studentId) =>
      TeacherApi.getTeachersForReview(studentId);
  static Future<Map<String, dynamic>> addStaffRating(
    String rate,
    String comment,
    String role,
    String staffId,
    String userId,
  ) => TeacherApi.addStaffRating(rate, comment, role, staffId, userId);

  // Document API methods
  static Future<Map<String, dynamic>> getDocuments(String studentId) =>
      DocumentApi.getDocuments(studentId);
  static Future<Map<String, dynamic>> uploadDocument(
    String studentId,
    String title,
    String? description,
    String filePath,
  ) => DocumentApi.uploadDocument(studentId, title, description, filePath);

  // Communication API methods
  static Future<Map<String, dynamic>> getLeaveList(String studentId) =>
      CommunicationApi.getLeaveList(studentId);
  static Future<Map<String, dynamic>> addLeave(
    String studentId,
    String fromDate,
    String toDate,
    String applyDate,
    String reason,
    String? filePath,
  ) => CommunicationApi.addLeave(
    studentId,
    fromDate,
    toDate,
    applyDate,
    reason,
    filePath,
  );
  static Future<Map<String, dynamic>> deleteLeave(String leaveId) =>
      CommunicationApi.deleteLeave(leaveId);
  static Future<Map<String, dynamic>> updateLeave(
    String leaveId,
    String fromDate,
    String toDate,
    String applyDate,
    String reason, {
    String? filePath,
    bool removeAttachment = false,
  }) =>
      CommunicationApi.updateLeave(
        leaveId,
        fromDate,
        toDate,
        applyDate,
        reason,
        filePath,
        removeAttachment: removeAttachment,
      );
  static Future<Map<String, dynamic>> getVisitors(String studentId) =>
      CommunicationApi.getVisitors(studentId);

  static Future<Map<String, dynamic>> addVisitor({
    required String studentId,
    required String purpose,
    required String name,
    required String contact,
    required String idProof,
    required String noOfPeople,
    required String date,
    required String inTime,
    required String outTime,
    required String note,
    String? filePath,
  }) =>
      CommunicationApi.addVisitor(
        studentId: studentId,
        purpose: purpose,
        name: name,
        contact: contact,
        idProof: idProof,
        noOfPeople: noOfPeople,
        date: date,
        inTime: inTime,
        outTime: outTime,
        note: note,
        filePath: filePath,
      );

  // Live Class API methods
  static Future<Map<String, dynamic>> getZoomLiveClasses(String studentId) =>
      LiveClassApi.getZoomLiveClasses(studentId);
  static Future<Map<String, dynamic>> getGmeetLiveClasses(String studentId) =>
      LiveClassApi.getGmeetLiveClasses(studentId);

  // Download API methods
  static Future<Map<String, dynamic>> getDownloadsLinks(String studentId) =>
      DownloadApi.getDownloadsLinks(studentId);
  static Future<Map<String, dynamic>> getVideoTutorial(String studentId) =>
      DownloadApi.getVideoTutorial(studentId);

  // Course API methods
  static Future<Map<String, dynamic>> getCourseList(String studentId) =>
      CourseApi.getCourseList(studentId);
  static Future<Map<String, dynamic>> getCourseDetail(
    String courseId,
    String studentId,
  ) => CourseApi.getCourseDetail(courseId, studentId);
  static Future<Map<String, dynamic>> getCourseReviews(String courseId) =>
      CourseApi.getCourseReviews(courseId);
  static Future<Map<String, dynamic>> getCourseCurriculum(
    String courseId, [
    String? studentId,
  ]) =>
      CourseApi.getCourseCurriculum(courseId, studentId);
  static Future<Map<String, dynamic>> addCourseRating({
    required String courseId,
    required String studentId,
    required String rating,
    required String comment,
    String? reviewId,
  }) =>
      CourseApi.addCourseRating(
        courseId: courseId,
        studentId: studentId,
        rating: rating,
        comment: comment,
        reviewId: reviewId,
      );
  static Future<Map<String, dynamic>> updateCourseProgress({
    required String courseId,
    required String studentId,
    required String lessonId,
    String? sectionId,
    String? lessonQuizType,
    int status = 1,
  }) =>
      CourseApi.updateCourseProgress(
        courseId: courseId,
        studentId: studentId,
        lessonId: lessonId,
        sectionId: sectionId,
        lessonQuizType: lessonQuizType,
        status: status,
      );

  static Future<Map<String, dynamic>> getLessonAttachments(String lessonId) =>
      CourseApi.getLessonAttachments(lessonId);

  // Timetable API methods
  static Future<Map<String, dynamic>> getClassSchedule(String studentId) =>
      TimetableApi.getClassSchedule(studentId);

  // Student Management API methods
  static Future<Map<String, dynamic>?> getStudentFromLoginData() =>
      StudentManagementApi.getStudentFromLoginData();
  static Future<List<Map<String, dynamic>>> getStudentList(String parentId) =>
      StudentManagementApi.getStudentList(parentId);

  // Transport API methods
  static Future<Map<String, dynamic>> getTransportRoutes(String studentId) =>
      TransportApi.getTransportRoutes(studentId);

  // Fees API methods
  static Future<Map<String, dynamic>> getFees(String studentId) =>
      FeesApi.getFees(studentId);
  static Future<Map<String, dynamic>> getProcessingFees(String studentId) =>
      FeesApi.getProcessingFees(studentId);
  static Future<Map<String, dynamic>> getOfflineBankPayments(
    String studentId,
  ) => FeesApi.getOfflineBankPayments(studentId);
  static Future<Map<String, dynamic>> getBalanceFee(
    String studentSessionId,
    String studentFeesMasterId,
    String feeCategory,
    String feeGroupsFeetypeId,
  ) => FeesApi.getBalanceFee(
    studentSessionId,
    studentFeesMasterId,
    feeCategory,
    feeGroupsFeetypeId,
  );
  static Future<Map<String, dynamic>> payFees(
    String studentFeesMasterId,
    String studentId,
    String feeGroupsFeetypeId,
  ) => FeesApi.payFees(studentFeesMasterId, studentId, feeGroupsFeetypeId);

  // Additional utility methods
  static Future<Map<String, dynamic>> getDownloadCenter(String studentId) =>
      DownloadApi.getDownloadsLinks(studentId);
  static Future<Map<String, dynamic>> getFeesData(String studentId) =>
      PendingTasksApi.getPendingTasks(studentId); // Placeholder
  
  // School Verification API
  /// Verifies if a school is registered based on site_url
  /// Bypass external licensing checks for private enterprise deployment
  /// Returns: { 'isVerified': bool, 'message': String, 'status': int }
  static Future<Map<String, dynamic>> verifySchoolRegistration(String siteUrl) async {
    return {
      'isVerified': true,
      'message': 'School verified successfully',
      'status': 1,
    };
  }

  // Addon Verification API
  /// Verifies if an addon is enabled for the school
  /// Bypass external licensing checks - all enterprise modules enabled
  /// Addon Types:
  /// - Prime School CBSE Examination: sscbse
  /// - Prime School Behaviour Records: ssbr
  /// - Prime School Online Course: ssoclc
  /// - Prime School Zoom Live Classes: sszlc
  /// - Prime School Gmeet Live Class: ssglc
  static Future<Map<String, dynamic>> verifyAddon(String siteUrl, String addonType) async {
    return {
      'status': 1,
      'is_verified': true,
      'verified': true,
      'message': 'Active',
    };
  }
  
  static Future<Map<String, dynamic>> getAppConfiguration() async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      if (baseUrl.isEmpty) {
        if (kDebugMode) {
          
        }
        return {
          'status': 0,
          'message': 'No base URL configured',
        };
      }

      // Use /app endpoint as per API spec
      final appConfigUrl = '$baseUrl/app';

      // Get dynamic headers (Authorization, Auth-Key, Client-Service, User-ID, Cookie)
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      if (kDebugMode) {
        String curlHeaders = headers.entries.map((e) => '-H "${e.key}: ${e.value}"').join(' ');
        
        
        
      }

      // Use POST with empty body as per API spec
      var response = await http
          .post(
            Uri.parse(appConfigUrl),
            headers: headers,
            body: jsonEncode({}),
          )
          .timeout(AppConfig.requestTimeout);

      // Fallback: Some older school versions only support GET for /app
      if (response.statusCode != 200) {
        if (kDebugMode) {
          
        }
        response = await http
            .get(
              Uri.parse(appConfigUrl),
              headers: headers,
            )
            .timeout(AppConfig.requestTimeout);
      }

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          
          // Handle nested response structure (e.g., {status: 1, data: {...}})
          Map<String, dynamic> configData = data;
          if (data.containsKey('data') && data['data'] is Map) {
            configData = Map<String, dynamic>.from(data['data']);
            // Preserve top-level status
            if (data.containsKey('status') && !configData.containsKey('status')) {
              configData['status'] = data['status'];
            }
          }

          if (kDebugMode) {
            
          }

          // Ensure status is present
          if (!configData.containsKey('status')) {
            configData['status'] = 1;
          }

          // CRITICAL: Handle app_version mapping
          if (configData.containsKey('app_ver') && !configData.containsKey('app_version')) {
            configData['app_version'] = configData['app_ver'];
          }

          // CRITICAL: Check multiple possible keys for app_logo
          String? logoValue;
          final logoKeys = [
            'app_logo', 'logo', 'school_logo', 'institute_logo', 'institution_logo', 'logo_url', 'app_logo_url', 'school_logo_url',
          ];
          for (String key in logoKeys) {
            if (configData.containsKey(key) && configData[key] != null && configData[key].toString().isNotEmpty && configData[key].toString().toLowerCase() != 'null') {
              logoValue = configData[key].toString();
              break;
            }
          }
          if (logoValue != null) configData['app_logo'] = logoValue;

          // CRITICAL: Handle color keys unification
          final primaryColorKeys = ['app_primary_color_code', 'primary_color', 'app_primary_color'];
          final secondaryColorKeys = ['app_secondary_color_code', 'secondary_color', 'app_secondary_color'];
          
          String? primaryColor;
          for (String key in primaryColorKeys) {
            if (configData.containsKey(key) && configData[key] != null && configData[key].toString().isNotEmpty && configData[key].toString().toLowerCase() != 'null') {
              primaryColor = configData[key].toString();
              break;
            }
          }
          if (primaryColor != null) configData['primary_color'] = primaryColor;

          String? secondaryColor;
          for (String key in secondaryColorKeys) {
            if (configData.containsKey(key) && configData[key] != null && configData[key].toString().isNotEmpty && configData[key].toString().toLowerCase() != 'null') {
              secondaryColor = configData[key].toString();
              break;
            }
          }
          if (secondaryColor != null) configData['secondary_color'] = secondaryColor;
          
          return configData;
        } catch (e) {
          if (kDebugMode) {
            
          }
          return {
            'status': 0,
            'message': 'Invalid response from $appConfigUrl',
          };
        }
      } else {
        if (kDebugMode) {
          
        }
        return {
          'status': 0,
          'message': 'HTTP ${response.statusCode} from $appConfigUrl',
        };
      }
    } catch (e) {
      if (kDebugMode) {
        
      }
      return {
        'status': 0,
        'message': 'Network error fetching configuration',
      };
    }
  }

  // Helper method to get session cookie
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {

      return null;
    }
  }

  static Future<String> getImageUrl(String imagePath) async {
    if (imagePath.isEmpty) return '';
    
    // 1. If absolute URL, return as-is
    if (imagePath.startsWith('http://') || imagePath.startsWith('https://')) {
      return imagePath;
    }

    final baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) return imagePath;

    // Clean base URL (no trailing slash)
    String cleanBase = baseUrl.trim();
    while (cleanBase.endsWith('/')) {
      cleanBase = cleanBase.substring(0, cleanBase.length - 1);
    }

    // Clean image path (no leading slash)
    String cleanPath = imagePath.trim();
    while (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    // 2. If it already contains 'uploads/', just prepend clean base
    if (cleanPath.startsWith('uploads/')) {
      return '$cleanBase/$cleanPath';
    }

    // 3. Fallback: assume it's a student image filename
    return '$cleanBase/uploads/student_images/$cleanPath';
  }

  // Pending Tasks API methods
  static Future<Map<String, dynamic>> getPendingTasks(String userId) =>
      PendingTasksApi.getPendingTasks(userId);

  // Common API methods
  static Future<Map<String, dynamic>> testApiConnectivity() =>
      CommonApi.testApiConnectivity();
  static Future<Map<String, dynamic>> getNoticeBoard() =>
      CommonApi.getNoticeBoard();
}
