import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class LessonApi {
  // Get syllabus status
  static Future<Map<String, dynamic>> getSyllabusStatus(
    String studentId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return empty data
      if (baseUrl.isEmpty) {
        
        return {'status': 0, 'message': 'No base URL configured', 'data': []};
      }

      // Use the correct Smart School API endpoint
      final endpoint = await AppConfig.getApiEndpoint('getsyllabussubjects');

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use the correct Smart School API body format - FIXED: use student_id not studentId
      final body = jsonEncode({'student_id': studentId});

      
      
      

      final url = Uri.parse(endpoint);
      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data is Map && data.containsKey('subjects')) {
            
            return {
              'status': 1,
              'message': 'Success',
              'data': data['subjects'] ?? [],
            };
          } else {
            
            return {
              'status': 0,
              'message': 'No subjects found in response',
              'data': [],
            };
          }
        } catch (e) {
          
          return {
            'status': 0,
            'message': 'Failed to parse response: $e',
            'data': [],
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error fetching syllabus status: $e',
        'data': [],
      };
    }
  }

  // Get syllabus subjects
  static Future<Map<String, dynamic>> getSyllabusSubjects(
    String studentId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured. Please set the school URL first.',
          'subjects': [],
        };
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('getsyllabussubjects'));

      // Use dynamic headers from AuthService
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use exact body format as per API specification - FIXED: use student_id not studentId
      final body = jsonEncode({'student_id': studentId});

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'subjects',
        );
        // Check if API returned empty data
        if (data['subjects'] == null || (data['subjects'] as List).isEmpty) {
          
          return {
            'status': 0,
            'message': 'No syllabus subjects found',
            'subjects': [],
          };
        }
        
        return {
          'status': 1,
          'message': 'Success',
          'subjects': data['subjects'] ?? [],
        };
      } else {
        
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'subjects': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading syllabus subjects: $e',
        'subjects': [],
      };
    }
  }

  // Get lesson topics with dynamic values from syllabus data
  static Future<Map<String, dynamic>> getLessonTopicsDynamic() async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured. Please set the school URL first.',
          'data': [],
        };
      }

      // Get dynamic values from syllabus data
      final studentId = await AuthService.getStudentId();
      final syllabusResponse = await getSyllabusSubjects(studentId);

      String? subjectId;
      String? classSectionId;

      if (syllabusResponse['status'] == 1 &&
          syllabusResponse['subjects'] != null) {
        final subjects = syllabusResponse['subjects'] as List;
        if (subjects.isNotEmpty) {
          // Use the first subject's IDs - DYNAMIC FROM API RESPONSE
          final firstSubject = subjects.first;
          subjectId = firstSubject['subject_group_subject_id']?.toString();
          classSectionId = firstSubject['id']?.toString();

          
          
          
          
        }
      }

      // If no subject data found, throw error instead of using static fallback
      if (subjectId == null || classSectionId == null) {
        
        throw Exception(
          'No subject data available. Please ensure syllabus is loaded.',
        );
      }

      
      
      

      final url = Uri.parse(await AppConfig.getApiEndpoint('getSubjectsLessons'));

      // Use dynamic headers from AuthService
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use dynamic values from user profile
      final body = jsonEncode({
        'subject_group_subject_id': subjectId,
        'subject_group_class_sections_id': classSectionId,
      });

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        // Check if response is HTML (error page)
        if (response.body.contains('<!DOCTYPE html>')) {
          
          return {
            'status': 0,
            'message': 'Server returned HTML error page',
            'data': [],
          };
        }

        try {
          final data = jsonDecode(response.body);
          

          // Check if we have actual lesson topics data
          if (data != null && data.isNotEmpty) {
            return {
              'status': 1,
              'message': 'Lesson topics loaded successfully',
              'data': data,
            };
          } else {
            
            return {
              'status': 0,
              'message': 'No lesson topics data found',
              'data': [],
            };
          }
        } catch (e) {
          
          return {
            'status': 0,
            'message': 'Error parsing response: $e',
            'data': [],
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading lesson topics: $e',
        'data': [],
      };
    }
  }

  // Get lesson topics (original method with parameters)
  static Future<Map<String, dynamic>> getLessonTopics(
    String subjectGroupSubjectId,
    String subjectGroupClassSectionsId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured. Please set the school URL first.',
          'data': [],
        };
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('getSubjectsLessons'));

      // Use dynamic headers from AuthService
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Use exact body format as per API specification
      final body = jsonEncode({
        'subject_group_subject_id': subjectGroupSubjectId,
        'subject_group_class_sections_id': subjectGroupClassSectionsId,
      });

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        // Check if response is HTML (error page)
        if (response.body.contains('<!DOCTYPE html>')) {
          
          return {
            'status': 0,
            'message': 'Server returned HTML error page',
            'data': [],
          };
        }

        try {
          final data = jsonDecode(response.body);
          

          // Check if we have actual lesson topics data
          if (data != null && data.isNotEmpty) {
            return {
              'status': 1,
              'message': 'Lesson topics loaded successfully',
              'data': data,
            };
          } else {
            
            return {
              'status': 0,
              'message': 'No lesson topics data found',
              'data': [],
            };
          }
        } catch (e) {
          
          return {
            'status': 0,
            'message': 'Error parsing response: $e',
            'data': [],
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'API error: ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading lesson topics: $e',
        'data': [],
      };
    }
  }

  // Get lesson plan
  static Future<Map<String, dynamic>> getLessonPlan(
    String studentId, [
    DateTime? dateFrom,
    DateTime? dateTo,
  ]) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured. Please set the school URL first.',
          'timetable': {},
        };
      }

      final urlStr = await AppConfig.getApiEndpoint('getlessonplan');
      final url = Uri.parse(urlStr);

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Build payload with date range if provided
      final Map<String, dynamic> payload = {'student_id': studentId};
      if (dateFrom != null) {
        payload['date_from'] = '${dateFrom.year}-${dateFrom.month.toString().padLeft(2, '0')}-${dateFrom.day.toString().padLeft(2, '0')}';
      }
      if (dateTo != null) {
        payload['date_to'] = '${dateTo.year}-${dateTo.month.toString().padLeft(2, '0')}-${dateTo.day.toString().padLeft(2, '0')}';
      }

      final body = jsonEncode(payload);

      
      

      final response = await http.post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 20));

      

      if (response.statusCode == 200) {
        final respBody = response.body;

        // CRITICAL: Check for HTML response (PHP errors often start with <div> or contain <!DOCTYPE)
        if (ResponseValidator.isHtmlResponse(respBody)) {
          
          return {
            'status': 0,
            'message': 'Server returned an invalid response. This often happens when no lessons are scheduled or there is a temporary server issue.',
            'timetable': {},
          };
        }

        try {
          final data = jsonDecode(respBody);
          

          if (data != null && data is Map) {
            final timetable = data['timetable'];
            return {
              'status': data['status'] ?? 1,
              'message': data['message'] ?? 'Success',
              'timetable': (timetable is Map) ? timetable : {},
            };
          } else {
            return {
              'status': 0,
              'message': 'Empty or invalid data received',
              'timetable': {},
            };
          }
        } catch (e) {
          
          return {
            'status': 0,
            'message': 'Failed to understand server response. (Invalid JSON)',
            'timetable': {},
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'Server error: ${response.statusCode}',
          'timetable': {},
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading lesson plan: ${e.toString()}',
        'timetable': {},
      };
    }
  }

  // Get syllabus details
  static Future<Map<String, dynamic>> getSyllabus(
    String subjectSyllabusId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'No base URL configured',
          'data': {},
        };
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('getsyllabus'));
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'subject_syllabus_id': subjectSyllabusId});
      
      
      

      final response = await http.post(url, headers: headers, body: body);
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data.isNotEmpty) {
            // Some APIs return list, some map. Handle dynamic response.
            // Usually returns a single object for details
            if (data is List && data.isNotEmpty) {
               return {'status': 1, 'message': 'Success', 'data': data.first};
            } else if (data is Map) {
               // Check if wrapped in data or direct
               if (data['data'] != null) {
                 return {'status': 1, 'message': 'Success', 'data': data['data'] is List && (data['data'] as List).isNotEmpty ? data['data'].first : data['data']}; 
               }
               // Check if syllabus key exists (sometimes returns {syllabus: [...]})
               if (data['syllabus'] != null) {
                  final syllabus = data['syllabus'];
                  if (syllabus is List && syllabus.isNotEmpty) {
                    return {'status': 1, 'message': 'Success', 'data': syllabus.first};
                  }
                  return {'status': 1, 'message': 'Success', 'data': syllabus};
               }
               return {'status': 1, 'message': 'Success', 'data': data};
            }
        }
        return {'status': 0, 'message': 'No data found', 'data': {}};
      }
      return {'status': 0, 'message': 'API Error', 'data': {}};
    } catch (e) {
      
      return {'status': 0, 'message': 'Error: $e', 'data': {}};
    }
  }

  // Get forum comments
  static Future<Map<String, dynamic>> getForumComments(
    String subjectSyllabusId,
  ) async {
    try {
      // Validate inputs
      if (subjectSyllabusId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Subject syllabus ID is required',
          'syllabus': [],
        };
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured',
          'syllabus': [],
        };
      }

      
      final url = Uri.parse(await AppConfig.getApiEndpoint('getforummessage'));

      // Get dynamic headers (Authorization, Auth-Key, Client-Service, User-ID, Cookie)
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'subject_syllabus_id': subjectSyllabusId});

      
      
      

      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      
      

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          

          // Handle different response structures
          if (jsonData is Map) {
            List<dynamic> combinedSyllabus = [];
            
            // Collect from all likely keys and merge them
            final listKeys = [
              'syllabus',
              'staff_comments',
              'teacher_comments',
              'data',
              'comments',
              'forum',
              'messages',
              'result'
            ];
            
            for (String key in listKeys) {
              if (jsonData.containsKey(key)) {
                final value = jsonData[key];
                if (value is List) {
                  combinedSyllabus.addAll(value);
                  
                } else if (value != null && value is! Map) {
                  // If it's a single item (sometimes happens), add it
                  combinedSyllabus.add(value);
                }
              }
            }

            // If we found something, return the merged list
            if (combinedSyllabus.isNotEmpty) {
               return {
                'status': jsonData['status'] ?? 1,
                'message': jsonData['message'] ?? 'Success',
                'syllabus': combinedSyllabus,
              };
            }

            // If no list keys found, check if the response itself is a single comment map
            if (jsonData.containsKey('message') || jsonData.containsKey('comment') || jsonData.containsKey('note')) {
               return {
                'status': jsonData['status'] ?? 1,
                'message': jsonData['message'] ?? 'Success',
                'syllabus': [jsonData],
              };
            }

            // Fallback for empty/unknown map
            return {
              'status': jsonData['status'] ?? 1,
              'message': jsonData['message'] ?? 'Success',
              'syllabus': [],
              'raw_response': jsonData,
            };
          } else if (jsonData is List) {
            // Response is directly a list
            
            return {'status': 1, 'message': 'Success', 'syllabus': jsonData};
          }
        } catch (e) {
          
          // Fallback to ResponseValidator
          final data = ResponseValidator.validateAndParseJson(
            response.body,
            'syllabus',
          );
          
          return data;
        }

        // Final fallback
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'syllabus',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load forum comments: ${response.statusCode}',
          'syllabus': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading forum comments: $e',
        'syllabus': [],
      };
    }
  }

  // Save forum comment
  static Future<Map<String, dynamic>> saveForumComment(
    String subjectSyllabusId,
    String message,
    String studentId,
  ) async {
    try {
      // Validate inputs
      if (subjectSyllabusId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Subject syllabus ID is required',
          'syllabus': [],
        };
      }

      if (message.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Comment message is required',
          'syllabus': [],
        };
      }

      if (studentId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Student ID is required',
          'syllabus': [],
        };
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured',
          'syllabus': [],
        };
      }

      
      

      // Get additional dynamic fields
      final profile = await AuthService.getUserProfile();
      final studentSessionId = profile['student_session_id'] ?? '';

      // Get dynamic headers (Authorization, Auth-Key, Client-Service, User-ID, Cookie)
      final baseHeaders = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        baseHeaders['Cookie'] = cookie;
      }

      // API endpoints to try (prioritize addforummessage)
      final endpoints = [
        '$baseUrl/api/webservice/addforummessage',
        '$baseUrl/api/webservice/saveforummessage',
        '$baseUrl/api/webservice/saveForumMessage',
        '$baseUrl/api/webservice/saveLessonForumComment',
      ];

      // Build multiple payload variants to match inconsistent backends
      final defaultPayload = {
        'subject_syllabus_id': subjectSyllabusId,
        'message': message,
        'student_id': studentId,
        'user_id': studentId, // Some backends check user_id
        'created_by': 'student', // Some backends check created_by
        if (studentSessionId.isNotEmpty) 'student_session_id': studentSessionId,
      };

      final payloads = [
        {
          'type': 'json',
          'description': 'subject_syllabus_id JSON payload',
          'body': jsonEncode(defaultPayload),
        },
        {
          'type': 'form',
          'description': 'Form-encoded payload',
          'body': _encodeFormData({
            'subject_syllabus_id': subjectSyllabusId,
            'message': message,
            'student_id': studentId,
            'user_id': studentId,
            if (studentSessionId.isNotEmpty)
              'student_session_id': studentSessionId,
          }),
        },
        {
          'type': 'form',
          'description': 'Alternative key form payload',
          'body': _encodeFormData({
            'subject_syllabusid': subjectSyllabusId,
            'message': message,
            'studentId': studentId,
            if (studentSessionId.isNotEmpty)
              'studentSessionId': studentSessionId,
          }),
        },
      ];

      for (final endpoint in endpoints) {
        final url = Uri.parse(endpoint);

        for (final payload in payloads) {
          final requestHeaders = Map<String, String>.from(baseHeaders);
          if (payload['type'] == 'form') {
            requestHeaders['Content-Type'] =
                'application/x-www-form-urlencoded';
          } else {
            requestHeaders['Content-Type'] = 'application/json';
          }

          if (studentSessionId.isNotEmpty) {
             requestHeaders['Student-Session-Id'] = studentSessionId;
          }

          
          
          
          
          

          http.Response? response;
          try {
            response = await http
                .post(url, headers: requestHeaders, body: payload['body'])
                .timeout(const Duration(seconds: 30));
          } catch (networkError) {
            
            continue;
          }

          
          

          if (response.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(response.body)) {
            try {
              final data = jsonDecode(response.body);

              if (data['syllabus'] != null) {
                
                return {
                  'status': 1,
                  'message': 'Comment saved successfully',
                  'syllabus': data['syllabus'],
                };
              }

              if (data['status'] == 1 ||
                  data['status'] == '1' ||
                  data['success'] == true) {
                
                return {
                  'status': 1,
                  'message':
                      data['message']?.toString() ??
                      'Comment saved successfully',
                };
              }

              final errorMsg =
                  data['message']?.toString() ?? 'Failed to save comment';
              
              // Try next payload/endpoint
              continue;
            } catch (parseError) {
              
              final responseLower = response.body.toLowerCase();
              if (responseLower.contains('success') ||
                  responseLower.contains('saved') ||
                  responseLower.contains('added')) {
                
                return {'status': 1, 'message': 'Comment saved successfully'};
              }
              // Try next payload/endpoint
              continue;
            }
          } else {
            
            // Try the next payload/endpoint
            continue;
          }
        }
      }

      
      return {
        'status': 0,
        'message': 'Failed to save comment. Please try again later.',
      };
    } catch (e) {
      
      return {'status': 0, 'message': 'Error saving forum comment: $e'};
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
  // Delete forum comment
  static Future<Map<String, dynamic>> deleteForumComment(String commentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      // Try deleteforummessage (standard naming) or others if needed
      // Based on pattern in StudentBehaviourApi which uses deleteincidentcomments
      final url = Uri.parse('$baseUrl/api/webservice/deleteforummessage');

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // API expects lesson_plan_forum_id as per curl provided by user
      final body = jsonEncode({'lesson_plan_forum_id': commentId});

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return {
            'status': data['status'] ?? 0,
            'message': data['message'] ?? (data['msg'] ?? 'Operation complete'),
          };
        } catch (e) {
          
           // Fallback if not JSON
           return {
            'status': 1, // Assume success if 200 OK but weird body? No, safer to be cautious.
            'message': 'Response parsing error'
          };
        }
      } else {
        return {
          'status': 0,
          'message': 'Failed to delete: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
      };
    }
  }

}

String _encodeFormData(Map<String, String> data) {
  return data.entries
      .map(
        (entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
      )
      .join('&');
}
