import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class HostelApi {
  // Get hostel list
  static Future<Map<String, dynamic>> getHostelList(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'hostels': [],
        };
      }
      
      // Try multiple endpoints to find the working one
      final endpoints = [
        await AppConfig.getApiEndpoint('getHostelList'),
        await AppConfig.getApiEndpoint('getHostels'),
        await AppConfig.getApiEndpoint('hostels'),
        await AppConfig.getApiEndpoint('getStudentHostels'),
        await AppConfig.getApiEndpoint('hostelRooms')
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Try different parameter combinations
      final bodyVariants = [
        jsonEncode({'student_id': studentId}),
        jsonEncode({'studentId': studentId}),
        jsonEncode({'student_Id': studentId}),
        jsonEncode({'id': studentId}),
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
                  List<dynamic>? hostelsList;
                  
                  // Check multiple possible keys for hostels data
                  // Priority: hostelarray (actual API response) first
                  for (String key in ['hostelarray', 'hostels', 'hostel_array', 'rooms', 'data', 'result', 'hostel_list', 'room_list']) {
                    if (jsonData[key] != null && jsonData[key] is List) {
                      hostelsList = jsonData[key] as List;
                      
                      break;
                    }
                  }
                  
                  if (hostelsList != null) {
                    return {
                      'status': jsonData['status'] ?? 1,
                      'message': jsonData['message'] ?? 'Success',
                      'hostels': hostelsList,
                      'hostelarray': jsonData['hostelarray'] ?? hostelsList, // Preserve original key
                    };
                  }
                }
              } catch (e) {
                
              }
              
              // Fallback to ResponseValidator
              final data = ResponseValidator.validateAndParseJson(
                response.body,
                'hostels',
              );
              
              // Check multiple keys in fallback
              if (data['hostels'] == null || (data['hostels'] as List).isEmpty) {
                for (String key in ['hostelarray', 'hostel_array', 'rooms', 'data', 'result']) {
                  if (data[key] != null && data[key] is List) {
                    data['hostels'] = data[key];
                    
                    break;
                  }
                }
              }
              
              if (data['hostels'] == null || (data['hostels'] as List).isEmpty) {
                
                data['hostels'] = [];
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
        'message': 'Failed to load hostels. Please try again later.',
        'hostels': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading hostels: $e',
        'hostels': [],
      };
    }
  }


  // Get session cookie
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
}


