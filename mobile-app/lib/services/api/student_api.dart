import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../config/app_config.dart';

class StudentApi {
  // Get timeline
  static Future<Map<String, dynamic>> getTimeline(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'timeline': [],
        };
      }
      
      // Try multiple endpoints to find the working one
      final endpoints = [
        await AppConfig.getApiEndpoint('getTimeline'),
        await AppConfig.getApiEndpoint('getTimelineList'),
        await AppConfig.getApiEndpoint('timeline'),
        await AppConfig.getApiEndpoint('getStudentTimeline'),
        await AppConfig.getApiEndpoint('calendar')
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Try different parameter combinations
      final bodyVariants = [
        jsonEncode({'studentId': studentId}),
        jsonEncode({'student_id': studentId}),
        jsonEncode({'student_Id': studentId}),
        jsonEncode({'id': studentId}),
      ];

      

      for (String endpoint in endpoints) {
        for (String body in bodyVariants) {
          try {
            
            final url = Uri.parse(endpoint);

            final response = await http.post(url, headers: headers, body: body);

            
            

            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
              
              final data = ResponseValidator.validateAndParseJson(
                response.body,
                'timeline',
              );
              
              // Don't add sample data - return empty list if no real data
              if (data['timeline'] == null || (data['timeline'] as List).isEmpty) {
                
                data['timeline'] = [];
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
        'message': 'Failed to load timeline data. Please try again later.',
        'timeline': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading timeline data: $e',
        'timeline': [],
      };
    }
  }

  // Add/Edit timeline
  static Future<Map<String, dynamic>> addEditTimeline(
    String? id,
    String title,
    String description,
    String timelineDate,
    String studentId,
    String? timelineDoc,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/addedittimeline');

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Remove Content-Type for form-data
      headers.remove('Content-Type');

      // Create form data
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(headers);
      
      request.fields['id'] = id ?? '';
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['timeline_date'] = timelineDate;
      request.fields['student_id'] = studentId;

      // Add file if provided
      if (timelineDoc != null && timelineDoc.isNotEmpty && timelineDoc != 'document.pdf') {
        try {
          final file = await http.MultipartFile.fromPath(
            'timeline_doc',
            timelineDoc,
          );
          request.files.add(file);
          
        } catch (e) {
          
          // Start of Fix: Ensure timeline_doc field is sent even if file attachment fails
          request.fields['timeline_doc'] = '';
          // End of Fix
        }
      } else {
        request.fields['timeline_doc'] = '';
      }

      
      
      
      

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to ${id != null ? 'edit' : 'add'} timeline entry: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error ${id != null ? 'editing' : 'adding'} timeline entry: $e',
      };
    }
  }

  // Delete timeline
  static Future<Map<String, dynamic>> deleteTimeline(String timelineId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/deletetimeline');

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'id': timelineId}); // Use 'id' parameter as per API specification

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to delete timeline entry: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error deleting timeline entry: $e',
      };
    }
  }

  // Get timeline status - check if students are allowed to add timeline
  static Future<Map<String, dynamic>> getTimeLineStatus(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'can_add': false,
        };
      }
      
      // Try multiple endpoints to find the working one
      final endpoints = [
        '$baseUrl/api/webservice/getTimeLineStatus',
        '$baseUrl/api/webservice/getTimelineStatus',
        '$baseUrl/api/webservice/timelineStatus',
        '$baseUrl/api/webservice/getStudentTimelineStatus',
        '$baseUrl/api/webservice/get_timeline_status',
        '$baseUrl/api/webservice/getTimelineSettings',
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
        jsonEncode({'id': studentId}),
        jsonEncode({}), // Fallback
      ];

      

      for (String endpoint in endpoints) {
        for (String body in bodyVariants) {
          try {
            
            final url = Uri.parse(endpoint);

            final response = await http.post(
              url, 
              headers: headers, 
              body: body,
            );

            
            

            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
            
            final data = jsonDecode(response.body);
            
            
            
            
            bool canAdd = false;
            
            // CRITICAL: If status == 1, timeline is ENABLED for students
            // This is the primary and most reliable indicator
            if (data['status'] == 1 || data['status'] == '1') {
              canAdd = true;
              
            } 
            // Fallback: Check other possible permission indicators
            else {
              
              final permissionKeys = [
                'allow_student_timeline',
                'is_student_timeline',
                'student_timeline',
                'can_add_timeline',
                'allow_timeline',
                'is_timeline_enabled',
                'timeline_status',
              ];

              for (String key in permissionKeys) {
                if (data[key] != null) {
                  final val = data[key].toString();
                  
                  if (val == '1' || val.toLowerCase() == 'true' || val.toLowerCase() == 'yes' || val.toLowerCase() == 'enabled') {
                    canAdd = true;
                    
                    break;
                  }
                }
              }
            }
            
            
            
            return {
              'status': 1,
              'can_add': canAdd,
              'message': 'Timeline status retrieved successfully',
              'raw_data': data,
            };
          }
          } catch (e) {
            
          }
        }
      }

      // If no endpoint works, default to false
      
      return {
        'status': 0,
        'message': 'Failed to check timeline status',
        'can_add': false,
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error checking timeline status: $e',
        'can_add': false,
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
