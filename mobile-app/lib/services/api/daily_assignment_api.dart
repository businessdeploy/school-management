import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';
import '../auth_service.dart';

class DailyAssignmentApi {
  // Get daily assignments
  static Future<Map<String, dynamic>> getDailyAssignments(
    String studentId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(
        await AppConfig.getApiEndpoint('getdailyassignment'),
      ); // Use correct endpoint name

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final payload = <String, dynamic>{
        'student_id': studentId.trim(),
      };

      // Include student_session_id when available for stricter filtering
      final studentSessionId = await AuthService.getStudentSessionId();
      if (studentSessionId.trim().isNotEmpty) {
        payload['student_session_id'] = studentSessionId.trim();
      }

      final body = jsonEncode(payload);

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'dailyassignment', // Use correct response key
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load daily assignments: ${response.statusCode}',
          'dailyassignment': [], // Use correct response key
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading daily assignments: $e',
        'dailyassignment': [], // Use correct response key
      };
    }
  }

  // Get session cookie from SharedPreferences
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }

  // Get single daily assignment
  static Future<Map<String, dynamic>> getDailyAssignment(
    String assignmentId,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('getDailyAssignment'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final body = jsonEncode({'assignment_id': assignmentId});

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'assignment',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load daily assignment: ${response.statusCode}',
          'assignment': null,
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading daily assignment: $e',
        'assignment': null,
      };
    }
  }

  // Add/Edit daily assignment
  // API: https://demo.smart-school.in/api/webservice/addeditdailyassignment
  // Method: POST
  // Body: form-data with id, title, description, student_id, subject, file
  static Future<Map<String, dynamic>> addEditDailyAssignment(
    String? id,
    String studentId,
    String title,
    String description,
    String dueDate,
    String? filePath, {
    String? subject,
  }) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();

      // Check if base URL is configured
      if (baseUrl.isEmpty) {
        
        if (kReleaseMode) {
          print('❌ No base URL configured for daily assignment');
        }
        return {
          'status': '0',
          'msg': 'Please configure the base URL in settings first',
        };
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Use the correct endpoint as per API documentation
      final url = Uri.parse(await AppConfig.getApiEndpoint('addeditdailyassignment'));

      

      // Prepare multipart request to match form-data format
      final mpHeaders = Map<String, String>.from(headers);
      // Remove Content-Type for multipart - it will be set automatically with boundary
      mpHeaders.remove('Content-Type');

      final request = http.MultipartRequest('POST', url);

      // Add headers (excluding Content-Type which will be set by multipart)
      request.headers.addAll(mpHeaders);

      // Validate required fields
      if (title.trim().isEmpty) {
        return {'status': '0', 'msg': 'Title is required'};
      }
      if (studentId.trim().isEmpty) {
        return {'status': '0', 'msg': 'Student ID is required'};
      }
      if (subject == null || subject.trim().isEmpty) {
        return {'status': '0', 'msg': 'Subject is required'};
      }

      // Add form fields as per API specification
      // For add: id should be empty string (per API spec: "id -")
      // For edit: id should be provided
      // Note: Some servers require all fields to be present, even if empty
      if (id != null && id.isNotEmpty) {
        request.fields['id'] = id;
      } else {
        // For add operations, send empty string (some servers require field to be present)
        request.fields['id'] = '';
      }

      request.fields['title'] = title.trim();
      request.fields['description'] = description.trim();
      request.fields['student_id'] = studentId.trim();

      // Subject is required - The API expects a numeric subject code (e.g., "230" for Hindi)
      // The dropdown now stores the subject code directly, so use it as-is
      String subjectCode = subject.trim();

      // Validate that subject is numeric (should be a code like "230", "210", etc.)
      if (!RegExp(r'^\d+$').hasMatch(subjectCode)) {
        
        // Try to extract numeric part if somehow we got formatted text
        final numberMatch = RegExp(r'(\d+)').firstMatch(subjectCode);
        if (numberMatch != null) {
          subjectCode = numberMatch.group(1)!;
          
        } else {
          return {'status': '0', 'msg': 'Invalid subject code format'};
        }
      }

      
      // Try multiple field name variations - API might expect subject_group_subject_id
      // Based on the model, the database uses subject_group_subject_id as foreign key
      request.fields['subject'] = subjectCode;
      request.fields['subject_id'] = subjectCode;
      request.fields['subject_group_subject_id'] =
          subjectCode; // Most likely what API expects
      request.fields['subject_code'] = subjectCode;

      // Add due_date field (API may require it, even if empty)
      request.fields['due_date'] = dueDate.trim().isNotEmpty
          ? dueDate.trim()
          : '';
      

      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      
      if (request.files.isNotEmpty) {
        
        
      }
      

      // Add file if provided
      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          request.files.add(
            await http.MultipartFile.fromPath('file', filePath),
          );
          
        }
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      
      

      if (response.statusCode == 200 &&
          !ResponseValidator.isHtmlResponse(response.body)) {
        try {
          final data = jsonDecode(response.body);
          // Check response format: {"status": "1", "msg": "Success"}
          final ok =
              data['status'] == '1' ||
              data['status'] == 1 ||
              data['msg']?.toString().toLowerCase() == 'success' ||
              data['success'] == true;

          if (ok) {
            
            return {'status': '1', 'msg': data['msg']?.toString() ?? 'Success'};
          } else {
            
            return {
              'status': '0',
              'msg': data['msg']?.toString() ?? 'Failed to save assignment',
            };
          }
        } catch (parseError) {
          
          return {'status': '0', 'msg': 'Invalid server response format'};
        }
      } else {
        
        

        // Check if response is HTML (database error page)
        String errorMsg = 'Server error: ${response.statusCode}';

        if (response.body.toLowerCase().contains('database error') ||
            response.body.toLowerCase().contains('<!doctype html>') ||
            response.body.toLowerCase().contains('<html')) {
          // Try to extract more specific error from HTML response
          String detailedError =
              'Database error: Please check your input fields and try again.';
          if (response.body.toLowerCase().contains('foreign key') ||
              response.body.toLowerCase().contains('constraint')) {
            detailedError =
                'Database error: Invalid subject or student ID. Please check your selection.';
          } else if (response.body.toLowerCase().contains('null') ||
              response.body.toLowerCase().contains('required')) {
            detailedError =
                'Database error: Missing required fields. Please fill all fields.';
          }
          errorMsg = detailedError;
          
          
          
          
        } else {
          try {
            final errorData = jsonDecode(response.body);
            errorMsg =
                errorData['msg']?.toString() ??
                errorData['message']?.toString() ??
                errorData['error']?.toString() ??
                errorMsg;
          } catch (e) {
            // If response is not JSON, provide a user-friendly message
            if (response.body.toLowerCase().contains('error')) {
              errorMsg =
                  'Server error occurred. Please check your input and try again.';
            } else {
              errorMsg =
                  'Server error: ${response.statusCode}. Please try again.';
            }
          }
        }

        return {
          'status': '0',
          'msg': errorMsg,
          'statusCode': response.statusCode,
        };
      }
    } catch (e) {
      
      return {
        'status': '0',
        'msg':
            'Error ${id != null ? 'editing' : 'adding'} daily assignment: $e',
      };
    }
  }

  // Delete daily assignment
  // API: https://demo.smart-school.in/api/webservice/deletedailyassignment
  // Method: POST
  // Body: {"id": "405"}
  // Response: {"status": "1", "msg": "Success"}
  static Future<Map<String, dynamic>> deleteDailyAssignment(
    String assignmentId, {
    String? studentId,
    String? studentSessionId,
  }) async {
    try {
      
      
      
      

      // Validate assignment ID
      if (assignmentId.isEmpty || assignmentId.trim().isEmpty) {
        
        return {'status': '0', 'msg': 'Assignment ID is required'};
      }

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': '0',
          'msg': 'Please configure the base URL in settings',
        };
      }

      final endpoint = await AppConfig.getApiEndpoint('deletedailyassignment');

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'application/json';

      // Normalize cookie to ci_session format
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        var normalized = cookie.trim();
        if (!normalized.startsWith('ci_session=')) {
          final match = RegExp(r'ci_session=([^;]+)').firstMatch(normalized);
          normalized = match != null
              ? 'ci_session=${match.group(1)}'
              : 'ci_session=$normalized';
        }
        headers['Cookie'] = normalized.split(';').first.trim();
      }

      String resolvedStudentId = studentId?.trim().isNotEmpty == true
          ? studentId!.trim()
          : '';
      if (resolvedStudentId.isEmpty) {
        resolvedStudentId = await AuthService.getStudentId();
      }

      final payload = <String, String>{'id': assignmentId.trim()};
      if (resolvedStudentId.isNotEmpty) {
        payload['student_id'] = resolvedStudentId;
      }
      if (studentSessionId != null && studentSessionId.trim().isNotEmpty) {
        payload['student_session_id'] = studentSessionId.trim();
      }

      final body = jsonEncode(payload);
      
      
      

      final response = await http
          .post(Uri.parse(endpoint), headers: headers, body: body)
          .timeout(const Duration(seconds: 30));

      
      

      if (response.statusCode == 200 &&
          !ResponseValidator.isHtmlResponse(response.body)) {
        try {
          final data = jsonDecode(response.body);
          final status = data['status'];
          final msg = data['msg'] ?? data['message'];
          final ok =
              status == '1' ||
              status == 1 ||
              status == true ||
              msg?.toString().toLowerCase() == 'success';
          if (ok) {
            return {'status': '1', 'msg': msg?.toString() ?? 'Success'};
          }
          return {
            'status': '0',
            'msg': msg?.toString() ?? 'Failed to delete assignment',
          };
        } catch (e) {
          
        }
      } else {
        
      }

      return {
        'status': '0',
        'msg': 'Failed to delete assignment. Please try again.',
      };
    } catch (e) {
      
      return {'status': '0', 'msg': 'Error deleting daily assignment: $e'};
    }
  }
}
