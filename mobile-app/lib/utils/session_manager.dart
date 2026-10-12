import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

/// Session Management Utility
/// 
/// This utility demonstrates how the school URL and other session data
/// are properly managed using the common configuration system.
class SessionManager {
  
  /// Initialize session with school URL
  /// This is called when user enters URL on the URL page
  static Future<bool> initializeSession(String schoolUrl) async {
    try {
      
      // Save the school URL to session
      final success = await AppConfig.setBaseUrl(schoolUrl);
      
      if (success) {
        return true;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
  
  /// Get current session information
  static Future<Map<String, dynamic>> getSessionInfo() async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      final schoolName = await AppConfig.getSchoolName();
      final authToken = await AppConfig.getAuthToken();
      final userId = await AppConfig.getUserId();
      final studentId = await AppConfig.getStudentId();
      
      return {
        'base_url': baseUrl,
        'school_name': schoolName,
        'is_authenticated': authToken != null && authToken.isNotEmpty,
        'user_id': userId,
        'student_id': studentId,
        'session_active': baseUrl.isNotEmpty,
      };
    } catch (e) {
      return {
        'base_url': '',
        'school_name': 'Government Higher Secondary School Sarna',
        'is_authenticated': false,
        'user_id': null,
        'student_id': null,
        'session_active': false,
      };
    }
  }
  
  /// Check if session is active (has school URL)
  static Future<bool> isSessionActive() async {
    try {
      final baseUrl = await AppConfig.getBaseUrl();
      return baseUrl.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get school URL from session
  static Future<String> getSchoolUrl() async {
    try {
      return await AppConfig.getBaseUrl();
    } catch (e) {
      return '';
    }
  }
  
  /// Update session with authentication data
  static Future<bool> updateSessionWithAuth({
    required String token,
    required String userId,
    String? studentId,
  }) async {
    try {
      
      // Save authentication data to session
      await AppConfig.setAuthToken(token);
      await AppConfig.setUserId(userId);
      
      if (studentId != null) {
        await AppConfig.setStudentId(studentId);
      }
      
      if (studentId != null) {
        await AppConfig.setStudentId(studentId);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear session (logout) but preserve school URL
  static Future<bool> clearSession() async {
    try {
      
      // Get school URL before clearing
      final schoolUrl = await AppConfig.getBaseUrl();
      
      // Clear all session data except school URL
      await AppConfig.clearAllConfiguration();
      
      // Restore school URL
      if (schoolUrl.isNotEmpty) {
        await AppConfig.setBaseUrl(schoolUrl);
      }
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Validate session integrity
  static Future<bool> validateSession() async {
    try {
      final sessionInfo = await getSessionInfo();
      
      if (!sessionInfo['session_active']) {
        return false;
      }
      
      return true;
      
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get API endpoint URL from session
  static Future<String> getApiEndpoint(String endpoint) async {
    try {
      return await AppConfig.getApiEndpoint(endpoint);
    } catch (e) {
      return '';
    }
  }
  
  /// Get complete headers for API calls from session
  static Future<Map<String, String>> getApiHeaders() async {
    try {
      return await AppConfig.getCompleteHeaders();
    } catch (e) {
      return AppConfig.baseHeaders;
    }
  }
}
