import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';

class StudentManagementApi {
  // Get student from login data
  static Future<Map<String, dynamic>?> getStudentFromLoginData() async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/getStudentFromLoginData');

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final body = jsonEncode({});

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'student',
        );
        
        return data['student'];
      } else {
        
        return null;
      }
    } catch (e) {
      
      return null;
    }
  }

  // Get student list
  static Future<List<Map<String, dynamic>>> getStudentList(String parentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse('$baseUrl/api/webservice/getStudentList');

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final body = jsonEncode({'parent_id': parentId});

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'students',
        );
        
        return List<Map<String, dynamic>>.from(data['students'] ?? []);
      } else {
        
        return [];
      }
    } catch (e) {
      
      return [];
    }
  }
}



