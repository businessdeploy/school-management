import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../providers/translation_provider.dart';
import '../services/translation_service.dart';

/// Extension methods for easy translation
extension TranslationExtension on String {
  /// Translate this string to the current language
  /// Usage: 'Hello'.tr(context)
  Future<String> tr(BuildContext context) async {
    final translationProvider = Provider.of<TranslationProvider>(context, listen: false);
    
    if (!translationProvider.isEnabled || translationProvider.currentLanguage == 'en') {
      return this;
    }

    return await TranslationService.translate(
      text: this,
      sourceLang: 'en',
      targetLang: translationProvider.currentLanguage,
    );
  }
}

/// Context extension for translation
extension TranslationContext on BuildContext {
  /// Get current language code
  String get currentLanguage {
    return Provider.of<TranslationProvider>(this, listen: false).currentLanguage;
  }

  /// Get current language name
  String get currentLanguageName {
    return Provider.of<TranslationProvider>(this, listen: false).currentLanguageName;
  }

  /// Check if translation is enabled
  bool get isTranslationEnabled {
    return Provider.of<TranslationProvider>(this, listen: false).isEnabled;
  }

  /// Translate a string
  Future<String> translate(String text) async {
    final translationProvider = Provider.of<TranslationProvider>(this, listen: false);
    
    if (!translationProvider.isEnabled || translationProvider.currentLanguage == 'en') {
      return text;
    }

    return await TranslationService.translate(
      text: text,
      sourceLang: 'en',
      targetLang: translationProvider.currentLanguage,
    );
  }
}
