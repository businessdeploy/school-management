import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../auth_service.dart';
import '../../config/app_config.dart';

class StudentBehaviourApi {
  // Get student behaviour
  // API: https://demo.smart-school.in/api/webservice/getstudentbehaviour
  // Body: {"student_id":"98"} (snake_case) - studentId is passed as parameter from AuthService
  // Response: {behaviour_settings, behaviour_score, assigned_incident: [...]}
  static Future<Map<String, dynamic>> getStudentBehaviour(
    String studentId,
  ) async {
    try {
      
      
      
      

      final baseUrl = await UrlManager.getBaseUrl();
      

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'behaviour': [],
        };
      }

      // Primary endpoint as per API documentation
      final endpoints = [
        await AppConfig.getApiEndpoint('getstudentbehaviour'), // Primary endpoint (as per API doc)
        await AppConfig.getApiEndpoint('getStudentBehaviour'), // Fallback (camelCase)
        await AppConfig.getApiEndpoint('getBehaviour'),
        await AppConfig.getApiEndpoint('behaviour'),
        await AppConfig.getApiEndpoint('getStudentBehavior'),
      ];

      // Get dynamic headers (Authorization, User-ID, Auth-Key, Client-Service, etc.)
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Get dynamic values for verification
      final authToken = await DynamicApiHeaders.getAuthToken();
      final userId = await DynamicApiHeaders.getUserId();
      final studentIdFromAuth = await DynamicApiHeaders.getStudentId();
      final cookieFromHeaders = await DynamicApiHeaders.getSessionCookie();

      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      

      // Add session cookie if available (check both sources)
      // Cookie format from curl: ci_session=lelare6f7m05kun2pkvb0rj26c2nac4a
      String? cookie = cookieFromHeaders;
      if (cookie == null || cookie.isEmpty) {
        cookie = await _getSessionCookie();
      }

      // Ensure cookie has ci_session= prefix and clean format
      // Cookie format from curl: ci_session=lelare6f7m05kun2pkvb0rj26c2nac4a (NO semicolons or extra attributes)
      if (cookie != null && cookie.isNotEmpty) {
        // Remove any semicolons and everything after (like "; expires=Sat")
        if (cookie.contains(';')) {
          cookie = cookie.split(';').first.trim();
          
        }

        if (!cookie.startsWith('ci_session=')) {
          // If cookie doesn't start with ci_session=, add it
          if (cookie.contains('=')) {
            // Cookie already has format like "key=value", use as is
            
          } else {
            // Cookie is just the value, add ci_session= prefix
            cookie = 'ci_session=$cookie';
            
          }
        }

        // Final cookie should be: ci_session=value (no semicolons, no expires, etc.)
        headers['Cookie'] = cookie;
        
        
      } else {
        
        
        
      }

      // Body format as per working curl: {"student_id":"98"} (snake_case, not camelCase)
      // Using dynamic studentId parameter passed to function (from AuthService.getStudentId())
      final body = jsonEncode({'student_id': studentId});
      
      
      
      
      
      
      
      
      
      final authHeader = headers['Authorization'] ?? 'NOT SET';
      
      
      
      
      
      final cookieHeader = headers['Cookie'] ?? 'NOT SET';
      
      
      
      
      
      
      
      
      
      
      

      for (String endpoint in endpoints) {
        try {
          
          final url = Uri.parse(endpoint);

          // Ensure body is sent as UTF-8 JSON string (exactly as curl does)
          final response = await http.post(
            url,
            headers: headers,
            body: body,
            encoding: utf8, // Explicitly set UTF-8 encoding
          );

          
          
          

          // Log full response for debugging (first 2000 chars)
          final responsePreview = response.body.length > 2000
              ? '${response.body.substring(0, 2000)}...'
              : response.body;
          

          // Check for non-200 status codes
          if (response.statusCode != 200) {
            
            
            
            
            
            
            
            continue; // Try next endpoint
          }

          // Check if response is HTML (error page)
          if (ResponseValidator.isHtmlResponse(response.body)) {
            
            
            continue; // Try next endpoint
          }

          // Check if response is SQL query text (error response from server)
          // This happens when server-side code has an error and leaks SQL
          final responseBodyUpper = response.body.trim().toUpperCase();
          final isSqlError =
              responseBodyUpper.startsWith('SELECT') ||
              responseBodyUpper.startsWith('INSERT') ||
              responseBodyUpper.startsWith('UPDATE') ||
              responseBodyUpper.startsWith('DELETE') ||
              responseBodyUpper.startsWith('FROM') ||
              (responseBodyUpper.contains('WHERE') &&
                  responseBodyUpper.contains('FROM')) ||
              responseBodyUpper.contains('JOIN') ||
              responseBodyUpper.contains('INNER JOIN') ||
              responseBodyUpper.contains('SUM(') ||
              responseBodyUpper.contains('COUNT(');

          if (isSqlError) {
            
            
            
            
            
            
            
            

            // If SQL error, it means the request format might be wrong
            // Let's check Content-Type to see if server intended to send JSON
            final contentType = response.headers['content-type'] ?? '';
            
            

            continue; // Try next endpoint
          }

          // Check for successful response (200 status code)
          // Note: API should return 200 OK for successful requests
          if (response.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(response.body)) {
            
            
            
            

            // Capture session cookie from response headers (if not already set)
            // Check both 'set-cookie' and 'Set-Cookie' headers (case-insensitive)
            String? setCookieHeader =
                response.headers['set-cookie'] ??
                response.headers['Set-Cookie'];
            if (setCookieHeader == null || setCookieHeader.isEmpty) {
              // Try case-insensitive search
              for (String key in response.headers.keys) {
                if (key.toLowerCase() == 'set-cookie') {
                  setCookieHeader = response.headers[key];
                  break;
                }
              }
            }

            if (setCookieHeader != null && setCookieHeader.isNotEmpty) {
              

              // Parse cookie - format: ci_session=value; path=/; HttpOnly
              String sessionCookie = setCookieHeader;

              // Extract just the ci_session=value part (before semicolon)
              if (sessionCookie.contains(';')) {
                sessionCookie = sessionCookie.split(';').first.trim();
              }

              // Ensure it starts with ci_session=
              if (!sessionCookie.startsWith('ci_session=')) {
                // Try to extract just the value and add prefix
                if (sessionCookie.contains('ci_session')) {
                  final match = RegExp(
                    r'ci_session=([^;]+)',
                  ).firstMatch(setCookieHeader);
                  if (match != null) {
                    sessionCookie = 'ci_session=${match.group(1)}';
                  }
                }
              }

              await _saveSessionCookie(sessionCookie);
              
            } else {
              
            }

            // Parse JSON - API returns: {behaviour_settings, behaviour_score, assigned_incident}
            try {
              final jsonData = jsonDecode(response.body);
              

              if (jsonData is Map) {
                
                
                

                List<dynamic>? behaviourList;

                // Priority: assigned_incident (as per API documentation)
                // Then check other possible keys for backward compatibility
                for (String key in [
                  'assigned_incident', // Primary key as per API documentation
                  'assigned_incidents',
                  'behaviour',
                  'behaviour_list',
                  'data',
                  'incidents',
                  'behaviour_records',
                  'student_behaviour',
                  'behaviours',
                  'incident_list',
                ]) {
                  if (jsonData[key] != null) {
                    
                    if (jsonData[key] is List) {
                      behaviourList = jsonData[key] as List;
                      
                      if (behaviourList.isNotEmpty) {
                        
                      }
                      break;
                    } else {
                      
                    }
                  }
                }

                // Always return the full response structure (even if list is empty)
                // Handle null behaviour_score - API returns null when no score
                String behaviourScore = '0';
                if (jsonData['behaviour_score'] != null) {
                  behaviourScore = jsonData['behaviour_score'].toString();
                } else if (jsonData['score'] != null) {
                  behaviourScore = jsonData['score'].toString();
                }

                final result = {
                  'status': 1,
                  'message': 'Success',
                  'behaviour':
                      behaviourList ??
                      [], // Map to 'behaviour' for UI compatibility
                  'assigned_incident':
                      behaviourList ?? [], // Preserve original key
                  'behaviour_score': behaviourScore,
                  'behaviour_settings': jsonData['behaviour_settings'],
                };

                
                
                
                
                
                return result;
              } else if (jsonData is List) {
                // Response is directly a list (fallback)
                
                return {
                  'status': 1,
                  'message': 'Success',
                  'behaviour': jsonData,
                  'assigned_incident': jsonData,
                  'behaviour_score': '0',
                  'behaviour_settings': null,
                };
              } else {
                
              }
            } catch (parseError) {
              
              
            }

            // Fallback to ResponseValidator - try to parse again
            try {
              final fallbackData = ResponseValidator.validateAndParseJson(
                response.body,
                'behaviour',
              );

              

              // Ensure assigned_incident is mapped to behaviour for UI
              List<dynamic>? fallbackList;

              if (fallbackData['assigned_incident'] != null &&
                  fallbackData['assigned_incident'] is List) {
                fallbackList = fallbackData['assigned_incident'] as List;
                
              } else if (fallbackData['behaviour'] != null &&
                  fallbackData['behaviour'] is List) {
                fallbackList = fallbackData['behaviour'] as List;
                
              }

              // Handle null behaviour_score
              String fallbackScore = '0';
              if (fallbackData['behaviour_score'] != null) {
                fallbackScore = fallbackData['behaviour_score'].toString();
              } else if (fallbackData['score'] != null) {
                fallbackScore = fallbackData['score'].toString();
              }

              // Always return with all expected keys
              return {
                'status': fallbackData['status'] ?? 1,
                'message': fallbackData['message'] ?? 'Success',
                'behaviour': fallbackList ?? [],
                'assigned_incident': fallbackList ?? [],
                'behaviour_score': fallbackScore,
                'behaviour_settings': fallbackData['behaviour_settings'],
              };
            } catch (fallbackError) {
              
            }

            // Last resort - return empty structure
            
            return {
              'status': 1,
              'message': 'Success',
              'behaviour': [],
              'assigned_incident': [],
              'behaviour_score': '0',
              'behaviour_settings': null,
            };
          }
        } catch (e) {
          
        }
      }

      // If no endpoint works, return error
      
      
      
      return {
        'status': 0,
        'message': 'Failed to load behaviour data. Please try again later.',
        'behaviour': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading behaviour data: $e',
        'behaviour': [],
      };
    }
  }

  // Get incident comments
  // API: https://demo.smart-school.in/api/webservice/getincidentcomments
  // Body: {"student_incident_id":"963"}
  // Response: {messagelist: [...]}
  static Future<Map<String, dynamic>> getIncidentComments(
    String incidentId,
  ) async {
    try {
      
      
      
      

      final baseUrl = await UrlManager.getBaseUrl();
      

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'comments': [],
        };
      }

      // Primary endpoint as per API documentation
      final endpoints = [
        await AppConfig.getApiEndpoint('getincidentcomments'), // Primary endpoint (as per API doc)
        await AppConfig.getApiEndpoint('getIncidentComments'), // Fallback (camelCase)
        await AppConfig.getApiEndpoint('get_incident_comments'),
        await AppConfig.getApiEndpoint('incidentcomments'),
        await AppConfig.getApiEndpoint('incident_comments'),
      ];

      // Get dynamic headers (Authorization, User-ID, Auth-Key, Client-Service, etc.)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      
      
      
      

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
        
      } else {
        
      }

      // Body as per API documentation: {"student_incident_id":"<dynamic>"}
      // Using dynamic incidentId parameter passed to function
      final body = jsonEncode({'student_incident_id': incidentId});
      
      

      for (String endpoint in endpoints) {
        try {
          
          final url = Uri.parse(endpoint);

          final response = await http.post(url, headers: headers, body: body);

          
          

          if (response.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(response.body)) {
            

            // Parse JSON - API returns: {messagelist: [...]}
            try {
              final jsonData = jsonDecode(response.body);
              if (jsonData is Map) {
                List<dynamic>? commentsList;

                // Priority: messagelist (as per API documentation)
                // Then check other possible keys for backward compatibility
                for (String key in [
                  'messagelist', // Primary key as per API documentation
                  'comments',
                  'comment_list',
                  'data',
                  'result',
                  'messages',
                  'message_list',
                ]) {
                  if (jsonData[key] != null && jsonData[key] is List) {
                    commentsList = jsonData[key] as List;
                    
                    break;
                  }
                }

                // Always return the full response structure (even if list is empty)
                return {
                  'status': 1,
                  'message': 'Success',
                  'comments':
                      commentsList ??
                      [], // Map to 'comments' for UI compatibility
                  'messagelist': commentsList ?? [], // Preserve original key
                };
              }
            } catch (parseError) {
              
            }

            // Fallback to ResponseValidator
            final data = ResponseValidator.validateAndParseJson(
              response.body,
              'comments',
            );

            // Ensure messagelist is mapped to comments for UI
            if (data['messagelist'] != null && data['messagelist'] is List) {
              data['comments'] = data['messagelist'];
            }

            if (data['comments'] == null ||
                (data['comments'] as List).isEmpty) {
              
              data['comments'] = [];
            }

            return data;
          }
        } catch (e) {
          
        }
      }

      // If no endpoint works, return error
      
      return {
        'status': 0,
        'message': 'Failed to load comments. Please try again later.',
        'comments': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading incident comments: $e',
        'comments': [],
      };
    }
  }

  // Add incident comment
  // API: https://demo.smart-school.in/api/webservice/addincidentcomments
  // Body: {student_incident_id, type, comment, student_id}
  // Response: {status: "1", msg: "Success"}
  static Future<Map<String, dynamic>> addIncidentComment(
    String incidentId,
    String comment,
  ) async {
    try {
      
      
      
      
      

      final baseUrl = await UrlManager.getBaseUrl();
      

      if (baseUrl.isEmpty) {
        
        return {
          'status': '0',
          'msg': 'Please configure the base URL in settings',
        };
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('addincidentcomments'));

      // Get dynamic headers (Authorization, User-ID, Auth-Key, Client-Service, etc.)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      
      
      
      

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
        
      } else {
        
      }

      // Get dynamic student ID from authentication service
      final studentId = await AuthService.getStudentId();
      

      // Body as per API documentation - all values are dynamic
      final body = jsonEncode({
        'student_incident_id': incidentId, // Dynamic parameter
        'type': 'student',
        'comment': comment, // Dynamic parameter
        'student_id': studentId, // Dynamic from AuthService
      });

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          

          // API returns: {"status": "1", "msg": "Success"}
          // Normalize response format
          return {
            'status': data['status']?.toString() ?? '0',
            'msg': data['msg'] ?? data['message'] ?? 'Comment added',
            'message': data['msg'] ?? data['message'] ?? 'Comment added',
          };
        } catch (e) {
          
          return {'status': '0', 'msg': 'Error parsing server response'};
        }
      } else {
        
        return {
          'status': '0',
          'msg': 'Failed to add incident comment: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {'status': '0', 'msg': 'Error adding incident comment: $e'};
    }
  }

  // Delete incident comment
  // API: https://devx.webfeb.com/ss720devaddoninst/api/webservice/deleteincidentcomments
  // cURL format:
  // curl --location 'https://devx.webfeb.com/ss720devaddoninst/api/webservice/deleteincidentcomments' \
  // --header 'Auth-Key: schoolAdmin@' \
  // --header 'Client-Service: smartschool' \
  // --header 'Content-Type: application/json' \
  // --header 'User-ID: 26' \
  // --header 'Authorization: MQNgMwMgMQ' \
  // --header 'Cookie: ci_session=...' \
  // --data '{
  //   "incident_comment_id": "45"
  // }'
  // Body: {incident_comment_id} (only this field is needed)
  static Future<Map<String, dynamic>> deleteIncidentComment(
    Map<String, dynamic> payload,
  ) async {
    try {
      
      
      

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': '0',
          'msg': 'Please configure the base URL in settings',
        };
      }

      // Extract incident_comment_id from payload (dynamic)
      final incidentCommentId = payload['incident_comment_id']?.toString().trim() ?? 
                                 payload['comment_id']?.toString().trim() ??
                                 payload['student_incident_comment_id']?.toString().trim() ??
                                 '';
      
      if (incidentCommentId.isEmpty) {
        
        return {
          'status': '0',
          'msg': 'Comment ID is required for deletion',
        };
      }

      

      // Primary endpoint: deleteincidentcomments (plural, as per curl command)
      final endpoints = [
        '$baseUrl/api/webservice/deleteincidentcomments', // Primary endpoint (from curl)
        '$baseUrl/api/webservice/deleteincidentcomment',  // Fallback (singular)
        '$baseUrl/api/webservice/deleteIncidentComment',
        '$baseUrl/api/webservice/removeincidentcomment',
        '$baseUrl/api/webservice/removeIncidentComment',
      ];

      // Get dynamic headers (all values are dynamic)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      
      
      
      

      // Add session cookie if available (dynamic)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
        
      } else {
        
      }

      // Build request body as per curl command - ONLY incident_comment_id
      // All values are dynamic
      final body = jsonEncode({
        'incident_comment_id': incidentCommentId, // Dynamic: from comment data
      });

      

      for (final endpoint in endpoints) {
        try {
          
          final response = await http.post(
            Uri.parse(endpoint),
            headers: headers,
            body: body,
          );
          
          

          if (response.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(response.body)) {
            try {
              final data = jsonDecode(response.body);
              final successFlags = <String>[
                data['status']?.toString() ?? '',
                data['success']?.toString() ?? '',
              ].map((value) => value.toLowerCase());
              final message = data['msg'] ?? data['message'];
              final bool successFlag =
                  successFlags.any((value) =>
                      value == '1' || value == 'success' || value == 'true');
              final bool explicitSuccess = data['success'] == true ||
                  data['status'] == true ||
                  (message?.toString().toLowerCase() == 'success');

              if (successFlag || explicitSuccess) {
                return {
                  'status': '1',
                  'msg': message ?? 'Comment deleted',
                  'message': message ?? 'Comment deleted',
                };
              }

              return {
                'status': data['status']?.toString() ?? '0',
                'msg': message ?? 'Failed to delete comment',
                'message': message ?? 'Failed to delete comment',
              };
            } catch (e) {
              
            }
          }
        } catch (e) {
          
        }
      }

      return {
        'status': '0',
        'msg': 'Unable to delete comment. Please try again later.',
      };
    } catch (e) {
      
      return {'status': '0', 'msg': 'Error deleting incident comment: $e'};
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

  // Save session cookie to SharedPreferences
  static Future<void> _saveSessionCookie(String cookie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', cookie);
      
    } catch (e) {
      
    }
  }
}
