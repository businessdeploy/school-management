import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http_parser/http_parser.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';
import '../../config/app_config.dart';

class HomeworkApi {
  // Get homework list
  static Future<Map<String, dynamic>> getHomework(
    String studentId, {
    String? homeworkStatus,
    String? subjectGroupSubjectId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'homework': [],
        };
      }

      // Prepare headers and body first
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add Cookie header if available (from login session)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Match cURL: {"student_id":"1","homework_status":"pending"}
      // Add subject filter if provided
      final bodyMap = {
        'student_id': studentId,
        'homework_status': homeworkStatus ?? 'pending',
      };
      
      // Add subject filter if provided
      if (subjectGroupSubjectId != null && subjectGroupSubjectId.isNotEmpty) {
        bodyMap['subject_group_subject_id'] = subjectGroupSubjectId;
      }
      
      final body = jsonEncode(bodyMap);

      // Try multiple endpoints to find the working one in parallel
      final List<String> endpoints = [
        await AppConfig.getApiEndpoint('getHomework'),
        await AppConfig.getApiEndpoint('getHomeworkList'),
        await AppConfig.getApiEndpoint('homework'),
        await AppConfig.getApiEndpoint('getStudentHomework'),
      ];

      final List<Future<Map<String, dynamic>?>> trials = [];

      for (String endpoint in endpoints) {
        trials.add(() async {
          try {
            final url = Uri.parse(endpoint);
            final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));

            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
              final Map<String, dynamic> data = jsonDecode(response.body);
              return data;
            }
          } catch (_) {}
          return null;
        }());
      }

      // Wait for all to complete or time out
      final results = await Future.wait(trials);
      for (final result in results) {
        if (result != null && result['status'] != 0) {
          return result;
        }
      }

      // If no endpoint works, return error
      return {
        'status': 0,
        'message': 'Failed to load homework from any endpoint',
        'homeworklist': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading homework: $e',
        'homeworklist': [],
      };
    }
  }

  /// Get detailed homework by ID
  static Future<Map<String, dynamic>> getHomeworkById(
    String homeworkId,
  ) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
        };
      }

      // Prepare headers
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Add homework_id to body
      final body = jsonEncode({'homework_id': homeworkId});

      // Try multiple endpoints for getHomeworkById
      final endpoints = [
        '$baseUrl/api/webservice/getHomeworkById',
        '$baseUrl/api/webservice/gethomeworkbyid',
        '$baseUrl/api/webservice/homeworkById',
        '$baseUrl/api/webservice/get_homework_by_id',
      ];

      for (String endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);
          final response = await http.post(url, headers: headers, body: body);

          if (response.statusCode == 200 &&
              !ResponseValidator.isHtmlResponse(response.body)) {
            return jsonDecode(response.body);
          }
        } catch (_) {}
      }

      return {
        'status': 0,
        'message': 'Failed to load homework details',
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
      };
    }
  }

  // Get subject list for homework
  static Future<Map<String, dynamic>> getSubjectList(String studentId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();

      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'subjects': [],
        };
      }

      // Try multiple endpoints to find the working one
      final endpoints = [
        '$baseUrl/api/webservice/getSubjectList',
        '$baseUrl/api/webservice/getSubjects',
        '$baseUrl/api/webservice/subjects',
        '$baseUrl/api/webservice/getStudentSubjects',
        // Removed getClassSubjects as it returns 404 on this server
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Try different parameter combinations
      final bodyVariants = [
        jsonEncode({'student_id': studentId}),
        jsonEncode({'studentId': studentId}),
        jsonEncode({'student_Id': studentId}),
        jsonEncode({'id': studentId}),
      ];


      // Create a list of all endpoint + body combinations to try in parallel
      final List<Future<Map<String, dynamic>?>> trials = [];

      for (String endpoint in endpoints) {
        for (String body in bodyVariants) {
          trials.add(() async {
            try {
              final url = Uri.parse(endpoint);
              final response = await http.post(url, headers: headers, body: body).timeout(const Duration(seconds: 10));

              if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
                try {
                  final jsonData = jsonDecode(response.body);
                  if (jsonData is Map) {
                    List<dynamic>? subjectsList;
                    for (String key in ['subjects', 'subject_list', 'data', 'result', 'subjectList', 'subjectListData']) {
                      if (jsonData[key] != null && jsonData[key] is List) {
                        subjectsList = jsonData[key] as List;
                        break;
                      }
                    }

                    if (subjectsList != null && subjectsList.isNotEmpty) {
                      return {
                        'status': 1,
                        'message': 'Success',
                        'subjects': subjectsList,
                      };
                    }
                  }
                } catch (_) {}
              }
            } catch (_) {}
            return null;
          }());
        }
      }

      // Wait for the first successful result or all to complete
      final results = await Future.wait(trials);
      for (final result in results) {
        if (result != null && result['status'] == 1) {
          return result;
        }
      }

      // If no endpoint works, return error
      return {
        'status': 0,
        'message': 'Failed to load subjects. Please try again later.',
        'subjects': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading subjects: $e',
        'subjects': [],
      };
    }
  }

  // Submit homework
  // API: https://demo.smart-school.in/api/webservice/addhomework
  // Method: POST
  // Headers: Auth-Key, Client-Service, Authorization, User-ID
  // Body (form-data): homework_id, student_id, message, file
  // Response: {"status": "1", "msg": "Success"}
  static Future<Map<String, dynamic>> submitHomework(
    String studentId,
    String homeworkId,
    String answer,
    String? filePath,
  ) async {
    try {

      final baseUrl = await UrlManager.getBaseUrl();

      // API endpoint: /api/webservice/addhomework
      final endpoint = '$baseUrl/api/webservice/addhomework';
      final url = Uri.parse(endpoint);

      // Get authentication headers dynamically
      // Headers required: Auth-Key, Client-Service, Authorization, User-ID
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Get User-ID dynamically from auth service
      final userProfile = await AuthService.getUserProfile();
      final userId = userProfile['user_id'] ?? userProfile['student_id'] ?? '';
      final studentSessionId = userProfile['student_session_id'] ?? '';

      // For multipart/form-data, Content-Type must be auto-set with boundary
      // Remove Content-Type header so it can be set automatically
      final multipartHeaders = Map<String, String>.from(headers);
      multipartHeaders.remove('Content-Type');

      // Ensure User-ID is set (required header)
      if (userId.isNotEmpty) {
        multipartHeaders['User-ID'] = userId;
      }
      
      // Add student_session_id to headers if needed by some backend configurations
      if (studentSessionId.isNotEmpty) {
        multipartHeaders['Student-Session-ID'] = studentSessionId;
      }

      // Add Cookie header if available (from login session)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        // Ensure cookie is in correct format (ci_session=value)
        String cookieValue = cookie.trim();
        if (!cookieValue.startsWith('ci_session=')) {
          // Extract ci_session value if cookie contains it
          final match = RegExp(r'ci_session=([^;]+)').firstMatch(cookieValue);
          if (match != null) {
            cookieValue = 'ci_session=${match.group(1)}';
          } else {
            cookieValue = 'ci_session=$cookieValue';
          }
        }
        multipartHeaders['Cookie'] = cookieValue;
      }


      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      request.headers.addAll(multipartHeaders);

      // Add form fields as per API spec:
      // homework_id, student_id, message, file
      final homeworkIdStr = homeworkId.toString().trim();
      final studentIdStr = studentId.toString().trim();
      final messageStr = answer.isNotEmpty ? answer.trim() : 'Homework Upload';

      // Validate IDs are not empty
      if (homeworkIdStr.isEmpty) {
        throw Exception(
          'Homework ID is required. Please refresh the homework list.',
        );
      }
      if (studentIdStr.isEmpty) {
        throw Exception('Student ID is required. Please login again.');
      }


      // Use standard field names as per API spec
      // The API expects: homework_id, student_id, message, file
      request.fields['homework_id'] = homeworkIdStr;
      request.fields['id'] = homeworkIdStr; // Alias for some backend versions
      request.fields['student_id'] = studentIdStr;
      request.fields['message'] = messageStr;
      request.fields['student_message'] = messageStr; // Alias for some backend versions
      
      // Add student_session_id if available (often required for correct record association)
      if (studentSessionId.isNotEmpty) {
        request.fields['student_session_id'] = studentSessionId;
      }


      // Add file if provided
      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          // Validate file size (limit to 10MB)
          final fileSize = await file.length();
          if (fileSize > 10 * 1024 * 1024) {
            throw Exception('File is too large. Maximum size is 10MB.');
          }

          if (fileSize == 0) {
            throw Exception(
              'Selected file is empty. Please select a valid file.',
            );
          }

          // Get file extension to determine MIME type
          final fileName = filePath.split('/').last;
          final fileExtension = fileName.split('.').last.toLowerCase();

          String contentType = 'application/octet-stream';
          if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
            contentType = 'image/jpeg';
          } else if (fileExtension == 'png') {
            contentType = 'image/png';
          } else if (fileExtension == 'pdf') {
            contentType = 'application/pdf';
          } else if (fileExtension == 'doc' || fileExtension == 'docx') {
            contentType = 'application/msword';
          } else if (fileExtension == 'gif') {
            contentType = 'image/gif';
          } else if (fileExtension == 'webp') {
            contentType = 'image/webp';
          }

          // Use fromPath instead of fromBytes for better compatibility
          // This matches the approach used in daily assignment uploads
          final fileFieldName = 'file';

          // Create MediaType for explicit content type setting
          MediaType? mediaType;
          if (contentType.contains('/')) {
            final parts = contentType.split('/');
            if (parts.length == 2) {
              mediaType = MediaType(parts[0], parts[1]);
            }
          }

          // Add primary file field 'file'
          request.files.add(
            await http.MultipartFile.fromPath(
              fileFieldName,
              filePath,
              filename: fileName,
              contentType: mediaType,
            ),
          );

          // Add fallback file field 'userfile' (common in Smart School/CodeIgniter)
          request.files.add(
            await http.MultipartFile.fromPath(
              'userfile',
              filePath,
              filename: fileName,
              contentType: mediaType,
            ),
          );
        }
      }

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      // Check if response is HTML (database error page)
      if (ResponseValidator.isHtmlResponse(responseBody)) {

        // Try to extract error message from HTML
        String errorMsg =
            'Database error occurred. Please check your homework ID and student ID.';
        if (responseBody.toLowerCase().contains('database error')) {
          errorMsg = 'Database error: Invalid homework or student information.';
        } else if (responseBody.toLowerCase().contains('foreign key')) {
          errorMsg =
              'Database error: Homework ID or Student ID not found. Please refresh the homework list.';
        } else if (responseBody.toLowerCase().contains('constraint')) {
          errorMsg =
              'Database error: Invalid data format. Please check your input.';
        }

        

        return {
          'status': 0,
          'msg': errorMsg,
          'message': errorMsg,
          'htmlResponse': true,
        };
      }

      // Handle both 200 and other success status codes
      if (streamedResponse.statusCode >= 200 &&
          streamedResponse.statusCode < 300) {
        try {
          final data = ResponseValidator.validateAndParseJson(
            responseBody,
            'submit homework',
          );

          // Check response status - handle both string and numeric status
          final dynamic status = data['status'];
          final dynamic msg = data['msg'] ?? data['message'] ?? data['validate_storage'];
          final dynamic error = data['error'];

          final bool isSuccess =
              status == 1 ||
              status == '1' ||
              status == true ||
              status.toString().toLowerCase() == 'success' ||
              (msg != null && msg.toString().toLowerCase().contains('success'));

          if (isSuccess) {
            
            // Extract attachment URL if present in response
            String? attachmentUrl;
            final possibleAttachmentKeys = [
              'attachment_url',
              'attachmentUrl',
              'file_url',
              'fileUrl',
              'student_logo',
              'studentLogo',
              'submission_url',
              'submissionUrl',
              'uploaded_file_url',
              'uploadedFileUrl',
            ];
            
            for (final key in possibleAttachmentKeys) {
              if (data[key] != null && data[key].toString().trim().isNotEmpty) {
                attachmentUrl = data[key].toString().trim();
                break;
              }
            }
            
            return {
              'status': 1,
              'msg': msg?.toString() ?? 'Success',
              'message': msg?.toString() ?? 'Success',
              if (attachmentUrl != null) 'attachment_url': attachmentUrl,
            };
          } else {
            // Check for validate_storage first as per user request
            String errorMsg = data['validate_storage']?.toString() ??
                msg?.toString() ??
                data['message']?.toString() ??
                'Failed to submit homework';
            
            // Handle detailed error object (e.g. {"file": "File type not allowed"})
            if (error != null) {
              if (error is Map) {
                final errorList = <String>[];
                error.forEach((key, value) {
                  // Only add error if message is not empty
                  if (value != null && value.toString().trim().isNotEmpty) {
                     errorList.add('$value');
                  }
                });
                if (errorList.isNotEmpty) {
                  errorMsg = errorList.join('\n');
                }
              } else {
                errorMsg = error.toString();
              }
            }
            
            return {
              'status': 0, 
              'msg': errorMsg, 
              'message': errorMsg, 
              'error': error,
              'validate_storage': data['validate_storage'],
            };
          }
        } catch (parseError) {
          

          if (responseBody.toLowerCase().contains('success') ||
              responseBody.toLowerCase().contains('"status":1') ||
              responseBody.toLowerCase().contains('"status":"1"')) {
            return {
              'status': 1,
              'msg': 'Success',
              'message': 'Homework submitted successfully',
            };
          }

          return {
            'status': 0,
            'msg': 'Failed to parse server response',
            'message': 'Failed to parse server response: $parseError',
          };
        }
      } else {

        // Try to parse error response
        String errorMsg = 'Server error: ${streamedResponse.statusCode}';
        try {
          final errorData = jsonDecode(responseBody);
          errorMsg =
              errorData['msg']?.toString() ??
              errorData['message']?.toString() ??
              errorData['error']?.toString() ??
              (responseBody.isNotEmpty ? responseBody : errorMsg);

          return {
            'status': 0,
            'msg': errorMsg,
            'message': errorMsg,
            'statusCode': streamedResponse.statusCode,
            'responseBody': responseBody,
          };
        } catch (e) {

          // Try to extract any error message from the raw response
          if (responseBody.isNotEmpty) {
            // Look for common error patterns
            if (responseBody.toLowerCase().contains('error')) {
              errorMsg = responseBody;
            } else if (responseBody.length < 200) {
              errorMsg = responseBody; // Use short responses as error message
            }
          }

          return {
            'status': 0,
            'msg': errorMsg,
            'message': errorMsg,
            'statusCode': streamedResponse.statusCode,
            'responseBody': responseBody,
          };
        }
      }
    } catch (e) {
      

      return {
        'status': 0,
        'msg': 'Error submitting homework: $e',
        'message': 'Error submitting homework: $e',
      };
    }
  }

  // Helper method to get session cookie from stored login data
  static Future<String?> _getSessionCookie() async {
    try {
      // Try to get cookie from SharedPreferences (if stored during login)
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
}
