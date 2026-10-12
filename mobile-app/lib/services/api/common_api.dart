import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class CommonApi {
  // Get base URL
  static Future<String> getBaseUrl() async {
    final baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      
      
      // Don't throw exception, return empty string to trigger sample data fallback
      return '';
    }
    return baseUrl;
  }

  // Test API connectivity
  static Future<Map<String, dynamic>> testApiConnectivity() async {
    try {
      final baseUrl = await getBaseUrl();
      
      // Test multiple endpoints to find the working one
      final testEndpoints = [
        '$baseUrl/api/webservice/test',
        '$baseUrl/api/test',
        '$baseUrl/api/webservice/getNoticeBoard',
        '$baseUrl/api/webservice/getHomework',
      ];
      
      for (String endpoint in testEndpoints) {
        try {
          final url = Uri.parse(endpoint);
          final headers = await DynamicApiHeaders.getCompleteHeaders();
          
          final response = await http.post(url, headers: headers, body: jsonEncode({}));
          
          if (response.statusCode == 200) {
            return {
              'status': 1,
              'message': 'API is accessible via $endpoint',
              'statusCode': response.statusCode,
              'workingEndpoint': endpoint,
            };
          }
        } catch (e) {
          
        }
      }
      
      return {
        'status': 0,
        'message': 'No working API endpoints found',
        'statusCode': 0,
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'API connectivity test failed: $e',
        'statusCode': 0,
      };
    }
  }

  // Get notice board
  static Future<Map<String, dynamic>> getNoticeBoard() async {
    try {
      final baseUrl = await getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'data': [],
        };
      }
      
      // Try multiple endpoints to find the working one
      final endpoints = [
        await AppConfig.getApiEndpoint('getNotifications'),
        await AppConfig.getApiEndpoint('getNoticeBoard'),
        await AppConfig.getApiEndpoint('notifications'),
        await AppConfig.getApiEndpoint('notices'),
        await AppConfig.getApiEndpoint('getAnnouncements'),
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      
      // Get session data
      final studentId = await _getStudentId();
      final userId = await _getUserId();
      final role = await _getUserRole();
      

      // Try different parameter combinations
      final bodyVariants = [
        jsonEncode({
          "student_id": studentId,
          "user_id": userId,
          "type": "student",
          "user_type_id": studentId, // Some APIs treat this as student ID
          "role": role ?? "student",
        }),
        jsonEncode({
          "student_id": studentId,
          "type": "student",
        }),
        jsonEncode({
          "user_id": userId,
          "role": "student",
        }),
        jsonEncode({"type": "student"}), // Fallback
        jsonEncode({}),
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
                if (jsonData is Map) {
                  List<dynamic>? noticesList;
                  
                  // Check multiple possible keys for notices data
                  for (String key in ['data', 'notices', 'notice_list', 'notifications', 'result', 'notice_array', 'noticeboard']) {
                    if (jsonData[key] != null && jsonData[key] is List) {
                      noticesList = jsonData[key] as List;
                      break;
                    }
                  }
                  
                  if (noticesList != null) {
                    return {
                      'status': jsonData['status'] ?? 1,
                      'message': jsonData['message'] ?? 'Success',
                      'data': noticesList,
                    };
                  }
                }
              } catch (e) {
                
              }
              
              // Fallback to ResponseValidator
              final data = ResponseValidator.validateAndParseJson(
                response.body,
                'data',
              );
              
              // Check multiple keys in fallback
              if (data['data'] == null || (data['data'] as List).isEmpty) {
                for (String key in ['notices', 'notice_list', 'notifications', 'result']) {
                  if (data[key] != null && data[key] is List) {
                    data['data'] = data[key];
                    break;
                  }
                }
              }
              
              if (data['data'] == null || (data['data'] as List).isEmpty) {
                data['data'] = [];
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
        'message': 'Failed to load notice board. Please try again later.',
        'data': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading notice board: $e',
        'data': [],
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

  static Future<String?> _getStudentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('student_id');
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('user_id');
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _getUserRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('role');
    } catch (e) {
      return null;
    }
  }
}
