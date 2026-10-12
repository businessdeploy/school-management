import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../utils/url_manager.dart';

/// API validation utility for checking API configuration and connectivity
class ApiValidator {
  static const String _tag = '🔍 API Validator';
  
  /// Validate all API requirements
  static Future<Map<String, dynamic>> validateApiSetup() async {
    
    final List<Map<String, dynamic>> validations = [];
    
    // Check base URL
    final baseUrlValidation = await _validateBaseUrl();
    validations.add(baseUrlValidation);
    
    // Check authentication
    final authValidation = await _validateAuthentication();
    validations.add(authValidation);
    
    // Check student ID
    final studentIdValidation = await _validateStudentId();
    validations.add(studentIdValidation);
    
    // Check headers
    final headersValidation = await _validateHeaders();
    validations.add(headersValidation);
    
    // Calculate overall status
    final successCount = validations.where((v) => v['success'] == true).length;
    final overallSuccess = successCount == validations.length;
    
    return {
      'success': overallSuccess,
      'total_validations': validations.length,
      'passed_validations': successCount,
      'failed_validations': validations.length - successCount,
      'validations': validations,
      'summary': overallSuccess 
          ? 'All API requirements are properly configured ✅'
          : 'Some API requirements are missing or invalid ❌',
    };
  }
  
  /// Validate base URL configuration
  static Future<Map<String, dynamic>> _validateBaseUrl() async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      final hasBaseUrl = baseUrl.isNotEmpty;
      final isValidUrl = _isValidUrl(baseUrl);
      
      return {
        'name': 'Base URL Configuration',
        'success': hasBaseUrl && isValidUrl,
        'details': {
          'has_base_url': hasBaseUrl,
          'base_url': baseUrl,
          'is_valid_url': isValidUrl,
        },
        'message': hasBaseUrl && isValidUrl
            ? 'Base URL is properly configured: $baseUrl'
            : hasBaseUrl 
                ? 'Base URL is configured but invalid: $baseUrl'
                : 'Base URL is not configured',
      };
    } catch (e) {
      return {
        'name': 'Base URL Configuration',
        'success': false,
        'error': e.toString(),
        'message': 'Failed to validate base URL: $e',
      };
    }
  }
  
  /// Validate authentication setup
  static Future<Map<String, dynamic>> _validateAuthentication() async {
    try {
      final headers = await AuthService.getCompleteHeaders();
      final hasHeaders = headers.isNotEmpty;
      
      final requiredHeaders = ['Authorization', 'Auth-Key', 'Client-Service', 'Content-Type'];
      final hasRequiredHeaders = requiredHeaders.every((header) => headers.containsKey(header));
      
      final authKey = headers['Auth-Key'];
      final clientService = headers['Client-Service'];
      final contentType = headers['Content-Type'];
      
      return {
        'name': 'Authentication Setup',
        'success': hasHeaders && hasRequiredHeaders,
        'details': {
          'has_headers': hasHeaders,
          'has_required_headers': hasRequiredHeaders,
          'auth_key': authKey,
          'client_service': clientService,
          'content_type': contentType,
          'header_count': headers.length,
        },
        'message': hasHeaders && hasRequiredHeaders
            ? 'Authentication headers are properly configured'
            : 'Authentication headers are missing or incomplete',
      };
    } catch (e) {
      return {
        'name': 'Authentication Setup',
        'success': false,
        'error': e.toString(),
        'message': 'Failed to validate authentication: $e',
      };
    }
  }
  
  /// Validate student ID
  static Future<Map<String, dynamic>> _validateStudentId() async {
    try {
      final studentId = await AuthService.getStudentId();
      final hasStudentId = studentId.isNotEmpty;
      final isValidId = _isValidStudentId(studentId);
      
      return {
        'name': 'Student ID Configuration',
        'success': hasStudentId && isValidId,
        'details': {
          'has_student_id': hasStudentId,
          'student_id': studentId,
          'is_valid_id': isValidId,
        },
        'message': hasStudentId && isValidId
            ? 'Student ID is properly configured: $studentId'
            : hasStudentId 
                ? 'Student ID is configured but invalid: $studentId'
                : 'Student ID is not configured',
      };
    } catch (e) {
      return {
        'name': 'Student ID Configuration',
        'success': false,
        'error': e.toString(),
        'message': 'Failed to validate student ID: $e',
      };
    }
  }
  
  /// Validate headers
  static Future<Map<String, dynamic>> _validateHeaders() async {
    try {
      final headers = await AuthService.getCompleteHeaders();
      final headerCount = headers.length;
      final hasMinimumHeaders = headerCount >= 4;
      
      final headerKeys = headers.keys.toList();
      final hasStandardHeaders = headerKeys.any((key) => 
          key.toLowerCase().contains('auth') || 
          key.toLowerCase().contains('content') ||
          key.toLowerCase().contains('client'));
      
      return {
        'name': 'Headers Configuration',
        'success': hasMinimumHeaders && hasStandardHeaders,
        'details': {
          'header_count': headerCount,
          'has_minimum_headers': hasMinimumHeaders,
          'has_standard_headers': hasStandardHeaders,
          'header_keys': headerKeys,
        },
        'message': hasMinimumHeaders && hasStandardHeaders
            ? 'Headers are properly configured ($headerCount headers)'
            : 'Headers are missing or insufficient ($headerCount headers)',
      };
    } catch (e) {
      return {
        'name': 'Headers Configuration',
        'success': false,
        'error': e.toString(),
        'message': 'Failed to validate headers: $e',
      };
    }
  }
  
  /// Check if URL is valid
  static bool _isValidUrl(String url) {
    if (url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      return uri.hasScheme && uri.hasAuthority;
    } catch (e) {
      return false;
    }
  }
  
  /// Check if student ID is valid
  static bool _isValidStudentId(String studentId) {
    if (studentId.isEmpty) return false;
    // Check if it's a valid number or alphanumeric ID
    return RegExp(r'^[a-zA-Z0-9]+$').hasMatch(studentId) && studentId.isNotEmpty;
  }
  
  /// Quick validation check
  static Future<bool> quickCheck() async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      final studentId = await AuthService.getStudentId();
      final headers = await AuthService.getCompleteHeaders();
      
      return baseUrl.isNotEmpty && 
             studentId.isNotEmpty && 
             headers.isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  /// Get API status summary
  static Future<String> getStatusSummary() async {
    try {
      final validation = await validateApiSetup();
      
      if (validation['success'] == true) {
        return '✅ API is properly configured and ready to use';
      } else {
        final failedCount = validation['failed_validations'] as int;
        return '❌ API has $failedCount configuration issues';
      }
    } catch (e) {
      return '❌ Failed to validate API configuration: $e';
    }
  }
}
