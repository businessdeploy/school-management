import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import 'package:http_parser/http_parser.dart';

class DocumentApi {
  // Get documents
  static Future<Map<String, dynamic>> getDocuments(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'documents': [],
        };
      }
      
      // Primary endpoint as per API documentation
      final endpoints = [
        '$baseUrl/api/webservice/getDocument', // Primary endpoint (singular)
        '$baseUrl/api/webservice/getDocuments', // Fallback (plural)
        '$baseUrl/api/webservice/getStudentDocuments',
        '$baseUrl/api/webservice/documents',
        '$baseUrl/api/webservice/getMyDocuments',
        '$baseUrl/api/webservice/studentFiles'
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Body as per API documentation: {"student_id":"<dynamic>"} (snake_case)
      // Using dynamic studentId parameter from AuthService
      final body = jsonEncode({'student_id': studentId});

      
      

      for (String endpoint in endpoints) {
        try {
          
          final url = Uri.parse(endpoint);

          final response = await http.post(url, headers: headers, body: body);

          
          

          if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
            
            
            // Parse JSON - API can return direct array or wrapped object
            try {
              final jsonData = jsonDecode(response.body);
              
              
              List<dynamic>? documentsList;
              
              // Check if response is a direct array (as per API documentation)
              if (jsonData is List) {
                documentsList = jsonData;
                
              } else if (jsonData is Map) {
                
                
                // Check multiple possible keys for documents data (prioritize common ones)
                for (String key in [
                  'documents', 
                  'document_list', 
                  'data', 
                  'result', 
                  'files', 
                  'student_documents', 
                  'document_array',
                  'list',
                  'items',
                ]) {
                  if (jsonData[key] != null) {
                    
                    if (jsonData[key] is List) {
                      documentsList = jsonData[key] as List;
                      
                      break;
                    }
                  }
                }
              }
              
              // Always return data, even if empty list
              if (documentsList != null) {
                return {
                  'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                  'message': jsonData is Map ? (jsonData['message'] ?? 'Success') : 'Success',
                  'documents': documentsList,
                };
              } else {
                
                return {
                  'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                  'message': jsonData is Map ? (jsonData['message'] ?? 'No documents found') : 'No documents found',
                  'documents': [],
                };
              }
            } catch (e) {
              
              
            }
            
            // Fallback to ResponseValidator
            final data = ResponseValidator.validateAndParseJson(
              response.body,
              'documents',
            );
            
            // Check multiple keys in fallback
            if (data['documents'] == null || (data['documents'] as List).isEmpty) {
              for (String key in ['document_list', 'data', 'result', 'files']) {
                if (data[key] != null && data[key] is List) {
                  data['documents'] = data[key];
                  
                  break;
                }
              }
            }
            
            if (data['documents'] == null || (data['documents'] as List).isEmpty) {
              
              data['documents'] = [];
            }
            
            return data;
          }
        } catch (e) {
          
        }
      }

      // If no endpoint works, return error
      
      return {
        'status': 0,
        'message': 'Failed to load documents. Please try again later.',
        'documents': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading documents: $e',
        'documents': [],
      };
    }
  }

  // Upload document
  // API expects form-data with: file, student_id, title
  // Reference cURL:
  // curl --location 'https://devx.webfeb.com/ss720devaddoninst/api/webservice/uploadDocument' \
  // --header 'Auth-Key: schoolAdmin@' \
  // --header 'Client-Service: smartschool' \
  // --header 'User-ID: 26' \
  // --header 'Authorization: MQNgMwMgMQ' \
  // --form 'student_id="26"' \
  // --form 'title="hello"' \
  // --form 'file=@"path/to/file"'
  static Future<Map<String, dynamic>> uploadDocument(
    String studentId,
    String title,
    String? description, // Optional, not in API spec but kept for backward compatibility
    String filePath,
  ) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        
        return {
          'status': '0',
          'msg': 'Please configure the base URL in settings',
        };
      }
      
      final url = Uri.parse('$baseUrl/api/webservice/uploadDocument');

      // Get headers from DynamicApiHeaders
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Remove Content-Type from headers for multipart request (Flutter will set it with boundary)
      // This is critical - multipart requests need boundary in Content-Type
      // The cURL shows Content-Type: application/json but uses --form, which means it's actually multipart
      headers.remove('Content-Type');
      
      // Add session cookie(s) if available (as per cURL - multiple ci_session cookies)
      // Note: DynamicApiHeaders already adds Cookie, but we ensure it's present
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        // If Cookie header already exists from DynamicApiHeaders, append to it
        // Otherwise set it (as per cURL format: ci_session=value1; ci_session=value2; ...)
        if (headers.containsKey('Cookie') && headers['Cookie']!.isNotEmpty) {
          // Append if not already present
          if (!headers['Cookie']!.contains(cookie)) {
            headers['Cookie'] = '${headers['Cookie']}; $cookie';
          }
        } else {
          headers['Cookie'] = cookie;
        }
        final cookieValue = headers['Cookie']!;
        final cookiePreview = cookieValue.length > 80 ? '${cookieValue.substring(0, 80)}...' : cookieValue;
        
      } else {
        
      }
      
      // Ensure all required headers are present (as per cURL)
      if (!headers.containsKey('Auth-Key')) {
        
      } else {
        
      }
      if (!headers.containsKey('Client-Service')) {
        
      } else {
        
      }
      if (!headers.containsKey('User-ID')) {
        
      } else {
        
      }
      if (!headers.containsKey('Authorization')) {
        
      } else {
        final authHeader = headers['Authorization'];
      if (authHeader != null) {
        final authPreview = authHeader.length > 10 ? '${authHeader.substring(0, 10)}...' : authHeader;
        
      } else {
        
      }
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      // Validate file is readable
      try {
        await file.readAsBytes();
      } catch (e) {
        throw Exception('File is not readable: $e');
      }

      // Get file name for logging (preserve original filename)
      final fileName = filePath.split('/').last;
      final fileSize = await file.length();
      
      if (fileSize == 0) {
        throw Exception('File is empty: $fileName');
      }
      
      
      
      

      final request = http.MultipartRequest('POST', url);
      
      // Add headers
      // CRITICAL: The working cURL shows Client-Service as 'smartschool'
      headers['Client-Service'] = 'smartschool';
      
      // DO NOT set Content-Type manually for multipart requests, 
      // as it will overwrite the boundary set by http package.
      
      request.headers.addAll(headers);
      
      
      request.headers.forEach((key, value) {
        if (key.toLowerCase() == 'authorization') {
          
        } else {
          
        }
      });
      
      // Trim and validate student_id
      final studentIdTrimmed = studentId.trim();
      if (studentIdTrimmed.isEmpty) {
        throw Exception('Student ID cannot be empty');
      }
      final studentIdForField = studentIdTrimmed; // Removed leading space
      
      // Trim and validate title
      final titleTrimmed = title.trim();
      if (titleTrimmed.isEmpty) {
        throw Exception('Title cannot be empty');
      }
      
      // Add form fields as per API cURL reference
      request.fields['student_id'] = studentIdForField;
      request.fields['title'] = titleTrimmed;
      
      
      
      
      // Add description only if provided (not in API spec but some backends might accept it)
      if (description != null && description.trim().isNotEmpty) {
        request.fields['description'] = description.trim();
      }
      
      // Add file as per API cURL reference (form-data field name: 'file')
      // Preserve original filename from file path
      final originalFileName = filePath.split('/').last;
      
      // Determine content type based on extension
      // This is crucial for some servers to accept the file
      final extension = originalFileName.split('.').last.toLowerCase();
      String contentType = 'application/octet-stream'; // Default
      String subtype = 'octet-stream';
      
      if (['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
        contentType = 'image';
        subtype = extension == 'jpg' ? 'jpeg' : extension;
      } else if (extension == 'pdf') {
        contentType = 'application';
        subtype = 'pdf';
      } else if (['doc', 'docx'].contains(extension)) {
        contentType = 'application';
        subtype = 'msword';
      } else if (['xls', 'xlsx'].contains(extension)) {
        contentType = 'application';
        subtype = 'vnd.ms-excel';
      }
      
      

      final multipartFile = await http.MultipartFile.fromPath(
        'file', 
        filePath,
        filename: originalFileName, // Preserve original filename
        contentType: MediaType(contentType, subtype),
      );
      request.files.add(multipartFile);

      
      
      
      
      
      
      
      
      
      final authHeader = request.headers['Authorization'];
      if (authHeader != null) {
        final authPreview = authHeader.length > 15 ? '${authHeader.substring(0, 15)}...' : authHeader;
        
      } else {
        
      }
      
      
      
      
      
      if (request.fields.containsKey('description')) {
        
      }
      
      
      
      
      
      

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      
      
      
      
      
      
      

      if (response.statusCode == 200) {
        try {
          // Check if response is HTML (error page)
          if (ResponseValidator.isHtmlResponse(responseBody)) {
            
            return {
              'status': '0',
              'msg': 'Server error. Please try again later.',
            };
          }
          
          final data = jsonDecode(responseBody);
          
          
          
          
          
          // Check multiple possible success indicators
          // API might return status as string "1", number 1, or boolean true
          final status = data['status'];
          final statusStr = status?.toString().trim() ?? '0';
          final statusNum = status is int ? status : (status is String ? int.tryParse(statusStr) : null);
          
          // Get message for additional success detection
          final msg = data['msg']?.toString().toLowerCase() ?? '';
          final message = data['message']?.toString().toLowerCase() ?? '';
          
          // More lenient success detection - check multiple indicators
          bool isSuccess = false;
          
          // Check status field
          if (statusStr == '1' || statusNum == 1) {
            isSuccess = true;
            
          }
          // Check success field
          else if (data['success'] == true || data['success'] == 1 || data['success'] == '1' || data['success'] == 'true') {
            isSuccess = true;
            
          }
          // Check message content for success keywords
          else if (msg.contains('success') || msg.contains('uploaded') || msg.contains('saved') || 
                   msg.contains('completed') || msg.contains('added') ||
                   message.contains('success') || message.contains('uploaded') || message.contains('saved') ||
                   message.contains('completed') || message.contains('added')) {
            isSuccess = true;
            
          }
          // If status is not explicitly 0 or false, and no error message, consider it success
          else if (statusStr != '0' && statusNum != 0 && 
                   !msg.contains('error') && !msg.contains('fail') && 
                   !message.contains('error') && !message.contains('fail') &&
                   response.statusCode == 200) {
            // For 200 status code without explicit error, assume success
            isSuccess = true;
            
          }
          
          
          
          
          
          
          
          // API returns: {"status": "1", "msg": "Success"} or similar
          // Normalize response format
          return {
            'status': isSuccess ? '1' : '0',
            'msg': data['msg'] ?? data['message'] ?? (isSuccess ? 'Document uploaded successfully' : 'Upload failed'),
            'message': data['msg'] ?? data['message'] ?? (isSuccess ? 'Document uploaded successfully' : 'Upload failed'),
            'success': isSuccess,
            'data': data, // Include full response for debugging
          };
        } catch (e) {
          
          
          // If we get 200 but can't parse, check if response contains success indicators
          final responseLower = responseBody.toLowerCase();
          if (responseLower.contains('success') || 
              responseLower.contains('uploaded') || 
              responseLower.contains('saved') ||
              responseLower.contains('completed') ||
              responseLower.contains('added') ||
              responseLower.contains('"status":"1"') ||
              responseLower.contains('"status":1')) {
            
            return {
              'status': '1',
              'msg': 'Document uploaded successfully',
              'success': true,
            };
          }
          return {
            'status': '0',
            'msg': 'Error parsing server response: $e',
            'success': false,
          };
        }
      } else {
        
        
        return {
          'status': '0',
          'msg': 'Failed to upload document: ${response.statusCode}',
          'success': false,
        };
      }
    } catch (e) {
      
      return {
        'status': '0',
        'msg': 'Error uploading document: $e',
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
}
