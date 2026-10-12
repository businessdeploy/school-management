import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Cache for storing translations locally
class TranslationCache {
  static const String _prefix = 'translation_';
  static const int _cacheExpiryDays = 30;
  
  // In-memory cache for faster access
  static final Map<String, String> _memoryCache = {};

  /// Get cached translation
  static Future<String?> get(String originalText, String targetLang) async {
    final key = _getCacheKey(originalText, targetLang);
    
    // Check memory cache first
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key];
    }

    // Check persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(key);
      
      if (cachedData != null) {
        final data = jsonDecode(cachedData);
        final timestamp = DateTime.parse(data['timestamp'] as String);
        final translation = data['translation'] as String;
        
        // Check if cache is still valid
        if (DateTime.now().difference(timestamp).inDays < _cacheExpiryDays) {
          // Add to memory cache
          _memoryCache[key] = translation;
          return translation;
        } else {
          // Cache expired, remove it
          await prefs.remove(key);
        }
      }
    } catch (e) {
      
    }
    
    return null;
  }

  /// Store translation in cache
  static Future<void> set(
    String originalText,
    String targetLang,
    String translation,
  ) async {
    final key = _getCacheKey(originalText, targetLang);
    
    // Add to memory cache
    _memoryCache[key] = translation;
    
    // Add to persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'translation': translation,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(key, jsonEncode(data));
    } catch (e) {
      
    }
  }

  /// Clear all cached translations
  static Future<void> clear() async {
    _memoryCache.clear();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      
    }
  }

  /// Clear cache for a specific language
  static Future<void> clearLanguage(String targetLang) async {
    // Clear from memory cache
    _memoryCache.removeWhere((key, _) => key.endsWith('_$targetLang'));
    
    // Clear from persistent cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs
          .getKeys()
          .where((key) => key.startsWith(_prefix) && key.endsWith('_$targetLang'));
      for (final key in keys) {
        await prefs.remove(key);
      }
    } catch (e) {
      
    }
  }

  /// Generate cache key
  static String _getCacheKey(String originalText, String targetLang) {
    // Use hash of text to keep key shorter
    final textHash = originalText.hashCode.toString();
    return '$_prefix${textHash}_$targetLang';
  }

  /// Get cache statistics
  static Future<Map<String, int>> getStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((key) => key.startsWith(_prefix));
      
      return {
        'memoryCache': _memoryCache.length,
        'persistentCache': keys.length,
      };
    } catch (e) {
      
      return {'memoryCache': 0, 'persistentCache': 0};
    }
  }
}
