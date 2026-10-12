import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/translation_service.dart';
import '../services/api_service.dart';

/// Provider for managing translation state
class TranslationProvider extends ChangeNotifier {
  String _currentLanguageCode = 'en';
  String _currentLanguageName = 'English';
  bool _translationEnabled = false;

  String get currentLanguage => _currentLanguageCode;
  String get currentLanguageName => _currentLanguageName;
  bool get isEnabled => _translationEnabled;

  /// Initialize translation provider
  Future<void> initialize() async {
    await _loadSavedLanguage();
    await _loadLanguageFromServer(); // Sync with server on startup
    
    notifyListeners();
  }

  /// Load language from local storage
  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString('language_code');
      final savedName = prefs.getString('language_name');
      final savedEnabled = prefs.getBool('translation_enabled') ?? false;

      if (savedCode != null && savedName != null) {
        _currentLanguageCode = savedCode;
        _currentLanguageName = savedName;
        _translationEnabled = savedEnabled;
        
      }
    } catch (e) {
      
    }
  }

  /// Load language from server to sync with web dashboard
  Future<void> _loadLanguageFromServer() async {
    try {
      
      final config = await ApiService.getAppConfiguration();
      
      if (config.isEmpty) {
        
        return;
      }

      // Get the current language code from server
      final serverLangCode = config['lang_code']?.toString();
      if (serverLangCode == null || serverLangCode.isEmpty || serverLangCode == 'en') {
        
        return;
      }

      // Map language code to language name
      final languageMap = {
        'hi': 'Hindi',
        'es': 'Spanish',
        'fr': 'French',
        'de': 'German',
        'ar': 'Arabic',
        'pt': 'Portuguese',
        'en': 'English',
      };

      final languageName = languageMap[serverLangCode] ?? 'English';

      // Only update if different from current
      if (serverLangCode != _currentLanguageCode) {
        
        
        
        _currentLanguageCode = serverLangCode;
        _currentLanguageName = languageName;
        _translationEnabled = serverLangCode != 'en';
        
        // Save to local storage
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('language_code', serverLangCode);
        await prefs.setString('language_name', languageName);
        await prefs.setBool('translation_enabled', _translationEnabled);
        
        
        notifyListeners();
      } else {
        
      }
    } catch (e) {
      
    }
  }

  /// Change current language
  Future<void> changeLanguage(String languageCode, String languageName) async {
    if (_currentLanguageCode == languageCode) {
      
      return;
    }

    try {
      _currentLanguageCode = languageCode;
      _currentLanguageName = languageName;
      _translationEnabled = languageCode != 'en'; // Disable for English
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('language_code', languageCode);
      await prefs.setString('language_name', languageName);
      await prefs.setBool('translation_enabled', _translationEnabled);
      
      
      notifyListeners();
    } catch (e) {
      
    }
  }

  /// Toggle translation on/off
  Future<void> toggleTranslation(bool enabled) async {
    try {
      _translationEnabled = enabled;
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('translation_enabled', enabled);
      
      
      notifyListeners();
    } catch (e) {
      
    }
  }

  /// Reset to English
  Future<void> resetToEnglish() async {
    await changeLanguage('en', 'English');
  }

  /// Clear translation cache
  Future<void> clearCache() async {
    await TranslationService.clearCache();
    
  }
}
