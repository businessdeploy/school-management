import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../../config/app_config.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../utils/response_validator.dart';

class OnlineExamApi {
  // Get online exam list - Updated to match exact API specification
  static Future<Map<String, dynamic>> getOnlineExam(String studentId, {String examType = ' '}) async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('getOnlineExam'));
      
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'No base URL configured',
          'onlineexam': [],
        };
      }

      if (studentId.isEmpty) {
        return {
          'status': 0,
          'message': 'Student ID is required',
          'onlineexam': [],
        };
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'student_id': studentId,
        'exam_type': examType,
      }); // Match exact API spec: {"student_id":"1","exam_type":"closed"} or {"student_id":"1","exam_type":" "}

      final response = await http.post(url, headers: headers, body: body);
      

      if (response.statusCode == 200) {
        // Parse the response directly since it's already in the correct format
        final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
        
        // Check if we got valid data with onlineexam key
        if (data['onlineexam'] != null && data['onlineexam'] is List) {
          final examList = data['onlineexam'] as List;
          return {
            'status': 1,
            'message': 'Success',
            'onlineexam': data['onlineexam'],
          };
        } else {
          return {
            'status': 0,
            'message': 'No exams found',
            'onlineexam': [],
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'onlineexam': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
        'onlineexam': [],
      };
    }
  }

  // Get online exam questions - Updated to match exact API specification
  static Future<Map<String, dynamic>> getOnlineExamQuestion(
    String studentId, 
    String onlineExamId, {
    bool isCourse = false,
  }) async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      
      // If no base URL is configured, return empty data
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'No base URL configured',
          'exam': {
            'questions': [],
            'remaining_duration': '00:00:00',
            'descriptive': '0',
          },
        };
      }
      
      final url = Uri.parse(await AppConfig.getApiEndpoint('getOnlineExamQuestion'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final classId = await AuthService.getClassId().catchError((_) => '');
      final sectionId = await AuthService.getSectionId().catchError((_) => '');

      final Map<String, dynamic> bodyMap = {
        'student_id': studentId,
        'online_exam_id': onlineExamId,
        'class_id': classId,
        'section_id': sectionId,
      };

      final body = jsonEncode(bodyMap);

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
        
        // Include debug info for on-screen display
        if (data is Map<String, dynamic>) {
          data['debug_curl'] = "curl -X POST \"$url\" -d '$body'";
          data['debug_raw_body'] = response.body;
          
          // Normalize status if missing but data is present
          if (data['status'] == null) {
            final examData = data['exam'] ?? data['result'];
            if (examData != null && examData['questions'] != null && (examData['questions'] as List).isNotEmpty) {
              data['status'] = 1;
            }
          }
        }
        
        return data;
      } else {
        
        
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'debug_curl': "curl -X POST \"$url\" -d '$body'",
          'debug_raw_body': response.body,
          'exam': {
            'questions': [],
            'remaining_duration': '00:00:00',
            'descriptive': '0',
          },
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
        'debug_curl': 'Internal Error',
        'debug_raw_body': 'N/A',
        'exam': {
          'questions': [],
          'remaining_duration': '00:00:00',
          'descriptive': '0',
        },
      };
    }
  }



  // Save online exam answers with attachments (Multipart)
  static Future<Map<String, dynamic>> saveOnlineExamWithAttachments({
    required String onlineexamStudentId,
    required List<Map<String, dynamic>> rows,
    required Map<String, String?> attachments,
  }) async {
    try {
      final url = Uri.parse(await AppConfig.getApiEndpoint('saveOnlineExam'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final classId = await AuthService.getClassId().catchError((_) => '');
      final sectionId = await AuthService.getSectionId().catchError((_) => '');
      final studentId = await AuthService.getStudentId();

      final request = http.MultipartRequest('POST', url);
      
      // Add headers (excluding Content-Type)
      headers.forEach((key, value) {
        if (key != 'Content-Type') {
          request.headers[key] = value;
        }
      });

      // Add basic fields
      request.fields['onlineexam_student_id'] = onlineexamStudentId;
      request.fields['student_id'] = studentId;
      request.fields['class_id'] = classId;
      request.fields['section_id'] = sectionId;
      
      // The API expects "rows" as a JSON string for multipart
      request.fields['rows'] = jsonEncode(rows);

      // Add attachments
      // The field name for attachments usually follows a pattern like attachment_<question_id>
      // based on typical Smart School implementations
      for (final entry in attachments.entries) {
        final String questionId = entry.key;
        final String? filePath = entry.value;
        
        if (filePath != null && filePath.isNotEmpty) {
          final file = File(filePath);
          if (await file.exists()) {
             request.files.add(
               await http.MultipartFile.fromPath(
                 'attachment_$questionId', 
                 filePath,
               )
             );
             
          }
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(responseBody);
          return jsonDecode(cleanedBody);
        } catch (e) {
          return {
            'status': 0,
            'message': 'Server returned invalid JSON. Raw response: $responseBody',
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to save online exam: ${streamedResponse.statusCode}. Server response: $responseBody',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error saving online exam: $e',
      };
    }
  }

  // Save online exam answers - Updated to match exact API specification
  static Future<Map<String, dynamic>> saveOnlineExam(
    String onlineexamStudentId,
    List<Map<String, dynamic>> rows,
  ) async {
    try {
      final url = Uri.parse(await AppConfig.getApiEndpoint('saveOnlineExam'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final classId = await AuthService.getClassId().catchError((_) => '');
      final sectionId = await AuthService.getSectionId().catchError((_) => '');
      final studentId = await AuthService.getStudentId();

      final body = jsonEncode({
        'onlineexam_student_id': onlineexamStudentId,
        'student_id': studentId,
        'class_id': classId,
        'section_id': sectionId,
        'rows': rows,
      }); // Match exact API spec: {"onlineexam_student_id":"10977","student_id":"1","class_id":"1","section_id":"1","rows":[{"onlineexam_student_id":"10977","question_type":"singlechoice","onlineexam_question_id":"2866","select_option":"opt_b"}]}

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        try {
          final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
          return data;
        } catch (e) {
          return {
            'status': 0,
            'message': 'Server returned invalid JSON. Raw response: ${response.body}',
          };
        }
      } else {
        
        
        return {
          'status': 0,
          'message': 'Failed to save online exam: ${response.statusCode}. Server response: ${response.body}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error saving online exam: $e',
      };
    }
  }

  // Get online exam result - Updated to match exact API specification
  static Future<Map<String, dynamic>> getOnlineExamResult(
    String onlineexamStudentId,
    String examId, {
    String? studentId,
  }) async {
    try {
      final url = Uri.parse(await AppConfig.getApiEndpoint('getOnlineExamResult'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'onlineexam_student_id': onlineexamStudentId,
        'exam_id': examId,
        if (studentId != null) 'student_id': studentId,
      }); // Match exact API spec: {"onlineexam_student_id":"10976","exam_id":"339"}

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200) {
        final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
        final data = jsonDecode(cleanedBody);
        
        // Robust key check: result, exam, or data
        final resultData = data['result'] ?? data['exam'] ?? data['data'];
        
        // If 'result' key exists, treat it as success even if status is missing
        final int status = (data['status'] != null) 
            ? int.tryParse(data['status'].toString()) ?? 0 
            : (resultData != null ? 1 : 0);

        return {
          'status': status,
          'message': data['message'] ?? (resultData != null ? 'Success' : 'No result found'),
          'result': resultData,
          'data': resultData,
          'full_response': data,
        };
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load online exam result: ${response.statusCode}',
          'result': null,
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading online exam result: $e',
        'result': null,
      };
    }
  }


  // Get all closed exams for a student - Alternative approach
  static Future<Map<String, dynamic>> getAllClosedExams(String studentId) async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'No base URL configured',
          'closed_exams': [],
        };
      }

      // First, get all upcoming exams to find their IDs
      final upcomingResponse = await getOnlineExam(studentId);
      final closedExams = <Map<String, dynamic>>[];

      if (upcomingResponse['status'] == 1 && upcomingResponse['onlineexam'] != null) {
        final upcomingExams = List<Map<String, dynamic>>.from(upcomingResponse['onlineexam']);

        for (var exam in upcomingExams) {
          final examId = exam['id']?.toString();
          final onlineexamStudentId = exam['onlineexam_student_id']?.toString();
          final isAttempted = exam['is_attempted']?.toString() == '1';
          final examTo = exam['exam_to']?.toString();

          // Check if exam is past due date
          bool isPastDue = false;
          if (examTo != null) {
            try {
              final examEndDate = DateTime.parse(examTo);
              isPastDue = DateTime.now().isAfter(examEndDate);
            } catch (_) {}
          }

          if (isPastDue || isAttempted) {
            final closedExam = Map<String, dynamic>.from(exam);
            closedExam['is_closed'] = true;
            closedExam['closed_reason'] = isPastDue ? 'Exam period ended' : 'Attempted';
            closedExam['status'] = isPastDue ? 'closed' : 'attempted';
            closedExams.add(closedExam);
          }
        }
      }

      // Alternative: Try to get results for specific exam IDs that might exist
      if (closedExams.isEmpty) {
        try {
          final url = Uri.parse(await AppConfig.getApiEndpoint('getOnlineExamResult'));
          final headers = await DynamicApiHeaders.getCompleteHeaders();
          final cookie = await _getSessionCookie();
          if (cookie != null && cookie.isNotEmpty) {
            headers['Cookie'] = cookie;
          }

          if (upcomingResponse['status'] == 1 && upcomingResponse['onlineexam'] != null) {
            final upcomingExams = List<Map<String, dynamic>>.from(upcomingResponse['onlineexam']);

            for (var exam in upcomingExams) {
              final examId = exam['id']?.toString();
              final onlineexamStudentId = exam['onlineexam_student_id']?.toString();

              if (examId != null && onlineexamStudentId != null) {
                try {
                  final body = jsonEncode({
                    'onlineexam_student_id': onlineexamStudentId,
                    'exam_id': examId,
                  });

                  final response = await http.post(url, headers: headers, body: body);

                  if (response.statusCode == 200) {
                    final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
                    final data = jsonDecode(cleanedBody);

                    if (data['status'] == 1 && data['result'] != null) {
                      final closedExam = Map<String, dynamic>.from(exam);
                      closedExam['is_closed'] = true;
                      closedExam['closed_reason'] = 'Has results';
                      closedExam['result_data'] = data['result'];
                      closedExam['status'] = 'completed';
                      closedExams.add(closedExam);
                    }
                  }
                } catch (e) {
                  
                }
              }
            }
          }
        } catch (e) {
          
        }
      }

      return {
        'status': 1,
        'message': 'Success',
        'closed_exams': closedExams,
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
        'closed_exams': [],
      };
    }
  }

  // Alternative method to get closed exams by checking exam status
  static Future<Map<String, dynamic>> getClosedExamsByStatus(String studentId) async {
    try {
      
      // Get all upcoming exams first
      final upcomingResponse = await getOnlineExam(studentId);
      final closedExams = <Map<String, dynamic>>[];
      
      if (upcomingResponse['status'] == 1 && upcomingResponse['onlineexam'] != null) {
        final upcomingExams = List<Map<String, dynamic>>.from(upcomingResponse['onlineexam']);
        
        for (var exam in upcomingExams) {
          final examTo = exam['exam_to']?.toString();
          final examFrom = exam['exam_from']?.toString();
          final isAttempted = exam['is_attempted']?.toString() == '1';
          final counter = int.tryParse(exam['counter']?.toString() ?? '0') ?? 0;
          final attempt = int.tryParse(exam['attempt']?.toString() ?? '0') ?? 0;
          final isActive = exam['is_active']?.toString() == '1';
          
          // Check if exam is currently open/active
          bool isCurrentlyOpen = false;
          final now = DateTime.now();
          
          // Check if exam is currently in its time window
          if (examFrom != null && examTo != null) {
            try {
              final examStartDate = DateTime.parse(examFrom);
              final examEndDate = DateTime.parse(examTo);
              
              if (now.isAfter(examStartDate) && now.isBefore(examEndDate) && isActive) {
                isCurrentlyOpen = true;
              }
            } catch (e) {
              
            }
          }
          
          // If exam is NOT currently open, add it to closed exams
          if (!isCurrentlyOpen) {
            String closedReason = '';
            
            // Determine the reason why it's closed
            if (examTo != null) {
              try {
                final examEndDate = DateTime.parse(examTo);
                if (now.isAfter(examEndDate)) {
                  closedReason = 'Exam period ended';
                } else if (examFrom != null) {
                  final examStartDate = DateTime.parse(examFrom);
                  if (now.isBefore(examStartDate)) {
                    closedReason = 'Exam not started yet';
                  }
                }
              } catch (e) {
                
              }
            }
            
            if (isAttempted) {
              closedReason = 'Exam was attempted';
            } else if (counter >= attempt && attempt > 0) {
              closedReason = 'Maximum attempts reached';
            } else if (!isActive) {
              closedReason = 'Exam is inactive';
            } else if (closedReason.isEmpty) {
              closedReason = 'Exam not currently available';
            }
            
            final closedExam = Map<String, dynamic>.from(exam);
            closedExam['is_closed'] = true;
            closedExam['closed_reason'] = closedReason;
            closedExam['status'] = 'closed';
            closedExam['is_currently_open'] = false;
            closedExams.add(closedExam);
          }
        }
      }
      
      
      return {
        'status': 1,
        'message': 'Success',
        'closed_exams': closedExams,
      };
      
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
        'closed_exams': [],
      };
    }
  }

  // Get all available exams (both open and closed) for better closed exam detection
  static Future<Map<String, dynamic>> getAllAvailableExams(String studentId) async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'No base URL configured',
          'all_exams': [],
        };
      }
      
      // Try different exam types to get all available exams
      final examTypes = [' ', 'quiz', 'exam', 'test', 'assessment'];
      final allExams = <Map<String, dynamic>>[];
      
      for (final examType in examTypes) {
        try {
          final url = Uri.parse(await AppConfig.getApiEndpoint('getOnlineExam'));
          final headers = await DynamicApiHeaders.getCompleteHeaders();
          
          final cookie = await _getSessionCookie();
          if (cookie != null && cookie.isNotEmpty) {
            headers['Cookie'] = cookie;
          }

          final body = jsonEncode({
            'student_id': studentId,
            'exam_type': examType,
          });

          final response = await http.post(url, headers: headers, body: body);

          if (response.statusCode == 200) {
            final cleanedBody = ResponseValidator.cleanJsonResponse(response.body);
            final data = jsonDecode(cleanedBody);
            if (data['status'] == 1 && data['onlineexam'] != null) {
              final exams = List<Map<String, dynamic>>.from(data['onlineexam']);
              allExams.addAll(exams);
            }
          }
        } catch (e) {
          
        }
      }
      
      // Remove duplicates based on exam ID
      final uniqueExams = <String, Map<String, dynamic>>{};
      for (var exam in allExams) {
        final examId = exam['id']?.toString();
        if (examId != null && !uniqueExams.containsKey(examId)) {
          uniqueExams[examId] = exam;
        }
      }
      
      final finalExams = uniqueExams.values.toList();
      
      return {
        'status': 1,
        'message': 'Success',
        'all_exams': finalExams,
      };
      
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
        'all_exams': [],
      };
    }
  }

  // Get session cookie from SharedPreferences
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
}
