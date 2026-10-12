import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class LiveClassApi {
  // Get Zoom live classes
  static Future<Map<String, dynamic>> getZoomLiveClasses(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('liveclasses'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'student_id': studentId}); // Use correct parameter name as per API

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'live_classes',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load Zoom live classes: ${response.statusCode}',
          'live_classes': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading Zoom live classes: $e',
        'live_classes': [],
      };
    }
  }

  // Get Google Meet live classes
  static Future<Map<String, dynamic>> getGmeetLiveClasses(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('gmeetclasses'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'student_id': studentId}); // Use underscore as per API documentation

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'classes',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load Google Meet live classes: ${response.statusCode}',
          'classes': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading Google Meet live classes: $e',
        'classes': [],
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
