import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';
import '../../config/app_config.dart';

class TeacherApi {
  // Get teachers list
  static Future<Map<String, dynamic>> getTeachersList(String classId, String sectionId, String userId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // Try multiple endpoints to find the working one
      final endpoints = [
        await AppConfig.getApiEndpoint('getTeachersList'),
        await AppConfig.getApiEndpoint('getTeachers'),
        await AppConfig.getApiEndpoint('teachers'),
        await AppConfig.getApiEndpoint('getStaffList'),
        await AppConfig.getApiEndpoint('staff')
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Try different parameter combinations
      final bodyVariants = [
        jsonEncode({
          'class_id': classId,
          'section_id': sectionId,
          'user_id': userId,
        }),
        jsonEncode({
          'classId': classId,
          'sectionId': sectionId,
          'userId': userId,
        }),
        jsonEncode({
          'class_Id': classId,
          'section_Id': sectionId,
          'user_Id': userId,
        }),
        jsonEncode({
          'class': classId,
          'section': sectionId,
          'user': userId,
        }),
      ];

      

      for (String endpoint in endpoints) {
        for (String body in bodyVariants) {
          try {
            
            final url = Uri.parse(endpoint);

            final response = await http.post(url, headers: headers, body: body);

            
            

            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
              
              
              // Parse JSON and check multiple possible keys
              try {
                final jsonData = jsonDecode(response.body);
                
                
                List<dynamic>? teachersList;
                
                if (jsonData is List) {
                  teachersList = jsonData;
                  
                } else if (jsonData is Map) {
                  
                  
                  // Check multiple possible keys for teachers data
                  for (String key in [
                    'teachers',
                    'teacher_list',
                    'data',
                    'result',
                    'staff',
                    'staff_list',
                    'list',
                    'items',
                  ]) {
                    if (jsonData[key] != null) {
                      
                      if (jsonData[key] is List) {
                        teachersList = jsonData[key] as List;
                        
                        break;
                      }
                    }
                  }
                }
                
                // Always return data, even if empty list
                if (teachersList != null) {
                  return {
                    'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                    'message': jsonData is Map ? (jsonData['message'] ?? 'Success') : 'Success',
                    'teachers': teachersList,
                  };
                } else {
                  
                  return {
                    'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                    'message': jsonData is Map ? (jsonData['message'] ?? 'No teachers found') : 'No teachers found',
                    'teachers': [],
                  };
                }
              } catch (e) {
                
                
              }
              
              // Fallback to ResponseValidator
              final data = ResponseValidator.validateAndParseJson(
                response.body,
                'teachers',
              );
              
              // Check multiple keys in fallback
              if (data['teachers'] == null || (data['teachers'] as List).isEmpty) {
                for (String key in ['teacher_list', 'data', 'result', 'staff', 'staff_list']) {
                  if (data[key] != null && data[key] is List) {
                    data['teachers'] = data[key];
                    
                    break;
                  }
                }
              }
              
              if (data['teachers'] == null || (data['teachers'] as List).isEmpty) {
                
                data['teachers'] = [];
              }
              
              return data;
            }
          } catch (e) {
            
          }
        }
      }

      // If no endpoint works, return error
      
      return {
        'status': 0,
        'message': 'Failed to load teachers. Please try again later.',
        'teachers': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading teachers: $e',
        'teachers': [],
      };
    }
  }

  // Get teacher subjects
  static Future<Map<String, dynamic>> getTeacherSubject(String classId, String sectionId, String staffId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/getTeacherSubject');

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'class_id': classId,
        'section_id': sectionId,
        'staff_id': staffId,
      });

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'subjects',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load teacher subjects: ${response.statusCode}',
          'subjects': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading teacher subjects: $e',
        'subjects': [],
      };
    }
  }

  // Get teacher reviews
  static Future<Map<String, dynamic>> getTeacherReviews(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'reviews': [],
        };
      }

      final endpoints = [
        '$baseUrl/api/webservice/getTeacherReviews',
        '$baseUrl/api/webservice/getTeacherReview',
        '$baseUrl/api/webservice/getTeacherRatings',
        '$baseUrl/api/webservice/teacherReviews',
        '$baseUrl/api/webservice/getStaffReviews',
        '$baseUrl/api/webservice/getStaffRating',
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final bodyVariants = [
        jsonEncode({'studentId': studentId}),
        jsonEncode({'student_id': studentId}),
        jsonEncode({'student_Id': studentId}),
        jsonEncode({'id': studentId}),
      ];

      

      for (final endpoint in endpoints) {
        for (final body in bodyVariants) {
          try {
            
            final response = await http.post(Uri.parse(endpoint), headers: headers, body: body);

            
            

            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
              
              final parsed = _parseTeacherReviewsResponse(response.body);

              final reviews = (parsed['reviews'] as List?) ?? [];
              if (reviews.isNotEmpty || parsed['status'] == 1) {
                return parsed;
              }

              // If the response was successful but empty, keep trying other variants
            }
          } catch (e) {
            
          }
        }
      }

      
      return {
        'status': 0,
        'message': 'Failed to load teacher reviews. Please try again later.',
        'reviews': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading teacher reviews: $e',
        'reviews': [],
      };
    }
  }

  // Get teachers for review - Uses getTeachersList API
  static Future<Map<String, dynamic>> getTeachersForReview(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'teachers': [],
        };
      }

      // Get dynamic values from user profile
      final userProfile = await AuthService.getUserProfile();
      final userClass = userProfile['class'];
      final userSection = userProfile['section'];
      final userId = await DynamicApiHeaders.getUserId();
      
      if (userClass == null || userClass.isEmpty) {
        
        throw Exception('No class found. Please login again.');
      }
      if (userSection == null || userSection.isEmpty) {
        
        throw Exception('No section found. Please login again.');
      }
      if (userId == null || userId.isEmpty) {
        
        throw Exception('No user ID found. Please login again.');
      }
      
      // Extract numeric class ID (e.g., "Class 1" -> "1", "Class 5" -> "5")
      final classId = userClass.replaceAll(RegExp(r'[^0-9]'), '');
      if (classId.isEmpty) {
        
        throw Exception('Invalid class format. Please login again.');
      }
      
      // Convert section to numeric format (e.g., "A" -> "1", "B" -> "2")
      final sectionId = userSection == 'A' ? '1' : 
                       userSection == 'B' ? '2' : 
                       userSection == 'C' ? '3' : 
                       userSection == 'D' ? '4' : 
                       userSection == 'E' ? '5' : userSection;
      
      
      
      
      

      final endpoint = '$baseUrl/api/webservice/getTeachersList';
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'class_id': classId,
        'section_id': sectionId,
        'user_id': userId,
      });

      
      
      

      final response = await http.post(Uri.parse(endpoint), headers: headers, body: body);

      
      
      
      // Check if response is HTML (error page)
      if (ResponseValidator.isHtmlResponse(response.body)) {
        
        return {
          'status': 0,
          'message': 'API returned error page. Please try again later.',
          'teachers': [],
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
          'teachers': [],
        };
      }

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          
          
          
          // API returns: {"result_list": {"5": {...}, "2": {...}}}
          if (jsonData is Map && jsonData.containsKey('result_list')) {
            final resultList = jsonData['result_list'];
            
            
            if (resultList is Map) {
              // Convert map to list of teachers
              final teachersList = <Map<String, dynamic>>[];
              resultList.forEach((staffId, teacherData) {
                if (teacherData is Map) {
                  // Add staff_id to the teacher data for easier access
                  final teacher = Map<String, dynamic>.from(teacherData);
                  teacher['staff_id'] = staffId.toString();
                  teacher['id'] = teacher['staff_id'] ?? staffId.toString();
                  teachersList.add(teacher);
                  
                }
              });
              
              
              return {
                'status': 1,
                'message': 'Success',
                'teachers': teachersList,
              };
            } else if (resultList is List) {
              // If result_list is already a list
              
              return {
                'status': 1,
                'message': 'Success',
                'teachers': resultList,
              };
            }
          }
          
          // Fallback to existing parser
          final parsed = _parseTeachersForReviewResponse(response.body);
          final teachers = (parsed['teachers'] as List?) ?? [];
          
          return parsed;
        } catch (e) {
          
          
          return {
            'status': 0,
            'message': 'Error parsing response: $e',
            'teachers': [],
          };
        }
      } else {
        
        
        return {
          'status': 0,
          'message': 'Failed to load teachers: ${response.statusCode}',
          'teachers': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading teachers for review: $e',
        'teachers': [],
      };
    }
  }

  static Map<String, dynamic> _parseTeacherReviewsResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map<String, dynamic>) {
        for (final key in ['reviews', 'review_list', 'data', 'teacher_reviews', 'result', 'ratings']) {
          final value = decoded[key];
          if (value is List) {
            return {
              'status': decoded['status'] ?? 1,
              'message': decoded['message'] ?? 'Success',
              'reviews': value,
            };
          }
        }

        // If the map itself represents a review item, wrap it in a list
        if (decoded.values.any((value) => value is Map)) {
          return {
            'status': decoded['status'] ?? 1,
            'message': decoded['message'] ?? 'Success',
            'reviews': [decoded],
          };
        }

        return {
          'status': decoded['status'] ?? 0,
          'message': decoded['message'] ?? 'No reviews data found',
          'reviews': <dynamic>[],
        };
      }

      if (decoded is List) {
        return {
          'status': 1,
          'message': 'Success',
          'reviews': decoded,
        };
      }
    } catch (e) {
      
    }

    final validated = ResponseValidator.validateAndParseJson(responseBody, 'reviews');
    validated['reviews'] = (validated['reviews'] as List?) ?? [];
    return validated;
  }

  static Map<String, dynamic> _parseTeachersForReviewResponse(String responseBody) {
    try {
      final decoded = jsonDecode(responseBody);
      

      if (decoded is Map) {
        // Check for result_list structure (API returns {"result_list": {"5": {...}, "2": {...}}})
        if (decoded['result_list'] != null) {
          final resultList = decoded['result_list'];
          
          
          if (resultList is Map) {
            // Convert map to list of teachers
            final teachersList = <Map<String, dynamic>>[];
            resultList.forEach((staffId, teacherData) {
              if (teacherData is Map) {
                // Add staff_id to the teacher data for easier access
                final teacher = Map<String, dynamic>.from(teacherData);
                teacher['staff_id'] = staffId.toString();
                teacher['id'] = teacher['staff_id'] ?? staffId.toString();
                teachersList.add(teacher);
                
              }
            });
            
            
            return {
              'status': 1,
              'message': 'Success',
              'teachers': teachersList,
            };
          } else if (resultList is List) {
            // If result_list is already a list
            return {
              'status': 1,
              'message': 'Success',
              'teachers': resultList,
            };
          }
        }
        
        // Check other possible keys
        for (final key in ['teachers', 'teacher_list', 'data', 'result', 'staff', 'staff_list']) {
          final value = decoded[key];
          if (value is List) {
            return {
              'status': decoded['status'] ?? 1,
              'message': decoded['message'] ?? 'Success',
              'teachers': value,
            };
          }
        }

        // If the map itself contains teacher data
        if (decoded.values.any((value) => value is Map)) {
          final teachersList = decoded.values.whereType<Map<String, dynamic>>().toList();
          return {
            'status': decoded['status'] ?? 1,
            'message': decoded['message'] ?? 'Success',
            'teachers': teachersList,
          };
        }

        return {
          'status': decoded['status'] ?? 0,
          'message': decoded['message'] ?? 'No teachers data found',
          'teachers': <dynamic>[],
        };
      }

      if (decoded is List) {
        return {
          'status': 1,
          'message': 'Success',
          'teachers': decoded,
        };
      }
    } catch (e) {
      
      
    }

    final validated = ResponseValidator.validateAndParseJson(responseBody, 'teachers');
    validated['teachers'] = (validated['teachers'] as List?) ?? [];
    return validated;
  }

  // Add teacher rating
  static Future<Map<String, dynamic>> addStaffRating(
    String rate,
    String comment,
    String role,
    String staffId,
    String userId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('addStaffRating'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({
        'rate': rate,
        'comment': comment,
        'role': role,
        'staff_id': staffId,
        'user_id': userId,
      });

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to add staff rating: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error adding staff rating: $e',
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
