import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';
import '../utils/url_manager.dart';
import '../utils/response_validator.dart';
import 'notification_service.dart';

class AuthService {
  // Storage keys
  static const String _tokenKey = 'token';
  static const String _userIdKey = 'user_id';
  static const String _roleKey = 'role';
  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _studentNameKey = 'student_name';
  static const String _emailKey = 'email';
  static const String _classKey = 'class';
  static const String _imageKey = 'image';
  static const String _admissionNoKey = 'admission_no';
  static const String _sectionKey = 'section';
  static const String _studentIdKey = 'student_id';
  static const String _studentSessionIdKey = 'student_session_id';
  static const String _loginDataKey = 'login_data';
  static const String _parentChildsKey = 'parent_childs';

  // Centralized authentication configuration - using exact values from curl
  static Map<String, String> get _baseHeaders => {
    'Auth-Key': AppConfig.authKey,
    'Client-Service': AppConfig.clientService,
    'Content-Type': AppConfig.contentType,
  };

  // Get base authentication headers (without token/user-specific data)
  static Map<String, String> getBaseHeaders() {
    return Map.from(_baseHeaders);
  }

  // Get complete authentication headers with token and user ID
  static Future<Map<String, String>> getAuthHeaders() async {
    final token = await getToken();
    final userId = await getUserId();

    return {
      ..._baseHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': token,
      if (userId != null && userId.isNotEmpty) 'User-ID': userId,
    };
  }

  // Get authentication headers with specific user ID (for backward compatibility)
  static Future<Map<String, String>> getAuthHeadersWithUserId(
    String specificUserId,
  ) async {
    final token = await getToken();

    return {
      ..._baseHeaders,
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      'User-ID': specificUserId,
    };
  }

  // Get headers without Content-Type (for multipart requests)
  static Future<Map<String, String>> getAuthHeadersWithoutContentType() async {
    final token = await getToken();
    final userId = await getUserId();

    return {
      'Auth-Key': AppConfig.authKey,
      'Client-Service': AppConfig.clientService,
      if (token != null && token.isNotEmpty) 'Authorization': token,
      if (userId != null && userId.isNotEmpty) 'User-ID': userId,
    };
  }

  // Get complete headers with dynamic user_id and student_id from login
  static Future<Map<String, String>> getCompleteHeaders() async {
    final token = await getToken();
    final userId = await getUserId();
    final userProfile = await getUserProfile();
    final studentId = userProfile['student_id'];

    return {
      'Auth-Key': AppConfig.authKey,
      'Client-Service': AppConfig.clientService,
      'Content-Type': AppConfig.contentType,
      if (token != null && token.isNotEmpty) 'Authorization': token, // Use token directly, not Bearer
      if (userId != null && userId.isNotEmpty) 'User-ID': userId,
      if (studentId != null && studentId.isNotEmpty) 'Student-ID': studentId,
    };
  }

  // Get headers for specific API calls (like homework)
  static Future<Map<String, String>> getApiHeaders() async {
    final token = await getToken();
    final userId = await getUserId();

    
    
    

    return {
      'Auth-Key': AppConfig.authKey,
      'Client-Service': AppConfig.clientService,
      'Content-Type': AppConfig.contentType,
      if (token != null && token.isNotEmpty) 'Authorization': token, // Use token directly, not Bearer
      if (userId != null && userId.isNotEmpty) 'User-ID': userId,
    };
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    final userId = prefs.getString(_userIdKey);
    final isLoggedIn = prefs.getBool(_isLoggedInKey) ?? false;

    return token != null &&
        token.isNotEmpty &&
        userId != null &&
        userId.isNotEmpty &&
        isLoggedIn;
  }

  // Clear all session data (logout) - preserves URL configuration and branding
  static Future<void> clearSession() async {
    // Session clearing is now centrally managed in AppConfig to ensure branding persistence
    await AppConfig.clearAllConfiguration();
    
    // Additional session-specific cleanup
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('session_cookie');
    await prefs.remove('login_data');
    await prefs.remove('parent_childs');
  }

  // Get current user token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    
    return token;
  }

  // Get current user ID
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  // Get parent ID from stored login data
  static Future<String> getParentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loginData = prefs.getString(_loginDataKey);
      
      if (loginData != null) {
        final data = jsonDecode(loginData);
        final parentId = data['parent_id']?.toString() ?? data['id']?.toString();
        if (parentId != null && parentId.isNotEmpty) {
          
          return parentId;
        }
      }
      
      // Try to get from stored user ID as fallback
      final userId = await getUserId();
      if (userId != null && userId.isNotEmpty) {
        
        return userId;
      }
      
      // Last resort fallback
      
      return '2';
    } catch (e) {
      
      return '2'; // Last resort fallback
    }
  }

  // Debug method to check current URL configuration
  static Future<void> debugUrlConfiguration() async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      final apiUrl = await UrlManager.getApiUrl();
      final siteUrl = await UrlManager.getSiteUrl();

      
      
      
      

      if (baseUrl.isEmpty) {
        
      }
    } catch (e) {
      
    }
  }

  // Clear URL configuration (for debugging)
  static Future<void> clearUrlConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('base_url');
      await prefs.remove('api_url');
      await prefs.remove('site_url');
      
    } catch (e) {
      
    }
  }

  // Set correct URL configuration
  static Future<void> setCorrectUrlConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Get the URLs from user configuration instead of hardcoding
      final baseUrl = await UrlManager.getBaseUrl();
      final apiUrl = await UrlManager.getApiUrl();

      await prefs.setString('base_url', baseUrl);
      await prefs.setString('api_url', apiUrl);
      await prefs.setString('site_url', baseUrl);
      
      
      
      
    } catch (e) {
      
    }
  }

  // Test API connectivity
  static Future<Map<String, dynamic>> testApiConnectivity() async {
    try {
      final apiUrl = await UrlManager.getApiUrl();
      final baseUrl = await UrlManager.getBaseUrl();

      
      
      

      // Test base URL connectivity
      try {
        final baseResponse = await http.get(Uri.parse(baseUrl));
        
      } catch (e) {
        
      }

      // Test API URL connectivity
      try {
        final apiResponse = await http.get(Uri.parse(apiUrl));
        
      } catch (e) {
        
      }

      // Test app configuration endpoint
      try {
        final appConfigUrl = '$baseUrl/${AppConfig.appConfigEndpoint}';
        
        final appResponse = await http.get(Uri.parse(appConfigUrl));
        
        if (ResponseValidator.isHtmlResponse(appResponse.body)) {
          
        } else {
          
          
        }
      } catch (e) {
        
      }

      // Test common endpoints
      final testEndpoints = [
        '$baseUrl/login',
        '$baseUrl/auth/login',
        '$apiUrl/auth/login',
        '$baseUrl/api/login',
      ];

      for (final endpoint in testEndpoints) {
        try {
          final response = await http.get(Uri.parse(endpoint));
          
          if (ResponseValidator.isHtmlResponse(response.body)) {
            
          } else {
            
          }
        } catch (e) {
          
        }
      }

      return {'success': true, 'message': 'API connectivity test completed'};
    } catch (e) {
      return {'success': false, 'message': 'Connectivity test failed: $e'};
    }
  }

  // Login user
  static Future<Map<String, dynamic>> login(
    String username,
    String password,
  ) async {
    try {
      // Debug current URL configuration
      await debugUrlConfiguration();

      // Get dynamic API URL using UrlManager
      final apiUrl = await UrlManager.getApiUrl();
      final baseUrl = await UrlManager.getBaseUrl();

      
      
      
      

      // Try different login endpoints based on common patterns
      String loginEndpoint = '$apiUrl/auth/login';

      // First attempt: standard auth/login endpoint
      

      // Generate or get device token
      final deviceToken = await AppConfig.getDeviceToken();
      
      final response = await http.post(
        Uri.parse(loginEndpoint),
        headers: getBaseHeaders(),
        body: jsonEncode({
          'username': username,
          'password': password,
          'deviceToken': deviceToken,
        }),
      );

      
      
      
      

      // Check if response is HTML (error page)
      if (ResponseValidator.isHtmlResponse(response.body)) {
        
        

        // Try alternative endpoint: direct base URL + login
        final altEndpoint = '$baseUrl/login';
        

        try {
          // Use the same device token for alternative endpoint
          final altResponse = await http.post(
            Uri.parse(altEndpoint),
            headers: getBaseHeaders(),
            body: jsonEncode({
              'username': username,
              'password': password,
              'deviceToken': deviceToken,
            }),
          );

          
          
          

          if (altResponse.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(altResponse.body) &&
              altResponse.body.trim().isNotEmpty) {
            // Use alternative response
            try {
              final data = ResponseValidator.validateAndParseJsonMap(
                altResponse.body,
                'alternative login',
              );
              if (data['status'] == 1) {
                // Capture and save session cookie from alternative response
                final setCookieHeader = altResponse.headers['set-cookie'];
                if (setCookieHeader != null && setCookieHeader.isNotEmpty) {
                  final cookies = setCookieHeader.split(',');
                  if (cookies.isNotEmpty) {
                    final sessionCookie = cookies.first.trim();
                    await saveSessionCookie(sessionCookie);
                    
                  }
                }
                
                await _saveUserData(data);
                return {'success': true, 'data': data};
              } else {
                return {
                  'success': false,
                  'message': data['message'] ?? 'Login failed',
                };
              }
            } catch (parseError) {
              
              
            }
          }
        } catch (altError) {
          
        }

        return {'success': false, 'message': 'Login failed. Please try again.'};
      }

      // Try to parse JSON response
      if (response.body.trim().isEmpty) {
        
        return {
          'success': false,
          'message':
              'Server returned empty response. Please check your connection.',
        };
      }

      try {
        final data = ResponseValidator.validateAndParseJsonMap(
          response.body,
          'login',
        );

        if (response.statusCode == 200 && data['status'] == 1) {
          
          
          
          
          
          
          
          
          
          // Debug the record structure if it exists
          if (data['record'] != null) {
            
            
            
            
          } else {
            
          }
          
          // Capture and save session cookie from response headers
          final setCookieHeader = response.headers['set-cookie'];
          if (setCookieHeader != null && setCookieHeader.isNotEmpty) {
            // Extract the first cookie (usually the session cookie)
            final cookies = setCookieHeader.split(',');
            if (cookies.isNotEmpty) {
              final sessionCookie = cookies.first.trim();
              await saveSessionCookie(sessionCookie);
              
            }
          }
          
          // Save user data
          await _saveUserData(data);
          return {'success': true, 'data': data};
        } else {
          return {
            'success': false,
            'message': data['message'] ?? 'Login failed',
          };
        }
      } catch (parseError) {
        
        
        return {
          'success': false,
          'message': 'Invalid server response. Please try again.',
        };
      }
    } catch (e) {
      
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // Save user data after successful login
  static Future<void> _saveUserData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();

    final token = data['token'] ?? '';
    final userId = data['id'] ?? '';
    
    
    
    
    
    

    // Save token to both keys for compatibility
    await prefs.setString(_tokenKey, token); // 'token' - for AuthService
    await prefs.setString('auth_token', token); // 'auth_token' - for AppConfig
    await prefs.setString(_userIdKey, userId);
    await prefs.setString('user_id', userId); // Also save as 'user_id' for compatibility
    await prefs.setString(_roleKey, data['role'] ?? '');
    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_loginDataKey, jsonEncode(data)); // Save full login data

    // Try to get student_id from multiple possible locations
    String? studentId;
    if (data['record'] != null) {
      final record = data['record'];
      studentId = record['student_id'] ?? record['id'] ?? record['studentId'];
      
      
      
      
      
      
      
      
      await prefs.setString(_studentNameKey, record['username'] ?? '');
      await prefs.setString(_emailKey, record['email'] ?? '');
      await prefs.setString(_classKey, record['class'] ?? '');
      await prefs.setString(_imageKey, record['image'] ?? '');
      await prefs.setString(_admissionNoKey, record['admission_no'] ?? '');
      await prefs.setString(_sectionKey, record['section'] ?? '');
      await prefs.setString(
        _studentSessionIdKey,
        record['student_session_id']?.toString() ?? '',
      );

      // Save parent children if available
      if (record['parent_childs'] != null) {
        await saveParentChilds(record['parent_childs']);
      }
    }
    
    // Also check root level for student_id
    if (studentId == null || studentId.isEmpty) {
      studentId = data['student_id'] ?? data['studentId'] ?? data['id']?.toString();
      
    }
    
    // Fallback: use user_id as student_id if student_id is not found
    if (studentId == null || studentId.isEmpty) {
      studentId = userId;
      
    }
    
    // Save student_id
    if (studentId != null && studentId.isNotEmpty) {
      await prefs.setString(_studentIdKey, studentId);
      
    } else {
      
      
    }
    
    if (data['record'] != null) {
      
    } else {
      
    }
  }

  // Get list of parent children
  static Future<List<Map<String, dynamic>>> getParentChilds() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_parentChildsKey);
    if (data != null) {
      return List<Map<String, dynamic>>.from(jsonDecode(data));
    }
    return [];
  }

  // Save list of parent children
  static Future<void> saveParentChilds(List<dynamic> children) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_parentChildsKey, jsonEncode(children));
  }

  // Switch between children for a parent account
  static Future<void> switchChild(Map<String, dynamic> child) async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Sync individual profile keys (Fallback for simple modules)
    await prefs.setString(_studentNameKey, child['name'] ?? '');
    await prefs.setString(_classKey, child['class'] ?? '');
    await prefs.setString(_sectionKey, child['section'] ?? '');
    await prefs.setString(_studentIdKey, child['student_id']?.toString() ?? '');
    await prefs.setString(_studentSessionIdKey, child['student_session_id']?.toString() ?? '');
    await prefs.setString(_imageKey, child['image'] ?? '');
    await prefs.setString(_admissionNoKey, child['admission_no']?.toString() ?? '');
    
    // 2. CRITICAL: Sync full login_data JSON while preserving parent context
    String? loginDataStr = prefs.getString(_loginDataKey);
    
    // Fallback: If login_data is missing, try to reconstruct it from other available data
    if (loginDataStr == null || loginDataStr.isEmpty) {
      final role = prefs.getString(_roleKey) ?? 'parent';
      final token = prefs.getString(_tokenKey) ?? '';
      final userId = prefs.getString(_userIdKey) ?? '';
      
      // Construct a skeleton login_data
      final skeleton = {
        'status': 1,
        'role': role,
        'token': token,
        'id': userId,
        'record': {
          'parent_childs': jsonDecode(prefs.getString('parent_childs') ?? '[]')
        }
      };
      loginDataStr = jsonEncode(skeleton);
    }

    try {
      final loginData = jsonDecode(loginDataStr);
      final existingRecord = loginData['record'];
      
      // Preserve the parent_childs list so the user can switch again!
      // Check in the record first, then try the direct prefs key as fallback
      final dynamic rawChildren = (existingRecord != null && existingRecord['parent_childs'] != null)
          ? existingRecord['parent_childs']
          : jsonDecode(prefs.getString('parent_childs') ?? '[]');
      
      final List<dynamic>? parentChilds = rawChildren is List ? rawChildren : null;
      
      // Create the new record from the selected child
      final Map<String, dynamic> newRecord = Map<String, dynamic>.from(child);
      
      // Normalize schema names for the Student model
      newRecord['id'] = newRecord['student_id'];
      newRecord['firstname'] = newRecord['name'];
      
      // Re-attach the children list to the new record
      if (parentChilds != null) {
        newRecord['parent_childs'] = parentChilds;
      }
      
      // Update login_data
      loginData['record'] = newRecord;
      await prefs.setString(_loginDataKey, jsonEncode(loginData));
    } catch (e) {
      // Fallback already handled by individual keys above
    }
    
    // Re-register device token for the new student ID in the background (non-blocking)
    try {
      NotificationService.registerCurrentToken(force: true);
    } catch (e) {
    }
  }

  // Save session cookie from login response
  static Future<void> saveSessionCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    final existingCookies = prefs.getString('session_cookie') ?? '';
    
    if (existingCookies.isEmpty) {
      await prefs.setString('session_cookie', cookie);
      
    } else {
      // Parse individual cookies (semicolon + space separated)
      final List<String> cookieList = existingCookies.split(';').map((c) => c.trim()).where((c) => c.isNotEmpty).toList();
      
      // Extract the name= part to avoid duplicates for the same cookie name if intended
      // But based on user cURL, they have multiple ci_session keys.
      // So we should just check for exact duplicates of "key=value"
      if (!cookieList.contains(cookie.trim())) {
        cookieList.add(cookie.trim());
        final String newCookies = cookieList.join('; ');
        await prefs.setString('session_cookie', newCookies);
        
        
      } else {
        
      }
    }
  }

  // Logout user
  static Future<void> logout() async {
    // Clear all configuration except base URL and school branding
    await AppConfig.clearAllConfiguration();
  }

  // Get user profile data
  static Future<Map<String, String?>> getUserProfile() async {
    final prefs = await SharedPreferences.getInstance();

    return {
      'user_id': prefs.getString(_userIdKey),
      'student_name': prefs.getString(_studentNameKey),
      'email': prefs.getString(_emailKey),
      'class': prefs.getString(_classKey),
      'image': prefs.getString(_imageKey),
      'admission_no': prefs.getString(_admissionNoKey),
      'section': prefs.getString(_sectionKey),
      'student_id': prefs.getString(_studentIdKey),
      'student_session_id': prefs.getString(_studentSessionIdKey),
      'role': prefs.getString(_roleKey),
    };
  }

  // Get current user role
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_roleKey);
  }

  // Get student ID - DYNAMIC ONLY, NO STATIC FALLBACK
  // Returns empty string if not found (instead of throwing) so UI can handle it gracefully
  static Future<String> getStudentId() async {
    // Try AppConfig first (most reliable as it matches DynamicApiHeaders logic)
    final appConfigStudentId = await AppConfig.getStudentId();
    if (appConfigStudentId != null && appConfigStudentId.isNotEmpty) {
      
      return appConfigStudentId;
    }

    final prefs = await SharedPreferences.getInstance();
    final studentId = prefs.getString(_studentIdKey);
    
    
    
    
    
    
    if (studentId != null && studentId.isNotEmpty) {
      
      return studentId;
    } else {
      
      
      // Return empty string instead of throwing - let the API handle the error
      return '';
    }
  }

  // Get student session ID - DYNAMIC ONLY, NO STATIC FALLBACK
  static Future<String> getStudentSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_studentSessionIdKey);
    
    if (sessionId != null && sessionId.isNotEmpty) {
      
      return sessionId;
    } else {
      
      
      throw Exception('No student session ID found. Please login again.');
    }
  }

  // Get class ID from user profile
  static Future<String> getClassId() async {
    final prefs = await SharedPreferences.getInstance();
    final classId = prefs.getString(_classKey);
    if (classId == null || classId.isEmpty) {
      
      throw Exception('No class ID found. Please login again.');
    }
    return classId;
  }

  // Get section ID from user profile
  static Future<String> getSectionId() async {
    final prefs = await SharedPreferences.getInstance();
    final sectionId = prefs.getString(_sectionKey);
    if (sectionId == null || sectionId.isEmpty) {
      
      throw Exception('No section ID found. Please login again.');
    }
    return sectionId;
  }

  // Validate token
  static Future<bool> validateToken() async {
    try {
      final token = await getToken();
      final userId = await getUserId();

      if (token == null || userId == null) {
        return false;
      }

      final apiUrl = await UrlManager.getApiUrl();

      final response = await http.post(
        Uri.parse('$apiUrl/auth/validate'),
        headers: await getAuthHeaders(),
      );

      // Check if response is HTML (error page)
      if (ResponseValidator.isHtmlResponse(response.body)) {
        
        return false;
      }

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'auth/validate',
        );
        return ResponseValidator.isSuccessResponse(data);
      }

      return false;
    } catch (e) {
      
      return false;
    }
  }

  // Refresh token if needed
  static Future<bool> refreshTokenIfNeeded() async {
    try {
      final isValid = await validateToken();
      if (isValid) {
        return true; // Token is still valid
      }

      // Token is invalid, try to refresh
      

      // For now, we'll just return false and let the user login again
      // In a real app, you might implement token refresh logic here
      return false;
    } catch (e) {
      
      return false;
    }
  }

  // Get token with validation
  static Future<String?> getValidToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    // Check if token is still valid
    final isValid = await validateToken();
    if (!isValid) {
      
      return null;
    }

    return token;
  }
}
