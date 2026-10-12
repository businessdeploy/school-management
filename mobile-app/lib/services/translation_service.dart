import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../utils/translation_cache.dart';

/// Service for translating text using MyMemory Translation API
class TranslationService {
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';
  
  /// Language code mappings
  static const Map<String, String> languageCodes = {
    'English': 'en',
    'Hindi': 'hi',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Arabic': 'ar',
    'Portuguese': 'pt',
  };

  /// Strip HTML tags from text
  static String _stripHtmlTags(String htmlText) {
    // Remove all HTML tags
    final RegExp htmlTagRegex = RegExp(r'<[^>]*>');
    String cleanText = htmlText.replaceAll(htmlTagRegex, '');
    
    // Decode HTML entities
    cleanText = cleanText
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
    
    return cleanText.trim();
  }

  /// Translate a single text from source to target language
  /// Returns original text if translation fails
  static Future<String> translate({
    required String text,
    String sourceLang = 'en',
    required String targetLang,
  }) async {
    // Skip translation if target is same as source
    if (sourceLang == targetLang) {
      return text;
    }

    // Skip empty or very short strings
    if (text.trim().isEmpty || text.length < 2) {
      return text;
    }

    // Skip if text is only numbers or symbols
    if (RegExp(r'^[0-9\s\.,\$\€\£\¥\₹\-\+]+$').hasMatch(text)) {
      return text;
    }

    try {
      // Check cache first
      final cachedTranslation = await TranslationCache.get(text, targetLang);
      if (cachedTranslation != null) {
        
        return cachedTranslation;
      }

      // Make API call
      final url = Uri.parse(
        '$_baseUrl?q=${Uri.encodeComponent(text)}&langpair=$sourceLang|$targetLang',
      );

      
      
      final response = await http
          .get(url)
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['responseStatus'] == 200 && data['responseData'] != null) {
          final translatedText = data['responseData']['translatedText'] as String?;
          
          if (translatedText != null && translatedText.isNotEmpty) {
            // Strip HTML tags from translation
            final cleanedText = _stripHtmlTags(translatedText);
            
            // Cache the cleaned translation
            await TranslationCache.set(text, targetLang, cleanedText);
            
            
            return cleanedText;
          }
        }
      }

      
      return text;
    } catch (e, stack) {
      
      if (kDebugMode) {
        
      }
      return text; // Fallback to original text
    }
  }

  /// Translate multiple texts in batch
  /// More efficient than individual calls
  static Future<Map<String, String>> translateBatch({
    required List<String> texts,
    String sourceLang = 'en',
    required String targetLang,
  }) async {
    final results = <String, String>{};
    
    for (final text in texts) {
      final translated = await translate(
        text: text,
        sourceLang: sourceLang,
        targetLang: targetLang,
      );
      results[text] = translated;
      
      // Small delay to avoid rate limiting
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    return results;
  }

  /// Get language code from language name
  static String? getLanguageCode(String languageName) {
    return languageCodes[languageName];
  }

  /// Get language name from code
  static String? getLanguageName(String languageCode) {
    return languageCodes.entries
        .firstWhere(
          (entry) => entry.value == languageCode,
          orElse: () => const MapEntry('English', 'en'),
        )
        .key;
  }

  /// Clear all cached translations
  static Future<void> clearCache() async {
    await TranslationCache.clear();
    
  }
}
