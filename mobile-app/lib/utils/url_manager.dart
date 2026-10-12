import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class UrlManager {
  static const String _baseUrlKey = 'base_url';
  
  // Get the configured base URL
  static Future<String> getBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final baseUrl = prefs.getString(_baseUrlKey) ?? '';
      
      if (baseUrl.isEmpty) {
        return '';
      }
      
      // CRITICAL: Normalize the URL when reading to handle legacy stored URLs
      String normalizedUrl = baseUrl.trim();
      
      // Remove trailing slash
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      
      // Remove /api or /api/ suffix if present (handles legacy URLs)
      if (normalizedUrl.endsWith('/api')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 4);
        // Save the normalized version for next time
        await prefs.setString(_baseUrlKey, normalizedUrl);
      }
      
      // Remove trailing slash again if it was behind /api
      while (normalizedUrl.endsWith('/')) {
        normalizedUrl = normalizedUrl.substring(0, normalizedUrl.length - 1);
      }
      
      return normalizedUrl;
    } catch (e) {
      return '';
    }
  }
  
  // Set the base URL with normalization
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
      return result;
    } catch (e) {
      return false;
    }
  }
  
  // Clear the base URL
  static Future<bool> clearBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final result = await prefs.remove(_baseUrlKey);
      return result;
    } catch (e) {
      return false;
    }
  }

  // Get API URL
  static Future<String> getApiUrl() async {
    final baseUrl = await getBaseUrl();
    return '$baseUrl/api';
  }

  // Get site URL
  static Future<String> getSiteUrl() async {
    return await getBaseUrl();
  }

  // Get site asset URL
  static Future<String> getSiteAsset(String assetPath) async {
    final baseUrl = await getBaseUrl();
    return '$baseUrl/uploads/$assetPath';
  }
}