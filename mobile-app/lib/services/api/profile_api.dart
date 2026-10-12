import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';

class ProfileApi {
  static Future<String> get baseUrl async => await AppConfig.getBaseUrl();

  // Get student profile data using getStudentProfile API
  static Future<Map<String, dynamic>> getUserProfile() async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Get student ID from authentication
      final studentId = await AuthService.getStudentId();
      
      
      
      
      
      final response = await http.post(
        Uri.parse('${await baseUrl}/api/webservice/getStudentProfile'),
        headers: headers,
        body: jsonEncode({
          'student_id': studentId,
          'user_type': 'student',
        }),
      );

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      
      rethrow;
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final base = await baseUrl;
      
      // Try multiple potential endpoints to resolve 404 issues
      final endpoints = [
        '$base/api/webservice/updateProfile',
        '$base/api/webservice/saveStudentProfile',
        '$base/api/webservice/editProfile',
        '$base/api/webservice/updateStudentProfile',
        '$base/api/webservice/setStudentProfile',
        '$base/api/webservice/editStudentProfile',
        // Add lowercase variations
        '$base/api/webservice/update_student_profile',
        '$base/api/webservice/update_profile',
        '$base/api/webservice/save_student_profile',
        '$base/api/webservice/edit_student_profile',
      ];

      http.Response? lastResponse;

      for (String url in endpoints) {
        try {
          
          final response = await http.post(
            Uri.parse(url),
            headers: headers,
            body: jsonEncode(profileData),
          );

          
          lastResponse = response;

          if (response.statusCode == 200) {
            
            return jsonDecode(response.body);
          }
        } catch (e) {
          
        }
      }

      if (lastResponse != null) {
        throw Exception('Failed to update profile after trying multiple endpoints. Last status: ${lastResponse.statusCode}');
      } else {
        throw Exception('Failed to reach any profile update endpoints.');
      }
    } catch (e) {
      
      rethrow;
    }
  }

  // Change password
  static Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final response = await http.post(
        Uri.parse('${await baseUrl}/api/webservice/changePassword'),
        headers: headers,
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to change password: ${response.statusCode}');
      }
    } catch (e) {
      
      rethrow;
    }
  }

  // Forgot password
  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final baseUrlStr = await baseUrl;
      
      // Use the correct endpoint for forgot password
      final url = Uri.parse('$baseUrlStr/api/forgot_password');
      
      
      
      
      
      final body = {
        'email': email,
        'usertype': 'student', // Default to student as per requirement
        'site_url': baseUrlStr, // Pass base URL as site_url
      };
      
      
      
      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        // Handle 404 or other errors gracefully
        if (response.statusCode == 404) {
           throw Exception('Forgot password service not found (404)');
        }
        throw Exception('Failed to send reset email: ${response.statusCode}');
      }
    } catch (e) {
      
      rethrow;
    }
  }

  // Reset password with token
  static Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final response = await http.post(
        Uri.parse('${await baseUrl}/api/webservice/resetPassword'),
        headers: headers,
        body: jsonEncode({
          'token': token,
          'new_password': newPassword,
          'confirm_password': confirmPassword,
        }),
      );

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        throw Exception('Failed to reset password: ${response.statusCode}');
      }
    } catch (e) {
      
      rethrow;
    }
  }
}
