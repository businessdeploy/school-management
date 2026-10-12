import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../utils/response_validator.dart';
import '../../config/app_config.dart';

class ExaminationApi {
  // Get exam list
  static Future<Map<String, dynamic>> getExamList(String studentId) async {
    try {
      // Validate student ID
      if (studentId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Student ID is required',
          'data': [],
        };
      }
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // Validate base URL
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'Base URL is not configured. Please set it in settings.',
          'data': [],
        };
      }
      
      // Use Smart School API specification
      final endpoint = await AppConfig.getApiEndpoint('getExamList');
      
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use correct parameter name as per Smart School API spec (student_id with underscore)
      final requestBody = jsonEncode({'student_id': studentId});

      try {
        final url = Uri.parse(endpoint);
        final response = await http.post(url, headers: headers, body: requestBody);

        // Check if response is HTML (error page)
        if (ResponseValidator.isHtmlResponse(response.body)) {
          
          return {
            'status': 0,
            'message': 'API returned error page. Please try again later.',
            'data': [],
          };
        }

        // Check if response is SQL query text (error response from server)
        final responseBodyUpper = response.body.trim().toUpperCase();
        if (responseBodyUpper.startsWith('SELECT') || 
            responseBodyUpper.startsWith('INSERT') || 
            responseBodyUpper.startsWith('UPDATE') || 
            responseBodyUpper.startsWith('DELETE') ||
            responseBodyUpper.startsWith('FROM') ||
            (responseBodyUpper.contains('WHERE') && responseBodyUpper.contains('FROM'))) {
          
          return {
            'status': 0,
            'message': 'Server error. Please try again later.',
            'data': [],
          };
        }

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          
          // Check if response contains examSchedule as per API spec
          if (responseData is Map && responseData.containsKey('examSchedule')) {
            final examSchedule = responseData['examSchedule'] as List<dynamic>?;
            
            return {
              'status': 1,
              'message': 'Exam list loaded successfully',
              'data': examSchedule ?? [],
              'examSchedule': examSchedule ?? [], // Preserve original key
            };
          } else if (responseData is List) {
            // Handle direct array response
            return {
              'status': 1,
              'message': 'Exam list loaded successfully',
              'data': responseData,
              'examSchedule': responseData, // Map to expected key
            };
          } else {
            return {
              'status': 0,
              'message': 'No exam schedule found in response',
              'data': [],
            };
          }
        } else {
          
          return {
            'status': 0,
            'message': 'HTTP error ${response.statusCode}',
            'data': [],
          };
        }
      } catch (e) {
        
        return {
          'status': 0,
          'message': 'Error calling Prime School API: $e',
          'data': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading exam list: $e',
        'data': [],
      };
    }
  }

  // Get exam schedule
  // API: https://demo.smart-school.in/api/webservice/getExamSchedule
  // Body: {"exam_group_class_batch_exam_id":"172"} (dynamic)
  // Headers: Authorization, Auth-Key, Client-Service, Content-Type, User-ID, Cookie (all dynamic)
  static Future<Map<String, dynamic>> getExamSchedule(
    String examGroupClassBatchExamId,
  ) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'Base URL is not configured. Please set it in settings.',
          'data': [],
        };
      }
      
      final endpoint = await AppConfig.getApiEndpoint('getExamSchedule');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use exact body format as per API spec: {"exam_group_class_batch_exam_id":"<dynamic>"}
      final requestBody = jsonEncode({'exam_group_class_batch_exam_id': examGroupClassBatchExamId});

          try {
            final url = Uri.parse(endpoint);
        final response = await http.post(url, headers: headers, body: requestBody);

            // Check if response is HTML (error page)
            if (ResponseValidator.isHtmlResponse(response.body)) {
              
              return {
                'status': 0,
                'message': 'API returned error page. Please try again later.',
                'data': [],
              };
            }

            // Check if response is SQL query text (error response from server)
            final responseBodyUpper = response.body.trim().toUpperCase();
            if (responseBodyUpper.startsWith('SELECT') || 
                responseBodyUpper.startsWith('INSERT') || 
                responseBodyUpper.startsWith('UPDATE') || 
                responseBodyUpper.startsWith('DELETE') ||
                responseBodyUpper.startsWith('FROM') ||
                (responseBodyUpper.contains('WHERE') && responseBodyUpper.contains('FROM'))) {
              
              return {
                'status': 0,
                'message': 'Server error. Please try again later.',
                'data': [],
              };
            }

            if (response.statusCode == 200) {
              final responseData = jsonDecode(response.body);
              
              // Check if response contains exam_subjects as per API spec
              if (responseData is Map && responseData.containsKey('exam_subjects')) {
                final examSubjects = responseData['exam_subjects'] as List<dynamic>?;
                
                return {
                  'status': 1,
                  'message': 'Exam schedule loaded successfully',
                  'data': examSubjects ?? [],
                  'exam_subjects': examSubjects ?? [], // Preserve original key
                  'full_response': responseData, // Pass full response for schedule file access
                };
              } else if (responseData is List) {
                // Handle direct array response
                return {
                  'status': 1,
                  'message': 'Exam schedule loaded successfully',
                  'data': responseData,
                  'exam_subjects': responseData, // Map to expected key
                };
              } else {
                return {
                  'status': 0,
                  'message': 'No exam subjects found in response',
                  'data': [],
                };
              }
            } else {
              
              return {
                'status': 0,
                'message': 'HTTP error ${response.statusCode}',
                'data': [],
              };
            }
          } catch (e) {
        
      return {
          'status': 0,
          'message': 'Error calling Prime School API: $e',
          'data': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading exam schedule: $e',
        'data': [],
      };
    }
  }

  // Get exam result
  // API: https://demo.smart-school.in/api/webservice/getExamResult
  // Body: {"student_id":"1", "exam_group_class_batch_exam_id":"172"} (all dynamic)
  // Headers: Authorization, Auth-Key, Client-Service, Content-Type, User-ID, Cookie (all dynamic)
  static Future<Map<String, dynamic>> getExamResult(
    String studentId,
    String examGroupClassBatchExamId,
  ) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'Base URL is not configured. Please set it in settings.',
          'data': null,
        };
      }
      
      final endpoint = await AppConfig.getApiEndpoint('getExamResult');
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use exact body format as per API spec: {"student_id":"<dynamic>", "exam_group_class_batch_exam_id":"<dynamic>"}
      final requestBody = jsonEncode({
        'student_id': studentId, // Dynamic parameter
        'exam_group_class_batch_exam_id': examGroupClassBatchExamId, // Dynamic parameter
      });

          try {
            final url = Uri.parse(endpoint);
        final response = await http.post(url, headers: headers, body: requestBody);

            // Check if response is HTML (error page)
            if (ResponseValidator.isHtmlResponse(response.body)) {
              
              return {
                'status': 0,
                'message': 'API returned error page. Please try again later.',
                'data': null,
              };
            }

            // Check if response is SQL query text (error response from server)
            final responseBodyUpper = response.body.trim().toUpperCase();
            if (responseBodyUpper.startsWith('SELECT') || 
                responseBodyUpper.startsWith('INSERT') || 
                responseBodyUpper.startsWith('UPDATE') || 
                responseBodyUpper.startsWith('DELETE') ||
                responseBodyUpper.startsWith('FROM') ||
                (responseBodyUpper.contains('WHERE') && responseBodyUpper.contains('FROM'))) {
              
              return {
                'status': 0,
                'message': 'Server error. Please try again later.',
                'data': null,
              };
            }

            if (response.statusCode == 200) {
              final responseData = jsonDecode(response.body);
              
              if (responseData is Map) {
                // Check all possible keys for the actual data
                final examData = responseData['exam'] ?? responseData['result'] ?? responseData['data'];
                
                if (examData != null) {
                  return {
                    'status': responseData['status'] ?? 1, // Use API status if available
                    'message': 'Exam result loaded successfully',
                    'data': examData,
                    'exam': examData, // Preserve original key
                    'full_response': responseData, // Pass full response for consolidated data
                  };
                }
              }
              
              return {
                'status': 0,
                'message': 'No exam result found in response',
                'data': null,
              };
            } else {
              
              return {
                'status': 0,
                'message': 'HTTP error ${response.statusCode}',
                'data': null,
              };
            }
          } catch (e) {
        
      return {
          'status': 0,
          'message': 'Error calling Prime School API: $e',
          'data': null,
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading exam result: $e',
        'data': null,
      };
    }
  }

  // CBSE Exam Result method
  static Future<List<Map<String, dynamic>>> getCBSEExamResult(String studentSessionId) async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        return [];
      }
      
      final url = await AppConfig.getApiEndpoint('cbseexamresult');
      
      // Add session cookie to headers
      final sessionCookie = await _getSessionCookie();
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = sessionCookie;
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'student_session_id': studentSessionId,
        }),
      );

      if (response.statusCode == 200) {
        String responseBody = response.body;
        // Clean up response if it contains PHP warnings/HTML
        final jsonStartIndex = responseBody.indexOf('{');
        final jsonListStartIndex = responseBody.indexOf('[');
        
        int startIndex = -1;
        if (jsonStartIndex != -1 && jsonListStartIndex != -1) {
          startIndex = jsonStartIndex < jsonListStartIndex ? jsonStartIndex : jsonListStartIndex;
        } else if (jsonStartIndex != -1) {
          startIndex = jsonStartIndex;
        } else if (jsonListStartIndex != -1) {
          startIndex = jsonListStartIndex;
        }

        if (startIndex > 0) {
          responseBody = responseBody.substring(startIndex);
        }

        final data = jsonDecode(responseBody);
        
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          // Check for different possible response structures
          if (data['data'] is List) {
            return List<Map<String, dynamic>>.from(data['data']);
          } else if (data['result'] is List) {
            return List<Map<String, dynamic>>.from(data['result']);
          } else if (data['cbse_exams'] is List) {
            return List<Map<String, dynamic>>.from(data['cbse_exams']);
          } else if (data['exams'] is List) {
            return List<Map<String, dynamic>>.from(data['exams']);
          } else {
            return [];
          }
        } else {
          return [];
        }
      } else {
        
        
        return [];
      }
    } catch (e) {
      
      return [];
    }
  }

  // CBSE Exam Timetable method
  static Future<List<Map<String, dynamic>>> getCBSEExamTimetable(String studentSessionId) async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        return [];
      }
      
      // Use 'cbseexamtimetable' as endpoint
      final url = await AppConfig.getApiEndpoint('cbseexamtimetable');
      
      // Add session cookie to headers
      final sessionCookie = await _getSessionCookie();
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = sessionCookie;
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'student_session_id': studentSessionId,
        }),
      );

      if (response.statusCode == 200) {
        String responseBody = response.body;
        // Clean up response if it contains PHP warnings/HTML
        final jsonStartIndex = responseBody.indexOf('{');
        final jsonListStartIndex = responseBody.indexOf('[');
        
        int startIndex = -1;
        if (jsonStartIndex != -1 && jsonListStartIndex != -1) {
          startIndex = jsonStartIndex < jsonListStartIndex ? jsonStartIndex : jsonListStartIndex;
        } else if (jsonStartIndex != -1) {
          startIndex = jsonStartIndex;
        } else if (jsonListStartIndex != -1) {
          startIndex = jsonListStartIndex;
        }

        if (startIndex > 0) {
          responseBody = responseBody.substring(startIndex);
        }

        final data = jsonDecode(responseBody);
        
        if (data is List) {
          return List<Map<String, dynamic>>.from(data);
        } else if (data is Map) {
          List<dynamic>? listData;
          if (data['data'] is List) {
            listData = data['data'];
          } else if (data['result'] is List) {
            listData = data['result'];
          } else if (data['cbse_exams'] is List) {
            listData = data['cbse_exams'];
          } else if (data['exams'] is List) {
            listData = data['exams'];
          } else if (data['timetables'] is List) {
            listData = data['timetables'];
          }
          
          if (listData != null) {
             return List<Map<String, dynamic>>.from(listData);
          }
          
          return [];
        } else {
          return [];
        }
      } else {
        
        
        return [];
      }
    } catch (e) {
      
      return [];
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
}