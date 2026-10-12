import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/api/currency_api.dart';
import '../config/app_config.dart';
import 'package:flutter/foundation.dart';

class AppConfigProvider extends ChangeNotifier {
  Map<String, dynamic>? _appConfig;
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _currencyOptions = [];
  List<Map<String, dynamic>> _languages = [];
  bool _isLoadingCurrencies = false;
  String? _selectedCurrencyId;
  String _baseUrl = '';
  String _cachedLogo = '';
  String _cachedSchoolName = 'Government Higher Secondary School Sarna';
  String _cachedPrimaryColor = '#424242';
  String _cachedSecondaryColor = '#E7F1EE';

  // Standard mapping for common currencies if no specific selection is active
  static const Map<String, String> _currencyCodeToSymbol = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
    'NGN': '₦',
    'GHS': 'GH₵',
    'KES': 'KSh',
    'UGX': 'USh',
    'ZAR': 'R',
    'AED': 'د.إ',
    'SAR': '﷼',
    'PKR': '₨',
    'BDT': '৳',
    'RUB': '₽',
    'CNY': '¥',
    'AUD': 'A\$',
    'CAD': 'C\$',
  };

  Map<String, dynamic>? get appConfig => _appConfig;
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get currencyOptions => _currencyOptions;
  List<Map<String, dynamic>> get languages => _languages;
  bool get isLoadingCurrencies => _isLoadingCurrencies;

  // Getters for specific config values
  String get appLogo {
    final logoFromConfig = _appConfig?['app_logo']?.toString() ?? '';
    
    // 1. Try logo from config memory first
    if (logoFromConfig.isNotEmpty && logoFromConfig.toLowerCase() != 'null') {
      if (logoFromConfig.startsWith('http')) return logoFromConfig;
      
      String siteUrl = _appConfig?['site_url']?.toString() ?? '';
      String baseUrl = (siteUrl.startsWith('http') ? siteUrl : _baseUrl);
      
      if (baseUrl.isNotEmpty) {
        return _constructLogoUrl(baseUrl, logoFromConfig);
      }
    }

    // 2. Fallback: Use cached logo from SharedPrefs
    if (_cachedLogo.isNotEmpty) {
      // If it's already a full URL, return it
      if (_cachedLogo.startsWith('http')) return _cachedLogo;
      
      // If it's just a filename, construct it using _baseUrl
      if (_baseUrl.isNotEmpty) {
        return _constructLogoUrl(_baseUrl, _cachedLogo);
      }
      
      // Last resort: return as-is (might be full path or relative)
      return _cachedLogo;
    }
    
    return '';
  }

  /// Helper to construct logo URL with consistent logic
  String _constructLogoUrl(String baseUrl, String logoPath) {
    if (logoPath.isEmpty) return '';
    if (logoPath.startsWith('http')) return logoPath;

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
    
    // Handle "uploads/" overlap
    if (cleanPath.startsWith('uploads/')) {
      cleanPath = cleanPath.substring(8);
    }

    // Try multiple standard paths
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

  String get schoolName {
    final name = _appConfig?['school_name']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return _cachedSchoolName;
  }

  String get primaryColor {
    final color = _appConfig?['primary_color']?.toString() ?? '';
    if (color.isNotEmpty) return color;
    return _cachedPrimaryColor;
  }

  String get secondaryColor {
    final color = _appConfig?['secondary_color']?.toString() ?? '';
    if (color.isNotEmpty) return color;
    return _cachedSecondaryColor;
  }
  String get langCode => _appConfig?['lang_code'] ?? 'en';
  String get currency => _appConfig?['currency'] ?? 'USD';
  String? get selectedCurrencyId => _selectedCurrencyId;
  String get dateFormat => _appConfig?['date_format'] ?? 'dd/MM/yyyy';
  String get appVersion => _appConfig?['app_version'] ?? _appConfig?['app_ver'] ?? '';

  double get selectedBasePrice {
    if (_currencyOptions.isEmpty || _selectedCurrencyId == null) return 1.0;
    final option = _currencyOptions.firstWhere(
      (c) => (c['id'] ?? c['currency_id'])?.toString() == _selectedCurrencyId,
      orElse: () => {},
    );
    final basePrice = option['base_price'];
    if (basePrice == null) return 1.0;
    return double.tryParse(basePrice.toString()) ?? 1.0;
  }

  String get selectedCurrencySymbol {
    if (_currencyOptions.isEmpty || _selectedCurrencyId == null) {
      // Fallback: Check if we have a mapping for the default currency code
      final defaultCurrency = currency;
      if (_currencyCodeToSymbol.containsKey(defaultCurrency)) {
        return _currencyCodeToSymbol[defaultCurrency]!;
      }
      return defaultCurrency;
    }
    
    final option = _currencyOptions.firstWhere(
      (c) => (c['id'] ?? c['currency_id'])?.toString() == _selectedCurrencyId,
      orElse: () => {},
    );
    
    // Try multiple possible keys for symbol
    final rawSymbol = option['currency_symbol']?.toString() ?? '';
    final code = option['code']?.toString() ?? option['short_name']?.toString() ?? '';
    
    // Priority 1: Map the code to a proper symbol (e.g. RUB -> ₽)
    if (code.isNotEmpty && _currencyCodeToSymbol.containsKey(code)) {
      return _currencyCodeToSymbol[code]!;
    }
    
    // Priority 2: Use the provided symbol
    if (rawSymbol.isNotEmpty) {
       // If the symbol is a known code, map it
       if (rawSymbol.length > 1 && _currencyCodeToSymbol.containsKey(rawSymbol)) {
         return _currencyCodeToSymbol[rawSymbol]!;
       }
       return rawSymbol;
    }
                   
    // Priority 3: Try to map the default currency code
    final defaultCurrency = currency;
    if (_currencyCodeToSymbol.containsKey(defaultCurrency)) {
      return _currencyCodeToSymbol[defaultCurrency]!;
    }
                   
    return defaultCurrency;
  }

  String get selectedCurrencyLabel {
    if (_currencyOptions.isEmpty || _selectedCurrencyId == null) {
      // If config has currency code (e.g. USD), use it. If it's a symbol like $, default to empty or USD.
      final c = currency;
      if (c.length > 1) return c;
      return 'USD'; // Generic fallback for symbols
    }
    
    final option = _currencyOptions.firstWhere(
      (c) => (c['id'] ?? c['currency_id'])?.toString() == _selectedCurrencyId,
      orElse: () => {},
    );
    
    // STRICT PRIORITY: name > code > short_name
    String? label = option['name']?.toString() ??
                    option['code']?.toString() ?? 
                    option['short_name']?.toString();
                    
    if (label == null || label.isEmpty || label.length <= 1) {
       return currency.length > 1 ? currency : 'USD';
    }
                   
    return label;
  }

  double convertAmount(double amount) {
    return amount * selectedBasePrice;
  }

  // Online Course Curriculum Settings
  // Logic: 1 = Quiz enabled, 2 = Exam enabled, 3 = Assignment enabled
  // Backend often sends this as a comma-separated string or list in 'online_course_curriculum'
  bool get isQuizEnabled {
    final curriculum = _appConfig?['online_course_curriculum'];
    if (curriculum == null) return true; // Default to enabled if key missing
    final s = curriculum.toString();
    if (s.isEmpty) return false; // Explicitly empty means none selected
    return s.contains('1');
  }

  bool get isExamEnabled {
    final curriculum = _appConfig?['online_course_curriculum'];
    if (curriculum == null) return true;
    final s = curriculum.toString();
    if (s.isEmpty) return false;
    return s.contains('2');
  }

  bool get isAssignmentEnabled {
    final curriculum = _appConfig?['online_course_curriculum'];
    if (curriculum == null) return true;
    final s = curriculum.toString();
    if (s.isEmpty) return false;
    return s.contains('3');
  }

  // Get color objects
  Color get primaryColorObj {
    try {
      return Color(int.parse(primaryColor.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return Colors.grey[800]!;
    }
  }

  Color get secondaryColorObj {
    try {
      return Color(int.parse(secondaryColor.replaceFirst('#', ''), radix: 16) + 0xFF000000);
    } catch (e) {
      return const Color(0xFFE7F1EE);
    }
  }

  // Allowed languages list (normalized to lowercase for comparison)
  static const Set<String> _allowedLanguageNames = {
    'english',
    'hindi',
    'arabic',
    'french',
    'francais', // Native French
    'français', // Native French with cedilla
    'portuguese',
    'portugis',   // User variant
    'portugise',  // User specified typo
    'spanish',
    'espanol', // Native Spanish
    'español', // Native Spanish with tilde
    'português', // Native Portuguese
  };

  // Helper to filter languages - return exactly what API provides
  List<Map<String, dynamic>> _filterLanguages(List<Map<String, dynamic>> rawList) {
    // Return all languages from API without any modifications
    return rawList;
  }

  Future<void> loadAppConfig() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    // Load cached languages first
    try {
      final savedLanguages = await AppConfig.getLanguages();
      if (savedLanguages.isNotEmpty) {
        _languages = _filterLanguages(savedLanguages);

        notifyListeners(); // Update UI immediately with cached data
      }
    } catch (e) {

    }

    // Load base URL and cached logo locally first
    try {
      _baseUrl = await AppConfig.getBaseUrl();
      
      // Load cached items
      _cachedLogo = await AppConfig.getAppLogo();
      _cachedSchoolName = await AppConfig.getSchoolName();
      if (_cachedSchoolName.isEmpty) _cachedSchoolName = 'Government Higher Secondary School Sarna';
      
      _cachedPrimaryColor = await AppConfig.getPrimaryColor();
      if (_cachedPrimaryColor.isEmpty) _cachedPrimaryColor = '#424242';
      
      _cachedSecondaryColor = await AppConfig.getSecondaryColor();
      if (_cachedSecondaryColor.isEmpty) _cachedSecondaryColor = '#E7F1EE';

      notifyListeners(); // Update UI immediately with cached data
    } catch (e) {
    }

    try {
      final config = await ApiService.getAppConfiguration();
      
      // CRITICAL: Only update state if fetch was successful
      final status = config['status'];
      final isSuccess = status == 1 || status == '1' || status == true;

      if (isSuccess && config.length > 2) { 
        await AppConfig.saveAppConfiguration(config);
        _appConfig = config;
        
        // Populate and filter languages
        if (config.containsKey('languages') && config['languages'] is List) {
          final rawLanguages = (config['languages'] as List).map((e) => Map<String, dynamic>.from(e)).toList();
          _languages = _filterLanguages(rawLanguages);
        }
        
        // If config has updated logo, update cached values too
        final newLogo = await AppConfig.getAppLogo();
        if (newLogo.isNotEmpty) {
          _cachedLogo = newLogo;
        }
        _cachedSchoolName = await AppConfig.getSchoolName();
        _cachedPrimaryColor = await AppConfig.getPrimaryColor();
        _cachedSecondaryColor = await AppConfig.getSecondaryColor();
      }
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshConfig() async {
    await loadAppConfig();
  }

  Future<void> loadCurrencyOptions() async {
    _isLoadingCurrencies = true;
    notifyListeners();

    try {

      final currencies = await CurrencyApi.getCurrencyList();
      _currencyOptions = currencies;
      
      // Load saved currency ID if not set
      if (_selectedCurrencyId == null || _selectedCurrencyId == 'null' || _selectedCurrencyId == '0') {
        final prefs = await SharedPreferences.getInstance();
        _selectedCurrencyId = prefs.getString('selected_currency_id');
        
        // If still null, try to find USD/Dollar as default
        if (_selectedCurrencyId == null || _selectedCurrencyId == 'null' || _selectedCurrencyId == '0') {
          for (final currency in _currencyOptions) {
            final shortName = currency['short_name']?.toString() ?? '';
            final name = currency['name']?.toString() ?? '';
            final code = currency['code']?.toString() ?? '';
            
            if (shortName == 'USD' || name.contains('Dollar') || code == 'USD') {
              _selectedCurrencyId = (currency['currency_id'] ?? currency['id'])?.toString();
              break;
            }
          }
        }
      }


    } catch (e) {

      _currencyOptions = [];
    }

    _isLoadingCurrencies = false;
    notifyListeners();
  }

  Future<void> refreshCurrencyOptions() async {
    await loadCurrencyOptions();
  }

  // Update specific config values (useful for testing)
  void updateConfigValue(String key, dynamic value) {
    if (_appConfig != null) {
      _appConfig![key] = value;
      notifyListeners();
    }
  }

  void setSelectedCurrencyId(String? id) {
    _selectedCurrencyId = id;
    notifyListeners();
  }

  // Get language options
  List<Map<String, dynamic>> get languageOptions {
    // Return _languages if populated (which includes cached ones)
    if (_languages.isNotEmpty) {
      return _languages;
    }
    
    // Fallback to checking _appConfig directly but applying filter
    final languages = _appConfig?['languages'];
    if (languages is List) {
      final rawList = languages.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      return _filterLanguages(rawList);
    }
    return [];
  }

  // Get currency options (loaded separately from currency API)
  // Note: This getter now returns the loaded currency options
}
