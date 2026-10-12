import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth_service.dart';
import '../../utils/url_manager.dart';
import '../../utils/dynamic_api_headers.dart';
import 'package:schoolapp/config/app_config.dart';

class AuthApi {
  // Get dynamic base URL from URL page settings
  static Future<String> getBaseUrl() async {
    final baseUrl = await UrlManager.getBaseUrl();
    if (baseUrl.isEmpty) {
      
      
      throw Exception('No base URL configured. Please set the URL in the URL page first.');
    }
    
    return baseUrl;
  }

  // Test method to check authentication
  static Future<void> testAuthentication() async {
    try {
      
      
      final token = await AuthService.getToken();
      final userId = await AuthService.getUserId();
      final baseUrl = await getBaseUrl();
      
      
      
      
      
      
      
      if (token != null && userId != null) {
        
        final headers = await DynamicApiHeaders.getCompleteHeaders();
        
        
        // Test with a simple API call
        final testUrl = Uri.parse('$baseUrl/api/webservice/getClassTimetable');
        final testBody = jsonEncode({'student_id': userId});
        
        final response = await http.post(
          testUrl,
          headers: headers,
          body: testBody,
        );
        
        
        
        
      }
    } catch (e) {
      
    }
  }

  // Force API mode - disable all static data fallbacks
  static Future<void> forceApiMode() async {
    try {
      
      
      // Test authentication only if URL is configured
      try {
        await testAuthentication();
        
        
      } catch (e) {
        
        
      }
    } catch (e) {
      
    }
  }

  // Helper method to make authenticated API calls
  static Future<Map<String, dynamic>> makeAuthenticatedCall(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final baseUrl = await getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/$endpoint');
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      
      
      
      
      

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      
      
      

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API call failed with status: ${response.statusCode}');
      }
    } catch (e) {
      
      rethrow;
    }
  }
  // Forgot Password API
  static Future<Map<String, dynamic>> forgotPassword(String email, {String usertype = 'student'}) async {
    try {
      final baseUrl = await getBaseUrl();
      // Ensure site_url has a trailing slash as per spec
      final siteUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
      
      // Exact endpoint from cURL: /api/webservice/forgot_password
      final url = Uri.parse('${siteUrl}api/webservice/forgot_password');
      
      // Specifically required headers for Forgot Password as per user provided cURL
      final headers = {
        'Auth-Key': AppConfig.authKey,
        'Client-Service': AppConfig.clientService,
        'Content-Type': AppConfig.contentType,
        'User-Agent': 'SmartSchool-Mobile/1.0',
        'Accept': 'application/json',
      };

      // Cookies is not required for forgot password and might cause 401 if invalid/expired

      final body = {
        'site_url': baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
        'email': email,
        'usertype': usertype,
      };

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      final responseData = jsonDecode(response.body);
      
      if (response.statusCode == 200) {
        return responseData;
      } else {
        // If the API returned a JSON with a message even on non-200 status, return it
        if (responseData is Map && (responseData.containsKey('message') || responseData.containsKey('error'))) {
          return responseData as Map<String, dynamic>;
        }
        throw Exception('Forgot password failed with status: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
