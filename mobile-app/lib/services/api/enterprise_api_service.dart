import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/dynamic_api_headers.dart';

/// Enterprise-grade API service with proper error handling, logging, and data validation
class EnterpriseApiService {
  static const String _tag = '🏢 Enterprise API';
  
  /// Generic API call method with comprehensive error handling
  static Future<ApiResponse> makeApiCall({
    required String endpoint,
    required Map<String, dynamic> body,
    String method = 'POST',
    Map<String, String>? additionalHeaders,
    bool requireAuth = true,
    int timeoutSeconds = 30,
  }) async {
    try {
      
      
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/$endpoint');
      
      // Prepare headers
      final headers = <String, String>{};
      if (requireAuth) {
        final authHeaders = await DynamicApiHeaders.getCompleteHeaders();
        headers.addAll(authHeaders);
      }
      
      // Add session cookie
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      
      // Add additional headers
      if (additionalHeaders != null) {
        headers.addAll(additionalHeaders);
      }
      
      
      
      // Make the request
      http.Response response;
      if (method.toUpperCase() == 'GET') {
        response = await http.get(url, headers: headers).timeout(
          Duration(seconds: timeoutSeconds),
        );
      } else {
        response = await http.post(url, headers: headers, body: jsonEncode(body)).timeout(
          Duration(seconds: timeoutSeconds),
        );
      }
      
      
      
      
      // Handle response
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          return ApiResponse.success(jsonData);
        } catch (e) {
          
          return ApiResponse.error('Invalid JSON response: $e');
        }
      } else {
        
        return ApiResponse.error('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      
      return ApiResponse.error('Network error: $e');
    }
  }
  
  /// School Details API
  static Future<ApiResponse> getSchoolDetails() async {
    return await makeApiCall(
      endpoint: 'getSchoolDetails',
      body: {},
    );
  }

  /// Get session cookie from SharedPreferences
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
  
  /// Download Center APIs
  static Future<ApiResponse> getDownloadsLinks(String studentId) async {
    return await makeApiCall(
      endpoint: 'getDownloadsLinks',
      body: {'student_id': studentId},
    );
  }
  
  static Future<ApiResponse> getVideoTutorial(String studentId) async {
    return await makeApiCall(
      endpoint: 'getVideoTutorial',
      body: {'student_id': studentId},
    );
  }
  
  /// Fees APIs
  static Future<ApiResponse> getFees(String studentId) async {
    return await makeApiCall(
      endpoint: 'fees',
      body: {'student_id': studentId},
    );
  }
  
  static Future<ApiResponse> getProcessingFees(String studentId) async {
    return await makeApiCall(
      endpoint: 'getProcessingfees',
      body: {'student_id': studentId},
    );
  }
  
  static Future<ApiResponse> getOfflineBankPayments(String studentId) async {
    return await makeApiCall(
      endpoint: 'getOfflineBankPayments',
      body: {'student_id': studentId},
    );
  }
  
  static Future<ApiResponse> getBalanceFee(
    String studentSessionId,
    String studentFeesMasterId,
    String feeCategory,
    String feeGroupsFeetypeId,
  ) async {
    return await makeApiCall(
      endpoint: 'getBalanceFee',
      body: {
        'student_session_id': studentSessionId,
        'student_fees_master_id': studentFeesMasterId,
        'fee_category': feeCategory,
        'fee_groups_feetype_id': feeGroupsFeetypeId,
      },
    );
  }
  
  static Future<ApiResponse> payFees(
    String studentFeesMasterId,
    String studentId,
    String feeGroupsFeetypeId,
  ) async {
    return await makeApiCall(
      endpoint: 'paymentrequest',
      body: {
        'student_fees_master_id': studentFeesMasterId,
        'student_id': studentId,
        'fee_groups_feetype_id': feeGroupsFeetypeId,
      },
    );
  }
  
  /// Online Exam APIs
  static Future<ApiResponse> getOnlineExam(String studentId, {String examType = ''}) async {
    return await makeApiCall(
      endpoint: 'getOnlineExam',
      body: {
        'student_id': studentId,
        'exam_type': examType,
      },
    );
  }
  
  static Future<ApiResponse> getOnlineExamQuestion(String studentId, String onlineExamId) async {
    return await makeApiCall(
      endpoint: 'getOnlineExamQuestion',
      body: {
        'student_id': studentId,
        'online_exam_id': onlineExamId,
      },
    );
  }
  
  static Future<ApiResponse> saveOnlineExam(
    String onlineexamStudentId,
    List<Map<String, dynamic>> rows,
  ) async {
    return await makeApiCall(
      endpoint: 'saveOnlineExam',
      body: {
        'onlineexam_student_id': onlineexamStudentId,
        'rows': rows,
      },
    );
  }
  
  static Future<ApiResponse> getOnlineExamResult(String onlineexamStudentId, String examId) async {
    return await makeApiCall(
      endpoint: 'getOnlineExamResult',
      body: {
        'onlineexam_student_id': onlineexamStudentId,
        'exam_id': examId,
      },
    );
  }
  
  /// Attendance API
  static Future<ApiResponse> getAttendance(String studentId, {String? month, String? year}) async {
    final now = DateTime.now();
    final currentMonth = month ?? now.month.toString();
    final currentYear = year ?? now.year.toString();
    final currentDate = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    
    return await makeApiCall(
      endpoint: 'getAttendenceRecords',
      body: {
        'student_id': studentId,
        'month': currentMonth,
        'year': currentYear,
        'date': currentDate,
      },
    );
  }
  
  /// Examination APIs
  static Future<ApiResponse> getExamList(String studentId) async {
    return await makeApiCall(
      endpoint: 'getExamList',
      body: {'student_Id': studentId}, // Note: capital I as per API spec
    );
  }
  
  static Future<ApiResponse> getExamSchedule(String examGroupClassBatchExamId) async {
    return await makeApiCall(
      endpoint: 'getExamSchedule',
      body: {'exam_group_class_batch_exam_id': examGroupClassBatchExamId},
    );
  }
  
  static Future<ApiResponse> getExamResult(String studentId, String examGroupClassBatchExamId) async {
    return await makeApiCall(
      endpoint: 'getExamResult',
      body: {
        'student_id': studentId,
        'exam_group_class_batch_exam_id': examGroupClassBatchExamId,
      },
    );
  }
  
  /// Behaviour Records APIs
  static Future<ApiResponse> getStudentBehaviour(String studentId) async {
    return await makeApiCall(
      endpoint: 'getstudentbehaviour',
      body: {'studentId': studentId},
    );
  }
  
  static Future<ApiResponse> getIncidentComments(String studentIncidentId) async {
    return await makeApiCall(
      endpoint: 'getincidentcomments',
      body: {'student_incident_id': studentIncidentId},
    );
  }
  
  static Future<ApiResponse> addIncidentComment(
    String studentIncidentId,
    String type,
    String comment,
    String studentId,
  ) async {
    return await makeApiCall(
      endpoint: 'addincidentcomments',
      body: {
        'student_incident_id': studentIncidentId,
        'type': type,
        'comment': comment,
        'student_id': studentId,
      },
    );
  }
  
  /// Lesson Plan APIs
  static Future<ApiResponse> getLessonPlan(String studentId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    final dateFrom = '${startOfWeek.year}-${startOfWeek.month.toString().padLeft(2, '0')}-${startOfWeek.day.toString().padLeft(2, '0')}';
    final dateTo = '${endOfWeek.year}-${endOfWeek.month.toString().padLeft(2, '0')}-${endOfWeek.day.toString().padLeft(2, '0')}';
    
    return await makeApiCall(
      endpoint: 'getlessonplan',
      body: {
        'student_id': studentId,
        'date_from': dateFrom,
        'date_to': dateTo,
      },
    );
  }
  
  static Future<ApiResponse> getSyllabusStatus(String subjectSyllabusId) async {
    return await makeApiCall(
      endpoint: 'getsyllabus',
      body: {'subject_syllabus_id': subjectSyllabusId},
    );
  }
  
  static Future<ApiResponse> getSyllabusSubjects(String studentId) async {
    return await makeApiCall(
      endpoint: 'getsyllabussubjects',
      body: {'student_Id': studentId}, // Note: capital I as per API spec
    );
  }
  
  /// Notice Board API
  static Future<ApiResponse> getNoticeBoard() async {
    return await makeApiCall(
      endpoint: 'getNotifications',
      body: {'type': 'student'},
    );
  }
  
  /// Hostel API
  static Future<ApiResponse> getHostelList(String studentId) async {
    return await makeApiCall(
      endpoint: 'getHostelList',
      body: {'student_id': studentId},
    );
  }
  
  /// Library APIs
  static Future<ApiResponse> getIssuedBooks(String studentId) async {
    return await makeApiCall(
      endpoint: 'getLibraryBookIssued',
      body: {'studentId': studentId},
    );
  }
  
  static Future<ApiResponse> getAllBooks() async {
    return await makeApiCall(
      endpoint: 'getLibraryBooks',
      body: {},
      method: 'GET',
    );
  }
  
  /// Teacher APIs
  static Future<ApiResponse> getTeachersList(String classId, String sectionId, String userId) async {
    return await makeApiCall(
      endpoint: 'getTeachersList',
      body: {
        'class_id': classId,
        'section_id': sectionId,
        'user_id': userId,
      },
    );
  }
  
  static Future<ApiResponse> getTeacherSubject(String classId, String sectionId, String staffId) async {
    return await makeApiCall(
      endpoint: 'getTeacherSubject',
      body: {
        'class_id': classId,
        'section_id': sectionId,
        'staff_id': staffId,
      },
    );
  }
  
  static Future<ApiResponse> addStaffRating(
    String rate,
    String comment,
    String role,
    String staffId,
    String userId,
  ) async {
    return await makeApiCall(
      endpoint: 'addStaffRating',
      body: {
        'rate': rate,
        'comment': comment,
        'role': role,
        'staff_id': staffId,
        'user_id': userId,
      },
    );
  }
  
  /// Timeline APIs
  static Future<ApiResponse> getTimeline(String studentId) async {
    return await makeApiCall(
      endpoint: 'getTimeline',
      body: {'studentId': studentId},
    );
  }
  
  static Future<ApiResponse> addEditTimeline({
    String? id,
    required String title,
    required String description,
    required String timelineDate,
    String? timelineDoc,
    required String studentId,
  }) async {
    // This requires form-data, so we'll handle it separately
    return await _makeFormDataCall(
      endpoint: 'addedittimeline',
      fields: {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'timeline_date': timelineDate,
        'timeline_doc': timelineDoc ?? '',
        'student_id': studentId,
      },
    );
  }
  
  static Future<ApiResponse> deleteTimeline(String timelineId) async {
    return await makeApiCall(
      endpoint: 'deletetimeline',
      body: {'id': timelineId},
    );
  }
  
  /// Transport API
  static Future<ApiResponse> getTransportRoutes(String studentId) async {
    return await makeApiCall(
      endpoint: 'gettransportroutes',
      body: {'student_id': studentId},
    );
  }
  
  /// Form-data API call for timeline
  static Future<ApiResponse> _makeFormDataCall({
    required String endpoint,
    required Map<String, String> fields,
  }) async {
    try {
      
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/$endpoint');
      
      final request = http.MultipartRequest('POST', url);
      
      // Add headers
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      request.headers.addAll(headers);
      
      // Add session cookie
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        request.headers['Cookie'] = cookie;
      }
      
      // Add fields
      request.fields.addAll(fields);
      
      
      
      final response = await request.send();
      final responseBody = await response.stream.bytesToString();
      
      
      
      
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(responseBody);
          return ApiResponse.success(jsonData);
        } catch (e) {
          return ApiResponse.error('Invalid JSON response: $e');
        }
      } else {
        return ApiResponse.error('HTTP ${response.statusCode}: $responseBody');
      }
    } catch (e) {
      
      return ApiResponse.error('Form-data error: $e');
    }
  }
}

/// Standardized API response class
class ApiResponse {
  final bool success;
  final dynamic data;
  final String? error;
  final int? statusCode;
  
  ApiResponse._({
    required this.success,
    this.data,
    this.error,
    this.statusCode,
  });
  
  factory ApiResponse.success(dynamic data, {int? statusCode}) {
    return ApiResponse._(
      success: true,
      data: data,
      statusCode: statusCode,
    );
  }
  
  factory ApiResponse.error(String error, {int? statusCode}) {
    return ApiResponse._(
      success: false,
      error: error,
      statusCode: statusCode,
    );
  }
  
  /// Get data with fallback
  T getData<T>(String key, {T? fallback}) {
    if (!success || data == null) return fallback ?? (T is List ? [] as T : {} as T);
    
    if (data is Map<String, dynamic>) {
      return data[key] ?? fallback ?? (T is List ? [] as T : {} as T);
    }
    
    return fallback ?? (T is List ? [] as T : {} as T);
  }
  
  /// Get list data with fallback
  List<T> getListData<T>(String key) {
    if (!success || data == null) return [];
    
    if (data is Map<String, dynamic> && data[key] is List) {
      return List<T>.from(data[key]);
    }
    
    return [];
  }
  
  /// Check if response has specific key
  bool hasKey(String key) {
    if (!success || data == null) return false;
    if (data is Map<String, dynamic>) {
      return data.containsKey(key);
    }
    return false;
  }
}
