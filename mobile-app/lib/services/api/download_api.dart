import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../auth_service.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';

class DownloadApi {
  // Get download links - Updated for Smart School API
  static Future<Map<String, dynamic>> getDownloadsLinks(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured',
          'data': [],
        };
      }

      final endpoint = '$baseUrl/api/webservice/getDownloadsLinks';
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Get class and section from user profile - DYNAMIC ONLY, NO STATIC FALLBACK
      final userProfile = await AuthService.getUserProfile();
      final classId = userProfile['class'];
      final sectionId = userProfile['section'];
      
      if (classId == null || classId.isEmpty) {
        
        throw Exception('No class ID found. Please login again.');
      }
      if (sectionId == null || sectionId.isEmpty) {
        
        throw Exception('No section ID found. Please login again.');
      }
      
      // Smart School API requires specific body format
      final body = jsonEncode({
        'role': 'student',
        'student_id': studentId,
        'classId': classId,
        'sectionId': sectionId,
        'user_parent_id': ''
      });

      
      
      

      final url = Uri.parse(endpoint);
      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        
        
        // Smart School API returns array directly, not wrapped in object
        final List<dynamic> data = jsonDecode(response.body);
        
        
        return {
          'status': 1,
          'message': 'Success',
          'data': data,
        };
      } else {
        
        return {
          'status': 0,
          'message': 'API call failed with status ${response.statusCode}',
          'data': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading download links: $e',
        'data': [],
      };
    }
  }

  // Get video tutorials - Updated for Smart School API
  static Future<Map<String, dynamic>> getVideoTutorial(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured',
          'result': [],
        };
      }

      final endpoint = '$baseUrl/api/webservice/getVideoTutorial';
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Get dynamic class and section from user profile - DYNAMIC ONLY, NO STATIC FALLBACK
      final userProfile = await AuthService.getUserProfile();
      final userClass = userProfile['class'];
      final userSection = userProfile['section'];
      
      if (userClass == null || userClass.isEmpty) {
        
        throw Exception('No class found. Please login again.');
      }
      if (userSection == null || userSection.isEmpty) {
        
        throw Exception('No section found. Please login again.');
      }
      
      // Convert user profile data to API format
      // Extract numeric class ID (e.g., "Class 1" -> "1", "Class 5" -> "5")
      final classId = userClass.replaceAll(RegExp(r'[^0-9]'), '');
      if (classId.isEmpty) {
        
        throw Exception('Invalid class format. Please login again.');
      }
      
      // Convert section to numeric format (e.g., "A" -> "1", "B" -> "2")
      // Use dynamic section value - NO STATIC FALLBACK
      final sectionId = userSection == 'A' ? '1' : userSection == 'B' ? '2' : userSection;
      if (sectionId.isEmpty) {
        
        throw Exception('Invalid section format. Please login again.');
      }
      
      
      
      
      
      
      // Smart School API requires specific body format as per specification
      final body = jsonEncode({
        'section_id': sectionId,
        'class_id': classId
      });

      
      
      

      final url = Uri.parse(endpoint);
      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        
        
        // Smart School API returns object with 'result' array
        final Map<String, dynamic> data = jsonDecode(response.body);
        final List<dynamic> result = data['result'] ?? [];
        
        
        return {
          'status': 1,
          'message': 'Success',
          'result': result,
        };
      } else {
        
        return {
          'status': 0,
          'message': 'API call failed with status ${response.statusCode}',
          'result': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading video tutorials: $e',
        'result': [],
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
