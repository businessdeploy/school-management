import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../services/auth_service.dart';

/// Dynamic API Headers
/// 
/// This utility ensures all APIs use dynamic credentials from the login session.
class DynamicApiHeaders {
  
  /// Get complete headers with dynamic credentials from login session
  static Future<Map<String, String>> getCompleteHeaders() async {
    try {
      
      // Get dynamic credentials from login session
      final token = await _getAuthToken();
      final userId = await _getUserId();
      final studentId = await _getStudentId();
      final sessionCookie = await _getSessionCookie();
      
      // Get dynamic credentials from config
      final authKey = await _getAuthKey();
      final clientService = await _getClientService();
      
      // Base headers with dynamic credentials
      final headers = <String, String>{
        'Auth-Key': authKey,
        'Client-Service': clientService,
        'Content-Type': 'application/json',
      };
      
      // Add dynamic authentication token (direct, no Bearer prefix)
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = token;
      }
      
      // Add dynamic user ID
      if (userId != null && userId.isNotEmpty) {
        headers['User-ID'] = userId;
      }
      
      // Add dynamic student ID
      if (studentId != null && studentId.isNotEmpty) {
        headers['Student-ID'] = studentId;
      }
      
      // Add session cookie
      if (sessionCookie != null && sessionCookie.isNotEmpty) {
        headers['Cookie'] = sessionCookie;
      }
      
      return headers;
    } catch (e) {
      
      return _getFallbackHeaders();
    }
  }
  
  /// Get authentication token from session (public method for debugging)
  static Future<String?> getAuthToken() async {
    return await _getAuthToken();
  }
  
  /// Get user ID from session (public method for debugging)
  static Future<String?> getUserId() async {
    return await _getUserId();
  }
  
  /// Get student ID from session (public method for debugging)
  static Future<String?> getStudentId() async {
    return await _getStudentId();
  }
  
  /// Get session cookie from session (public method for debugging)
  static Future<String?> getSessionCookie() async {
    return await _getSessionCookie();
  }
  
  /// Get authentication token from session
  static Future<String?> _getAuthToken() async {
    try {
      // Try AppConfig first (most reliable)
      final appConfigToken = await AppConfig.getAuthToken();
      if (appConfigToken != null && appConfigToken.isNotEmpty) {
        return appConfigToken;
      }
      
      // Fall back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsToken = prefs.getString('auth_token');
      if (prefsToken != null && prefsToken.isNotEmpty) {
        return prefsToken;
      }
      
      // Try AuthService
      final authServiceToken = await AuthService.getToken();
      if (authServiceToken != null && authServiceToken.isNotEmpty) {
        return authServiceToken;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Get user ID from session
  static Future<String?> _getUserId() async {
    try {
      // Try AppConfig first
      final appConfigUserId = await AppConfig.getUserId();
      if (appConfigUserId != null && appConfigUserId.isNotEmpty) {
        return appConfigUserId;
      }
      
      // Fall back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsUserId = prefs.getString('user_id');
      if (prefsUserId != null && prefsUserId.isNotEmpty) {
        return prefsUserId;
      }
      
      // Try AuthService
      final authServiceUserId = await AuthService.getUserId();
      if (authServiceUserId != null && authServiceUserId.isNotEmpty) {
        return authServiceUserId;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Get student ID from session
  static Future<String?> _getStudentId() async {
    try {
      // Try AppConfig first
      final appConfigStudentId = await AppConfig.getStudentId();
      if (appConfigStudentId != null && appConfigStudentId.isNotEmpty) {
        return appConfigStudentId;
      }
      
      // Fall back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsStudentId = prefs.getString('student_id');
      if (prefsStudentId != null && prefsStudentId.isNotEmpty) {
        return prefsStudentId;
      }
      
      // Try AuthService
      final userProfile = await AuthService.getUserProfile();
      final authServiceStudentId = userProfile['student_id'];
      if (authServiceStudentId != null && authServiceStudentId.isNotEmpty) {
        return authServiceStudentId;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Get session cookie from session
  static Future<String?> _getSessionCookie() async {
    try {
      // Try AppConfig first
      final appConfigCookie = await AppConfig.getSessionCookie();
      if (appConfigCookie != null && appConfigCookie.isNotEmpty) {
        return appConfigCookie;
      }
      
      // Fall back to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsCookie = prefs.getString('session_cookie');
      if (prefsCookie != null && prefsCookie.isNotEmpty) {
        return prefsCookie;
      }
      
      return null;
    } catch (e) {
      
      return null;
    }
  }
  
  /// Get fallback headers when no session data is available
  static Map<String, String> _getFallbackHeaders() {
    return {
      'Auth-Key': AppConfig.authKey,
      'Client-Service': AppConfig.clientService,
      'Content-Type': 'application/json',
    };
  }
  
  /// Validate that all required headers are present
  static Future<Map<String, dynamic>> validateHeaders() async {
    try {
      final headers = await getCompleteHeaders();
      
      final hasAuthKey = headers.containsKey('Auth-Key');
      final hasClientService = headers.containsKey('Client-Service');
      final hasContentType = headers.containsKey('Content-Type');
      final hasAuthorization = headers.containsKey('Authorization');
      final hasUserId = headers.containsKey('User-ID');
      final hasStudentId = headers.containsKey('Student-ID');
      final hasCookie = headers.containsKey('Cookie');
      
      final allRequired = hasAuthKey && hasClientService && hasContentType;
      final hasAuth = hasAuthorization && hasUserId;
      final hasStudent = hasStudentId;
      final hasSession = hasCookie;
      
      return {
        'success': allRequired,
        'has_required': allRequired,
        'has_auth': hasAuth,
        'has_student': hasStudent,
        'has_session': hasSession,
        'headers': headers,
        'missing': <String>[
          if (!hasAuthKey) 'Auth-Key',
          if (!hasClientService) 'Client-Service',
          if (!hasContentType) 'Content-Type',
          if (!hasAuthorization) 'Authorization',
          if (!hasUserId) 'User-ID',
          if (!hasStudentId) 'Student-ID',
          if (!hasCookie) 'Cookie',
        ],
      };
    } catch (e) {
      
      return {
        'success': false,
        'error': e.toString(),
        'headers': <String, String>{},
        'missing': <String>['All headers'],
      };
    }
  }
  
  /// Get debug information about headers
  static Future<Map<String, dynamic>> getHeaderDebugInfo() async {
    try {
      final headers = await getCompleteHeaders();
      final validation = await validateHeaders();
      
      return {
        'timestamp': DateTime.now().toIso8601String(),
        'headers': headers,
        'validation': validation,
        'recommendations': <String>[
          if (!validation['has_auth']) 'Login to the app to get authentication headers',
          if (!validation['has_student']) 'Ensure student ID is set after login',
          if (!validation['has_session']) 'Check if session cookie is being set',
        ],
      };
    } catch (e) {
      
      return {
        'error': e.toString(),
        'headers': <String, String>{},
        'validation': {'success': false, 'error': e.toString()},
        'recommendations': ['Check app configuration and login status'],
      };
    }
  }
  
  /// Get dynamic Auth-Key from config
  static Future<String> _getAuthKey() async {
    try {
      // Try to get from stored login data first
      final prefs = await SharedPreferences.getInstance();
      final loginData = prefs.getString('login_data');
      
      if (loginData != null) {
        final data = jsonDecode(loginData);
        final authKey = data['auth_key']?.toString();
        if (authKey != null && authKey.isNotEmpty) {
          return authKey;
        }
      }
      
      // Fallback to config
      final authKey = AppConfig.authKey;
      return authKey;
    } catch (e) {
      
      return AppConfig.authKey;
    }
  }
  
  /// Get dynamic Client-Service from config
  static Future<String> _getClientService() async {
    try {
      // Try to get from stored login data first
      final prefs = await SharedPreferences.getInstance();
      final loginData = prefs.getString('login_data');
      
      if (loginData != null) {
        final data = jsonDecode(loginData);
        final clientService = data['client_service']?.toString();
        if (clientService != null && clientService.isNotEmpty) {
          return clientService;
        }
      }
      
      // Fallback to config
      final clientService = AppConfig.clientService;
      return clientService;
    } catch (e) {
      
      return AppConfig.clientService;
    }
  }
}
