import 'dart:convert';
import 'dart:io';
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';
import '../../config/app_config.dart';

class CommunicationApi {
  // Get leave list - Uses getApplyLeave API
  // cURL format:
  // curl --location 'https://devx.webfeb.com/ss720devaddoninst/api/webservice/getApplyLeave' \
  // --header 'Auth-Key: schoolAdmin@' \
  // --header 'Client-Service: smartschool' \
  // --header 'Content-Type: application/json' \
  // --header 'User-ID: 26' \
  // --header 'Authorization: MQNgMwMgMQ' \
  // --header 'Cookie: ci_session=...' \
  // --data '{
  //   "student_id": "26"
  // }'
  static Future<Map<String, dynamic>> getLeaveList(String studentId) async {
    try {
      // Validate student ID
      if (studentId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Student ID is required',
          'leaves': [],
          'data': [],
          'result_array': [],
        };
      }
      
      
      
      
      
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      
      // Validate base URL
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Base URL is not configured. Please set it in settings.',
          'leaves': [],
          'data': [],
          'result_array': [],
        };
      }

      // Primary endpoint as per API spec
      final endpoint = await AppConfig.getApiEndpoint('getApplyLeave');

      // Get dynamic headers (all values are dynamic)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      
      
      
      
      
      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
        
      } else {
        
      }

      // Use exact body format from API spec: {"student_id":"26"} (all dynamic)
      final body = jsonEncode({'student_id': studentId});

      
      

      final url = Uri.parse(endpoint);
      final response = await http.post(url, headers: headers, body: body);

      
      

      // Check if response is HTML (error page)
      if (ResponseValidator.isHtmlResponse(response.body)) {
        
        return {
          'status': 0,
          'message': 'API returned error page. Please try again later.',
          'leaves': [],
          'data': [],
          'result_array': [],
        };
      }

      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          
          
          List<dynamic>? leavesList;
          
          if (jsonData is List) {
            leavesList = jsonData;
            
          } else if (jsonData is Map) {
            
            
            // Check for result_array first (as per API spec)
            if (jsonData['result_array'] != null && jsonData['result_array'] is List) {
              leavesList = jsonData['result_array'] as List;
              
            } else {
              // Check other possible keys
              for (String key in [
                'leaves', 
                'result', 
                'data', 
                'leave_list', 
                'leave_requests',
                'list',
                'items',
              ]) {
                if (jsonData[key] != null && jsonData[key] is List) {
                  leavesList = jsonData[key] as List;
                  
                  break;
                }
              }
            }
          }
          
          // Return data with all possible keys for UI compatibility
          if (leavesList != null) {
            return {
              'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
              'message': jsonData is Map ? (jsonData['message'] ?? 'Success') : 'Success',
              'leaves': leavesList,
              'data': leavesList, // UI expects 'data' key
              'leave_list': leavesList, // UI also checks this
              'result_array': leavesList, // Preserve original key
            };
          } else {
            
            return {
              'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
              'message': jsonData is Map ? (jsonData['message'] ?? 'No leaves found') : 'No leaves found',
              'leaves': [],
              'data': [],
              'leave_list': [],
              'result_array': [],
            };
          }
        } catch (e) {
          
          
          return {
            'status': 0,
            'message': 'Error parsing response: $e',
            'leaves': [],
            'data': [],
            'result_array': [],
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load leaves: ${response.statusCode}',
          'leaves': [],
          'data': [],
          'result_array': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading leaves: $e',
        'leaves': [],
      };
    }
  }

  // Get forum messages
  static Future<Map<String, dynamic>> getForumMessage(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('getForumMessage'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'studentId': studentId}); // Use correct parameter name as per API

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'forum_messages',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load forum messages',
          'forum_messages': [],
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading forum messages: $e',
        'forum_messages': [],
      };
    }
  }

  // Save comment
  static Future<Map<String, dynamic>> saveComment(String studentId, String message) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('saveComment'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();

      final body = jsonEncode({
        'student_id': studentId,
        'message': message,
      });

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = ResponseValidator.validateAndParseJson(
          response.body,
          'comment',
        );
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to save comment',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error saving comment: $e',
      };
    }
  }

  // Add leave request - Uses form-data as per API spec
  static Future<Map<String, dynamic>> addLeave(
    String studentId,
    String fromDate,
    String toDate,
    String applyDate,
    String reason,
    String? filePath,
  ) async {
    try {
      // Validate student ID
      if (studentId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Student ID is required',
        };
      }
      
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // Validate base URL
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Base URL is not configured. Please set it in settings.',
        };
      }
      
      final url = Uri.parse(await AppConfig.getApiEndpoint('addleave'));

      // Get dynamic headers (Authorization, Auth-Key, Client-Service, User-ID, etc.)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      
      // Remove Content-Type for multipart request (it will be set automatically)
      headers.remove('Content-Type');

      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Add headers (including dynamic Authorization, Auth-Key, Client-Service, User-ID, Cookie)
      request.headers.addAll(headers);
      
      // Add form fields as per API spec
      request.fields['student_id'] = studentId;
      request.fields['studentId'] = studentId; // Fallback for some backend versions
      
      // Get student_session_id (often required)
      try {
        final studentSessionId = await AuthService.getStudentSessionId();
        if (studentSessionId.isNotEmpty) {
          request.fields['student_session_id'] = studentSessionId;
          
        }
      } catch (e) {
        
      }

      request.fields['from_date'] = fromDate;
      request.fields['to_date'] = toDate;
      request.fields['apply_date'] = applyDate;
      request.fields['reason'] = reason;

      // Add file if provided
      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          // Validate file size (limit to 10MB)
          final fileSize = await file.length();
          if (fileSize > 10 * 1024 * 1024) {
            return {
              'status': 0,
              'message': 'File is too large. Maximum size is 10MB.',
            };
          }

          // Get file extension and content type
          final fileName = filePath.split('/').last;
          final fileExtension = fileName.split('.').last.toLowerCase();
          
          MediaType? mediaType;
          if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
            mediaType = MediaType('image', 'jpeg');
          } else if (fileExtension == 'png') {
            mediaType = MediaType('image', 'png');
          } else if (fileExtension == 'pdf') {
            mediaType = MediaType('application', 'pdf');
          }

          // Use 'file' as the field name (standard for this API)
          request.files.add(
            await http.MultipartFile.fromPath(
              'file', 
              filePath,
              contentType: mediaType,
            ),
          );
          
        }
      }

      
      
      

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      final responseBody = response.body;

      
      
      

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final data = jsonDecode(responseBody);
          return data;
        } catch (e) {
          
          if (response.statusCode == 200) {
            return {'status': 1, 'message': 'Success'};
          }
          return {'status': 0, 'message': 'Invalid server response'};
        }
      } else {
        // Try to parse error message
        String errorMsg = 'Failed to add leave request: ${response.statusCode}';
        try {
          final errorData = jsonDecode(responseBody);
          if (errorData is Map) {
            errorMsg = errorData['message']?.toString() ?? 
                       errorData['msg']?.toString() ?? 
                       errorData['error']?.toString() ?? 
                       errorMsg;
            // Check for nested error map (PHP validation)
            if (errorData['error'] is Map) {
              final eMap = errorData['error'] as Map;
              final detail = eMap.values.where((v) => v.toString().isNotEmpty).join(' ');
              if (detail.isNotEmpty) errorMsg = detail;
            }
          }
        } catch (_) {}
        
        
        
        return {
          'status': 0,
          'message': errorMsg,
          'raw_error': responseBody,
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error adding leave request: $e',
      };
    }
  }

  // Delete leave request
  static Future<Map<String, dynamic>> deleteLeave(String leaveId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      final url = Uri.parse(await AppConfig.getApiEndpoint('deleteLeave'));

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      final body = jsonEncode({'leave_id': leaveId});

      
      
      

      final response = await http.post(url, headers: headers, body: body);

      
      

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        return data;
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to delete leave request: ${response.statusCode}',
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error deleting leave request: $e',
      };
    }
  }

  // Update leave request - Uses form-data as per API spec
  static Future<Map<String, dynamic>> updateLeave(
    String leaveId,
    String fromDate,
    String toDate,
    String applyDate,
    String reason,
    String? filePath, {
    bool removeAttachment = false,
  }) async {
    try {
      // Validate leave ID
      if (leaveId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Leave ID is required',
        };
      }
      
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // Validate base URL
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Base URL is not configured. Please set it in settings.',
        };
      }
      
      final url = Uri.parse(await AppConfig.getApiEndpoint('updateLeave'));

      // Get dynamic headers (Authorization, Auth-Key, Client-Service, User-ID, etc.)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available (dynamic from login)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      
      // Remove Content-Type for multipart request (it will be set automatically)
      headers.remove('Content-Type');

      // Create multipart request
      final request = http.MultipartRequest('POST', url);
      
      // Add headers (including dynamic Authorization, Auth-Key, Client-Service, User-ID, Cookie)
      request.headers.addAll(headers);
      
      // Add form fields as per API spec
      request.fields['id'] = leaveId;
      request.fields['leave_id'] = leaveId; // Fallback
      
      // Get student_session_id
      try {
        final studentSessionId = await AuthService.getStudentSessionId();
        if (studentSessionId.isNotEmpty) {
          request.fields['student_session_id'] = studentSessionId;
          
        }
      } catch (e) {
        
      }

      request.fields['from_date'] = fromDate;
      request.fields['to_date'] = toDate;
      request.fields['apply_date'] = applyDate;
      request.fields['reason'] = reason;

      if (removeAttachment) {
        request.fields['remove_attachment'] = '1';
      }

      // Add file if provided
      if (filePath != null && filePath.isNotEmpty) {
        final file = File(filePath);
        if (await file.exists()) {
          // Validate file size
          final fileSize = await file.length();
          if (fileSize > 10 * 1024 * 1024) {
            return {
              'status': 0,
              'message': 'File is too large. Maximum size is 10MB.',
            };
          }

           // Get file extension and content type
          final fileName = filePath.split('/').last;
          final fileExtension = fileName.split('.').last.toLowerCase();
          
          MediaType? mediaType;
          if (fileExtension == 'jpg' || fileExtension == 'jpeg') {
            mediaType = MediaType('image', 'jpeg');
          } else if (fileExtension == 'png') {
            mediaType = MediaType('image', 'png');
          } else if (fileExtension == 'pdf') {
            mediaType = MediaType('application', 'pdf');
          }

          request.files.add(
            await http.MultipartFile.fromPath(
              'file', 
              filePath,
              contentType: mediaType,
            ),
          );
          
        }
      }

      
      
      

      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      
      

       if (streamedResponse.statusCode >= 200 && streamedResponse.statusCode < 300) {
        try {
          final data = jsonDecode(responseBody);
          return data;
        } catch (e) {
           if (streamedResponse.statusCode == 200) {
             return {'status': 1, 'message': 'Success'};
          }
           return {'status': 0, 'message': 'Invalid server response'};
        }
      } else {
         // Try to parse error message
        String errorMsg = 'Failed to update leave request: ${streamedResponse.statusCode}';
        try {
          final errorData = jsonDecode(responseBody);
          if (errorData['message'] != null) errorMsg = errorData['message'];
          else if (errorData['msg'] != null) errorMsg = errorData['msg'];
           else if (errorData['error'] != null) errorMsg = errorData['error'];
        } catch (_) {}

        
        return {
          'status': 0,
          'message': errorMsg,
        };
      }
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error updating leave request: $e',
      };
    }
  }

  // Get visitors
  static Future<Map<String, dynamic>> getVisitors(String studentId) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'visitors': [],
        };
      }
      
      // Try multiple endpoints to find the working one
      final endpoints = [
        await AppConfig.getApiEndpoint('getVisitors'),
        await AppConfig.getApiEndpoint('getVisitorBook'),
        await AppConfig.getApiEndpoint('visitors'),
        await AppConfig.getApiEndpoint('getStudentVisitors'),
        await AppConfig.getApiEndpoint('visitorBook')
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

      

      for (String endpoint in endpoints) {
        for (String body in bodyVariants) {
          try {
            
            final url = Uri.parse(endpoint);

            final response = await http.post(url, headers: headers, body: body);

            
            

            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
              
              
              // Parse JSON and check multiple possible keys
              try {
                final jsonData = jsonDecode(response.body);
                if (jsonData is Map) {
                  List<dynamic>? visitorsList;
                  
                  // Check multiple possible keys for visitors data
                  // Priority: result (actual API response) first
                  for (String key in ['result', 'visitors', 'data', 'visitor_list', 'visitor_book', 'visitor_array']) {
                    if (jsonData[key] != null && jsonData[key] is List) {
                      visitorsList = jsonData[key] as List;
                      
                      break;
                    }
                  }
                  
                  if (visitorsList != null) {
                    return {
                      'status': jsonData['status'] ?? 1,
                      'message': jsonData['message'] ?? 'Success',
                      'visitors': visitorsList,
                      'result': jsonData['result'] ?? visitorsList, // Preserve original key for UI
                    };
                  }
                }
              } catch (e) {
                
              }
              
              // Fallback to ResponseValidator
              final data = ResponseValidator.validateAndParseJson(
                response.body,
                'visitors',
              );
              
              // Check multiple keys in fallback
              if (data['visitors'] == null || (data['visitors'] as List).isEmpty) {
                for (String key in ['result', 'data', 'visitor_list']) {
                  if (data[key] != null && data[key] is List) {
                    data['visitors'] = data[key];
                    
                    break;
                  }
                }
              }
              
              if (data['visitors'] == null || (data['visitors'] as List).isEmpty) {
                
                data['visitors'] = [];
              }
              
              return data;
            }
          } catch (e) {
            
          }
        }
      }

      // If no endpoint works, return error
      
      return {
        'status': 0,
        'message': 'Failed to load visitors. Please try again later.',
        'visitors': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading visitors: $e',
        'visitors': [],
      };
    }
  }

  static Future<Map<String, dynamic>> addVisitor({
    required String studentId,
    required String purpose,
    required String name,
    required String contact,
    required String idProof,
    required String noOfPeople,
    required String date,
    required String inTime,
    required String outTime,
    required String note,
    String? filePath,
  }) async {
    try {
      
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'Base URL not configured',
        };
      }

      // Get student_session_id
      String studentSessionId = '';
      try {
        studentSessionId = await AuthService.getStudentSessionId();
      } catch (e) {
        
      }

      // Try multiple potential endpoints
      final endpoints = [
        '$baseUrl/api/webservice/addVisitorBook',
        '$baseUrl/api/webservice/addVisitor',
        '$baseUrl/api/webservice/addvisitor',
        '$baseUrl/api/webservice/add_visitor',
        '$baseUrl/api/webservice/visitorBook',
        '$baseUrl/api/webservice/saveVisitor'
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }
      
      headers.remove('Content-Type');

      for (String endpoint in endpoints) {
        try {
          
          final url = Uri.parse(endpoint);
          final request = http.MultipartRequest('POST', url);
          request.headers.addAll(headers);
          
          request.fields['student_id'] = studentId;
          request.fields['student_session_id'] = studentSessionId;
          request.fields['purpose'] = purpose;
          request.fields['name'] = name;
          request.fields['contact'] = contact;
          request.fields['id_proof'] = idProof;
          request.fields['no_of_people'] = noOfPeople;
          request.fields['date'] = date;
          request.fields['in_time'] = inTime;
          request.fields['out_time'] = outTime;
          request.fields['note'] = note;
          request.fields['meeting_with'] = ''; // Optional but added for completeness
          // Some backends might use user_id
          request.fields['user_id'] = studentId;

          if (filePath != null && filePath.isNotEmpty) {
            try {
              // Try both 'file' and 'attachment' as field names
              final file = await http.MultipartFile.fromPath('file', filePath);
              request.files.add(file);
              
              // If the backend expects 'attachment', we'd need a separate request or double files
              // but let's try 'file' first as it's common. 
              // Some systems like leave use 'attachment'. 
              // We'll try 'file' for now as it's what we used in uploadDocument.
              
            } catch (e) {
              
            }
          }

          
          

          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);

          
          

          if (response.statusCode != 404) {
             if (response.statusCode == 200) {
               return jsonDecode(response.body);
             } else {
               // If not 404 but not 200, maybe it's the correct endpoint but wrong parameters
               // Stay with this endpoint if it's not a generic 404
               return {
                 'status': 0,
                 'message': 'Failed to add visitor: ${response.statusCode}',
               };
             }
          }
          // If 404, continue to next endpoint
        } catch (e) {
          
        }
      }

      return {
        'status': 0,
        'message': 'Failed to find a working endpoint for adding visitor.',
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error: $e',
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
