import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class TimetableApi {
  // Get class schedule/timetable
  static Future<Map<String, dynamic>> getClassSchedule(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'timetable': {},
        };
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('class_schedule'));

      // Get dynamic headers (Authorization, User-ID, Auth-Key, Client-Service, etc.)
      // All values come from login session - NO STATIC VALUES
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      
      
      
      
      
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
        
      } else {
        
      }

      final body = jsonEncode({'student_id': studentId}); // Use underscore as per API documentation

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'timetable',
        );
        // Don't add sample data - return empty timetable if not found
        if (data['timetable'] == null || (data['timetable'] as Map).isEmpty) {
          
          data['timetable'] = {};
        }
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load class schedule: ${response.statusCode}',
          'timetable': {},
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading class schedule: $e',
        'timetable': {},
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



