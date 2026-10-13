import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/app_config.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';

class ModuleApi {
  static const String _cacheKey = 'cached_module_permissions';

  static Future<String> get _baseUrl async => await AppConfig.getBaseUrl();

  /// Fetch module statuses synchronized with Web Admin Panel permissions
  static Future<Map<String, bool>> getModulePermissions() async {
    final Map<String, bool> permissions = {};

    try {
      final base = await _baseUrl;
      if (base.isEmpty) {
        return await getCachedPermissions();
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final role = (await AuthService.getUserRole()) ?? 'student';
      final body = jsonEncode({'user': role.toLowerCase() == 'parent' ? 'parent' : 'student'});

      final endpoints = [
        '$base/api/webservice/getELearningModuleStatus',
        '$base/api/webservice/getAcademicsModuleStatus',
        '$base/api/webservice/getCommunicateModuleStatus',
        '$base/api/webservice/getOthersModuleStatus',
        '$base/api/webservice/getModuleStatus',
      ];

      final results = await Future.wait(
        endpoints.map((url) => http.post(Uri.parse(url), headers: headers, body: body).catchError((_) => http.Response('', 500))),
      );

      for (final response in results) {
        if (response.statusCode == 200 && response.body.isNotEmpty) {
          try {
            final data = jsonDecode(response.body);
            if (data is Map<String, dynamic> && data['module_list'] is List) {
              for (final item in data['module_list']) {
                if (item is Map<String, dynamic>) {
                  final shortCode = item['short_code']?.toString() ?? '';
                  final status = item['status']?.toString();
                  if (shortCode.isNotEmpty) {
                    final isEnabled = (status == '1' || status == 'true');
                    permissions[shortCode] = isEnabled;
                  }
                }
              }
            }
          } catch (_) {}
        }
      }

      // If we got valid permissions, cache them
      if (permissions.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_cacheKey, jsonEncode(permissions));
        return permissions;
      }
    } catch (_) {}

    // Fallback to cache if network call fails
    return await getCachedPermissions();
  }

  /// Get cached module permissions from local storage
  static Future<Map<String, bool>> getCachedPermissions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_cacheKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final decoded = jsonDecode(jsonStr);
        if (decoded is Map<String, dynamic>) {
          return decoded.map((k, v) => MapEntry(k, v == true));
        }
      }
    } catch (_) {}
    return {};
  }

  /// Check if a specific module short_code is enabled
  static bool isModuleEnabled(Map<String, bool> permissions, String shortCode, {bool defaultVal = true}) {
    if (permissions.containsKey(shortCode)) {
      return permissions[shortCode] == true;
    }
    // If permission wasn't returned by server, use default
    return defaultVal;
  }
}
