import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class AppConfig {

  /// Authentication credentials
  static const String authKey = 'schoolAdmin@';
  static const String clientService = 'smartschool';
  static const String contentType = 'application/json';
  
  /// Set skip to 'yes' to bypass the URL entry page and use skipUrl
  static const String skip = 'yes'; // 'yes' or 'no'
  static const String skipUrl = 'https://ghss-sarna.manage-school-crm.4d68er.easypanel.host';
  
  /// Set adminEnabled to true to show the admin URL button in login section
  static const bool adminEnabled = true; //true or false
  static const String adminUrl = 'https://ghss-sarna.manage-school-crm.4d68er.easypanel.host/site/login'; 
  
  /// API Endpoints
  static const String authValidateEndpoint = 'auth/validate';
  static const String authLoginEndpoint = 'auth/login';
  static const String authLogoutEndpoint = 'auth/logout';
  static const String appConfigEndpoint = 'app';
  
  /// HTTP Configuration
  static const Duration requestTimeout = Duration(seconds: 30);
  static const int maxRetries = 3;
  
  /// Response Keys
  static const String successStatusKey = 'status';
  static const String successMessageKey = 'message';
  static const String dataKey = 'data';
  
  /// Error Messages
  static const String networkErrorMessage = 'Network error. Please check your connection.';
  static const String serverErrorMessage = 'Server error. Please try again later.';
  static const String authenticationErrorMessage = 'Authentication failed. Please login again.';
  static const String notificationConfigAsset = 'assets/config/notification_config.json';
  
  /// Bearer token prefix
  static const String bearerPrefix = 'Bearer ';
  
  /// Header Keys
  static const String userIdHeaderKey = 'User-ID';
  static const String studentIdHeaderKey = 'Student-ID';
  
  // ============================================================================
  // SHARED PREFERENCES KEYS
  // ============================================================================
  
  static const String _baseUrlKey = 'base_url';
  static const String _appLogoKey = 'app_logo';
  static const String _schoolNameKey = 'school_name';
  static const String _primaryColorKey = 'primary_color';
  static const String _secondaryColorKey = 'secondary_color';
  static const String _langCodeKey = 'lang_code';
  static const String _currencyKey = 'currency';
  static const String _appVersionKey = 'app_version';
  static const String _authTokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _studentIdKey = 'student_id';
  static const String _sessionCookieKey = 'session_cookie';
  static const String _deviceTokenKey = 'device_token';
  static const String _dateFormatKey = 'date_format';
  static const String _languagesKey = 'languages';
  static const String _schoolAddressKey = 'school_address';
  static const String _schoolPhoneKey = 'school_phone';
  static const String _schoolEmailKey = 'school_email';
  static const String _schoolCodeKey = 'school_code';
  static const String _currentSessionKey = 'current_session';
  static const String _sessionStartMonthKey = 'session_start_month';
  
  // ============================================================================
  // DYNAMIC URL MANAGEMENT
  // ============================================================================
  
  /// Get the configured base URL
  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String baseUrl = prefs.getString(_baseUrlKey) ?? '';
      
      if (baseUrl.isEmpty) {
        // Fallback: literal check
        baseUrl = prefs.getString('base_url') ?? '';
      }

      if (baseUrl.isEmpty) {
        // Check if skip URL logic is enabled
        if (skip == 'yes' && skipUrl.isNotEmpty) {
          baseUrl = skipUrl;
          await prefs.setString(_baseUrlKey, baseUrl);
        } else {
          return '';
        }
      }
      
      // Normalize the URL
      String normalizedUrl = baseUrl.trim();
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      if (normalizedUrl.endsWith('/api')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 4);
      }
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      
      return normalizedUrl;
    } catch (e) {
      return '';
    }
  }

  static Future<String> getAppLogo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String logoPath = (prefs.getString(_appLogoKey) ?? '').trim();
      
      if (logoPath.isEmpty || logoPath == 'null') {
        logoPath = (prefs.getString('app_logo') ?? '').trim();
      }

      if (logoPath.isNotEmpty && logoPath != 'null') {
        if (logoPath.startsWith('http')) return logoPath;

        final baseUrl = await getBaseUrl();
        if (baseUrl.isEmpty) return logoPath;

        String cleanBase = baseUrl.trim();
        while (cleanBase.endsWith('/')) {
          cleanBase = cleanBase.substring(0, cleanBase.length - 1);
        }
        if (cleanBase.endsWith('/api')) {
          cleanBase = cleanBase.substring(0, cleanBase.length - 4);
        }
        while (cleanBase.endsWith('/')) {
          cleanBase = cleanBase.substring(0, cleanBase.length - 1);
        }

        String cleanPath = logoPath.trim().replaceAll('\\', '/');
        while (cleanPath.startsWith('/')) {
          cleanPath = cleanPath.substring(1);
        }
        
        if (cleanPath.startsWith('uploads/')) {
          cleanPath = cleanPath.substring(8);
        }

        if (cleanPath.contains('school_content/logo/app_logo/')) {
          return '$cleanBase/uploads/$cleanPath';
        }
        if (cleanPath.contains('school_content/admin_logo/')) {
          return '$cleanBase/uploads/$cleanPath';
        }
        if (!cleanPath.contains('/')) {
          return '$cleanBase/uploads/school_content/logo/app_logo/$cleanPath';
        }
        
        return '$cleanBase/uploads/$cleanPath';
      }
      return '';
    } catch (e) {
      return '';
    }
  }
  
  /// Set the base URL with normalization
  static Future<bool> setBaseUrl(String url) async {
    try {
      String normalizedUrl = url.trim();
      
      // Remove trailing slash first
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      
      // Remove /api or /api/ suffix if present
      if (normalizedUrl.endsWith('/api')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 4);
      }
      
      // Remove trailing slash again if it was behind /api
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      
      if (normalizedUrl.isEmpty) {
        
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_baseUrlKey, normalizedUrl);
      if (result) {
        
      } else {
        
      }
      return result;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Clear the base URL
  static Future<bool> clearBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_baseUrlKey);
      if (result) {
        
      } else {
        
      }
      return result;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get API URL
  static Future<String> getApiUrl() async {
    final baseUrl = await getBaseUrl();
    return '$baseUrl/api';
  }
  
  /// Get site URL
  static Future<String> getSiteUrl() async {
    return await getBaseUrl();
  }
  
  /// Get site asset URL
  static Future<String> getSiteAsset(String assetPath) async {
    final baseUrl = await getBaseUrl();
    return '$baseUrl/uploads/$assetPath';
  }
  
  /// Get full API endpoint URL
  static Future<String> getApiEndpoint(String endpoint) async {
    String baseUrl = await getBaseUrl();
    if (baseUrl.isEmpty) {
      return '';
    }
    // Remove trailing slash if present for consistent construction
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return '$baseUrl/api/webservice/$endpoint';
  }
  
  /// Get app configuration endpoint URL
  static Future<String> getAppConfigUrl() async {
    String baseUrl = await getBaseUrl();
    // Remove trailing slash if present
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return '$baseUrl/$appConfigEndpoint';
  }
  
  // ============================================================================
  // CREDENTIALS & AUTHENTICATION
  // ============================================================================
  
  /// Get base headers for API requests
  static Map<String, String> get baseHeaders => {
    'Auth-Key': authKey,
    'Client-Service': clientService,
    'Content-Type': contentType,
  };
  
  /// Get complete headers with authentication
  static Future<Map<String, String>> getCompleteHeaders() async {
    final headers = Map<String, String>.from(baseHeaders);
    
    // Add authentication token if available
    final token = await getAuthToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = '$bearerPrefix$token';
    }
    
    // Add user ID if available
    final userId = await getUserId();
    if (userId != null && userId.isNotEmpty) {
      headers[userIdHeaderKey] = userId;
    }
    
    // Add student ID if available
    final studentId = await getStudentId();
    if (studentId != null && studentId.isNotEmpty) {
      headers[studentIdHeaderKey] = studentId;
    }
    
    // Add session cookie if available
    final cookie = await getSessionCookie();
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    
    return headers;
  }
  
  /// Get authentication token
  static Future<String?> getAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_authTokenKey);
    } catch (e) {
      
      return null;
    }
  }
  
  /// Set authentication token
  static Future<bool> setAuthToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_authTokenKey, token);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Clear authentication token
  static Future<bool> clearAuthToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_authTokenKey);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get user ID
  static Future<String?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      
      return null;
    }
  }
  
  /// Set user ID
  static Future<bool> setUserId(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_userIdKey, userId);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get student ID
  static Future<String?> getStudentId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_studentIdKey);
    } catch (e) {
      
      return null;
    }
  }
  
  /// Set student ID
  static Future<bool> setStudentId(String studentId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_studentIdKey, studentId);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get session cookie
  static Future<String?> getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_sessionCookieKey);
    } catch (e) {
      
      return null;
    }
  }
  
  /// Set session cookie
  static Future<bool> setSessionCookie(String cookie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_sessionCookieKey, cookie);
    } catch (e) {
      
      return false;
    }
  }

  // ============================================================================
  // DEVICE TOKEN MANAGEMENT
  // ============================================================================

  /// Generate a unique device token
  static String generateDeviceToken() {
    // Generate a unique token using timestamp and random string
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = (timestamp * 1000 + (timestamp % 1000)).toString();
    // Create a base64-like string (simplified)
    final token = 'DT${timestamp.toString().substring(0, 10)}${random.substring(0, 6)}';
    
    return token;
  }

  /// Get device token (generates new one if not exists)
  static Future<String> getDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? token = prefs.getString(_deviceTokenKey);
      
      if (token == null || token.isEmpty) {
        // Generate new token if not exists
        token = generateDeviceToken();
        await prefs.setString(_deviceTokenKey, token);
        
      } else {
        
      }
      
      return token;
    } catch (e) {
      
      // Fallback to generated token
      return generateDeviceToken();
    }
  }

  /// Set device token
  static Future<bool> setDeviceToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.setString(_deviceTokenKey, token);
      if (result) {
        
      }
      return result;
    } catch (e) {
      
      return false;
    }
  }

  /// Clear device token
  static Future<bool> clearDeviceToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_deviceTokenKey);
    } catch (e) {
      
      return false;
    }
  }
  
  // ============================================================================
  // APP CONFIGURATION (LOGO, COLORS, ETC.)
  // ============================================================================
  
  /// Set app logo
  static Future<bool> setAppLogo(String logoPath) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_appLogoKey, logoPath);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get school name (from API only, no defaults)
  static Future<String> getSchoolName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_schoolNameKey) ?? '';
    } catch (e) {
      
      return '';
    }
  }
  
  /// Set school name
  static Future<bool> setSchoolName(String name) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_schoolNameKey, name);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get primary color (from API only, no defaults)
  static Future<String> getPrimaryColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_primaryColorKey) ?? '';
    } catch (e) {
      
      return '';
    }
  }
  
  /// Set primary color
  static Future<bool> setPrimaryColor(String color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_primaryColorKey, color);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get secondary color (from API only, no defaults)
  static Future<String> getSecondaryColor() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_secondaryColorKey) ?? '';
    } catch (e) {
      
      return '';
    }
  }
  
  /// Set secondary color
  static Future<bool> setSecondaryColor(String color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_secondaryColorKey, color);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get language code
  static Future<String> getLangCode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_langCodeKey) ?? 'en';
    } catch (e) {
      
      return 'en';
    }
  }
  
  /// Set language code
  static Future<bool> setLangCode(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_langCodeKey, code);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get currency
  static Future<String> getCurrency() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_currencyKey) ?? '';
    } catch (e) {
      
      return '';
    }
  }

  /// Get languages list
  static Future<List<Map<String, dynamic>>> getLanguages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languagesJson = prefs.getString(_languagesKey);
      
      if (languagesJson != null && languagesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(languagesJson);
        return decoded.map((e) => Map<String, dynamic>.from(e)).toList();
      }
      return [];
    } catch (e) {
      
      return [];
    }
  }
  
  /// Set currency
  static Future<bool> setCurrency(String currency) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_currencyKey, currency);
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get app version
  static Future<String> getAppVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_appVersionKey) ?? '5.0';
    } catch (e) {
      
      return '5.0';
    }
  }
  
  /// Set app version
  static Future<bool> setAppVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_appVersionKey, version);
    } catch (e) {
      
      return false;
    }
  }

  /// Get date format
  static Future<String> getDateFormat() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_dateFormatKey) ?? 'dd/MM/yyyy';
    } catch (e) {
      
      return 'dd/MM/yyyy';
    }
  }

  /// Set date format
  static Future<bool> setDateFormat(String format) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_dateFormatKey, format);
    } catch (e) {
      
      return false;
    }
  }
  
  // ============================================================================
  // BULK CONFIGURATION MANAGEMENT
  // ============================================================================
  
  /// Save complete app configuration
  static Future<bool> saveAppConfiguration(Map<String, dynamic> config) async {
    try {
      // CRITICAL: Only save if status is 1 (success)
      // This prevents overwriting valid settings with empty ones when an API call fails
      final status = config['status'];
      final isSuccess = status == 1 || status == '1' || status == true;
      
      if (!isSuccess) {
        if (kDebugMode) {
          
        }
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      
      // Extract logo value - check multiple possible keys
      String logoValue = config['app_logo']?.toString() ?? '';
      if (logoValue.isEmpty) {
        // Try alternative keys
        final altKeys = ['logo', 'school_logo', 'institute_logo', 'institution_logo', 'logo_url', 'app_logo_url'];
        for (String key in altKeys) {
          if (config.containsKey(key) && 
              config[key] != null && 
              config[key].toString().isNotEmpty &&
              config[key].toString().toLowerCase() != 'null') {
            logoValue = config[key].toString();
            
            break;
          }
        }
      }
      
      // Save logo ONLY if it's not empty, or if we have no logo saved yet
      final existingLogo = prefs.getString(_appLogoKey) ?? '';
      if (logoValue.isNotEmpty) {
        await prefs.setString(_appLogoKey, logoValue);
      } else if (existingLogo.isEmpty) {
        await prefs.setString(_appLogoKey, '');
      }

      // Save school name
      final schoolName = config['school_name']?.toString() ?? '';
      if (schoolName.isNotEmpty) {
        await prefs.setString(_schoolNameKey, schoolName);
      }

      // Save colors - check correct keys
      String primaryColorValue = config['primary_color']?.toString() ?? '';
      if (primaryColorValue.isEmpty || primaryColorValue.toLowerCase() == 'null') {
        primaryColorValue = config['app_primary_color_code']?.toString() ?? '';
      }
      
      if (primaryColorValue.isNotEmpty) {
        await prefs.setString(_primaryColorKey, primaryColorValue);
      }

      String secondaryColorValue = config['secondary_color']?.toString() ?? '';
      if (secondaryColorValue.isEmpty || secondaryColorValue.toLowerCase() == 'null') {
        secondaryColorValue = config['app_secondary_color_code']?.toString() ?? '';
      }

      if (secondaryColorValue.isNotEmpty) {
        await prefs.setString(_secondaryColorKey, secondaryColorValue);
      }

      if (config['lang_code'] != null && config['lang_code'].toString().isNotEmpty) {
        await prefs.setString(_langCodeKey, config['lang_code'].toString());
      }
      
      // Save currency
      String currencyCode = config['currency']?.toString() ?? '';
      String currencySymbol = config['currency_symbol']?.toString() ?? '';
      String finalCurrency = currencyCode.isNotEmpty ? currencyCode : currencySymbol;
      if (finalCurrency.isNotEmpty) {
        await prefs.setString(_currencyKey, finalCurrency);
      }
      
      String version = config['app_version']?.toString() ?? config['app_ver']?.toString() ?? config['mobile_app_version']?.toString() ?? '';
      if (version.isNotEmpty) {
        await prefs.setString(_appVersionKey, version);
      }

      if (config['date_format'] != null && config['date_format'].toString().isNotEmpty) {
        await prefs.setString(_dateFormatKey, config['date_format'].toString());
      }
      
      // Save additional school info
      if (config['address'] != null || config['school_address'] != null) {
        await prefs.setString(_schoolAddressKey, config['address']?.toString() ?? config['school_address']?.toString() ?? '');
      }
      if (config['phone'] != null || config['school_phone'] != null) {
        await prefs.setString(_schoolPhoneKey, config['phone']?.toString() ?? config['school_phone']?.toString() ?? '');
      }
      if (config['email'] != null || config['school_email'] != null) {
        await prefs.setString(_schoolEmailKey, config['email']?.toString() ?? config['school_email']?.toString() ?? '');
      }
      if (config['school_code'] != null) {
        await prefs.setString(_schoolCodeKey, config['school_code']?.toString() ?? '');
      }
      if (config['session'] != null || config['current_session'] != null) {
        await prefs.setString(_currentSessionKey, config['session']?.toString() ?? config['current_session']?.toString() ?? '');
      }
      if (config['start_month'] != null) {
        await prefs.setString(_sessionStartMonthKey, config['start_month']?.toString() ?? '');
      }
      
      // Store languages list if present
      if (config.containsKey('languages') && config['languages'] is List) {
        await prefs.setString(_languagesKey, jsonEncode(config['languages']));
      }

      // Update base URL if provided
      String? newBaseUrl;
      if (config.containsKey('site_url') && config['site_url'].toString().isNotEmpty) {
        newBaseUrl = config['site_url'].toString();
      } else if (config.containsKey('url') && config['url'].toString().isNotEmpty) {
        newBaseUrl = config['url'].toString();
        // Remove trailing /api/ or /api if present
        if (newBaseUrl.endsWith('/api/')) {
          newBaseUrl = newBaseUrl.substring(0, newBaseUrl.length - 5);
        } else if (newBaseUrl.endsWith('/api')) {
          newBaseUrl = newBaseUrl.substring(0, newBaseUrl.length - 4);
        }
      }

      if (newBaseUrl != null && newBaseUrl.isNotEmpty) {
        // Ensure no trailing slash for consistency
        if (newBaseUrl.endsWith('/')) {
          newBaseUrl = newBaseUrl.substring(0, newBaseUrl.length - 1);
        }
        
        final currentBaseUrl = prefs.getString(_baseUrlKey) ?? '';
        if (newBaseUrl != currentBaseUrl) {
          await setBaseUrl(newBaseUrl);
        }
      }
      
      
      
      
      
      
      
      
      
      // Verify logo was saved
      final savedLogo = prefs.getString(_appLogoKey);
      
      
      return true;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Clear all configuration (logout)
  static Future<bool> clearAllConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear only user session data, preserve school branding and identity
      // DO NOT REMOVE: _langCodeKey, _currencyKey, _appVersionKey, _deviceTokenKey, _baseUrlKey, _appLogoKey, _schoolNameKey, etc.
      await prefs.remove(_authTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_studentIdKey);
      await prefs.remove(_sessionCookieKey);
      await prefs.remove('login_data'); // Also clear the full login data cache
      await prefs.remove('parent_childs'); // Clear children list
      
      
      return true;
    } catch (e) {
      
      return false;
    }
  }
  
  /// Get all current configuration
  static Future<Map<String, dynamic>> getAllConfiguration() async {
    try {
      return {
        'base_url': await getBaseUrl(),
        'app_logo': await getAppLogo(),
        'school_name': await getSchoolName(),
        'primary_color': await getPrimaryColor(),
        'secondary_color': await getSecondaryColor(),
        'lang_code': await getLangCode(),
        'currency': await getCurrency(),
        'app_version': await getAppVersion(),
        'auth_token': await getAuthToken(),
        'user_id': await getUserId(),
        'student_id': await getStudentId(),
      };
    } catch (e) {
      
      return {};
    }
  }
}
