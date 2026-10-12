import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../utils/url_manager.dart';
import '../auth_service.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class CurrencyApi {
  static Future<List<Map<String, dynamic>>> getCurrencyList({
    String? studentId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return [];
      }

      String resolvedStudentId = studentId?.trim() ?? '';
      if (resolvedStudentId.isEmpty) {
        resolvedStudentId = await AuthService.getStudentId() ?? '';
      }
      if (resolvedStudentId.isEmpty) {
        
        return [];
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'application/json';

      final body = jsonEncode({'student_id': resolvedStudentId});
      final url = Uri.parse(await AppConfig.getApiEndpoint('get_currency_list'));

      
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));
      

      if (response.statusCode != 200) {
        
        return [];
      }

      final data = jsonDecode(response.body);
      

      if (data is Map && data['result'] is List) {
        final currencies = (data['result'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        
        if (currencies.isNotEmpty) {
          
          
        }
        return currencies;
      }

      
      return [];
    } catch (e, stack) {
      
      
      return [];
    }
  }

  static Future<bool> updateStudentCurrency({
    required String currencyId,
    String? studentId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return false;

      String resolvedStudentId = studentId?.trim() ?? '';
      if (resolvedStudentId.isEmpty) {
        resolvedStudentId = await AuthService.getStudentId() ?? '';
      }
      if (resolvedStudentId.isEmpty || currencyId.trim().isEmpty) {
        return false;
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'application/json';

      final body = jsonEncode({
        'student_id': resolvedStudentId,
        'currency_id': currencyId.trim(),
      });
      final url = Uri.parse(await AppConfig.getApiEndpoint('updatestudentcurrency'));

      
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        
        return false;
      }

      final data = jsonDecode(response.body);
      return data is Map && (data['status'] == 1 || data['status'] == '1');
    } catch (e) {
      
      return false;
    }
  }

  static Future<bool> updateStudentLanguage({
    required String languageId,
    String? studentId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) return false;

      String resolvedStudentId = studentId?.trim() ?? '';
      if (resolvedStudentId.isEmpty) {
        resolvedStudentId = await AuthService.getStudentId() ?? '';
      }
      if (resolvedStudentId.isEmpty || languageId.trim().isEmpty) {
        return false;
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'application/json';

      final body = jsonEncode({
        'student_id': resolvedStudentId,
        'language_id': languageId.trim(),
      });
      final url = Uri.parse(await AppConfig.getApiEndpoint('updatestudentlanguage'));

      
      final response = await http
          .post(url, headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        
        return false;
      }

      final data = jsonDecode(response.body);
      return data is Map && (data['status'] == 1 || data['status'] == '1');
    } catch (e) {
      
      return false;
    }
  }
}

