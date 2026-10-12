import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../utils/url_manager.dart';
import '../utils/dynamic_api_headers.dart';

class ExaminationDiagnostic {
  static Future<Map<String, dynamic>> testExaminationAPI() async {
    try {
      
      
      // 1. Check student ID
      final studentId = await AuthService.getStudentId();
      
      
      // 2. Check base URL
      final baseUrl = await UrlManager.getBaseUrl();
      
      
      if (baseUrl.isEmpty) {
        return {
          'success': false,
          'error': 'No base URL configured',
          'student_id': studentId,
        };
      }
      
      // 3. Check headers
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      
      // 4. Test API call
      final endpoint = '$baseUrl/api/webservice/getExamList';
      final requestBody = jsonEncode({'studentId': studentId});
      
      
      
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: requestBody,
      ).timeout(Duration(seconds: 30));
      
      
      
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'status_code': response.statusCode,
          'response_data': data,
          'student_id': studentId,
          'base_url': baseUrl,
        };
      } else {
        return {
          'success': false,
          'status_code': response.statusCode,
          'response_body': response.body,
          'student_id': studentId,
          'base_url': baseUrl,
        };
      }
    } catch (e) {
      
      return {
        'success': false,
        'error': e.toString(),
        'error_type': e.runtimeType.toString(),
      };
    }
  }
}
