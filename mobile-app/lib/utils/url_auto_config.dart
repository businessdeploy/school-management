import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class UrlAutoConfig {
  /// Check if base URL is configured (don't auto-set it)
  static Future<void> ensureBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? '';
      
      if (baseUrl.isEmpty) {
      } else {
      }
    } catch (e) {
      
    }
  }
  
  /// Get current URL status
  static Future<Map<String, dynamic>> getUrlStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString('base_url') ?? '';
      
      return {
        'configured': baseUrl.isNotEmpty,
        'base_url': baseUrl,
        'is_demo': baseUrl.contains('demo.smart-school.in'),
      };
    } catch (e) {
      return {
        'configured': false,
        'base_url': '',
        'error': e.toString(),
      };
    }
  }
}
