import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../config/app_config.dart';

class PendingTasksApi {
  // Get pending tasks
  // API: https://demo.smart-school.in/api/webservice/getTask
  // Body: {"user_id":"195"} (exact format from working curl)
  // Headers: Auth-Key, Client-Service, Content-Type, Authorization, User-ID, Cookie
  static Future<Map<String, dynamic>> getPendingTasks(String userId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'tasks': [],
        };
      }
      
      // Primary endpoint as per working curl: getTask (singular)
      final endpoints = [
        await AppConfig.getApiEndpoint('getTask'), // Primary endpoint (from working curl)
        await AppConfig.getApiEndpoint('getPendingTasks'), // Fallback
        await AppConfig.getApiEndpoint('getTasks'),
        await AppConfig.getApiEndpoint('getUserTasks'),
        await AppConfig.getApiEndpoint('tasks')
      ];

      // Get dynamic headers (Authorization, User-ID, Auth-Key, Client-Service, etc.)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Add session cookie if available (from login response)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie;
      }

      // Body format as per working curl: {"user_id":"195"} (exact format)
      final body = jsonEncode({'user_id': userId});

      // Try endpoints - use getTask first (from working curl)
      for (String endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);
          final response = await http.post(url, headers: headers, body: body);
          
          // Check if response is HTML (error page)
          if (ResponseValidator.isHtmlResponse(response.body)) {
            continue; // Try next endpoint
          }

          if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
            
            // Capture session cookie from response headers (if not already set)
            final setCookieHeader = response.headers['set-cookie'];
            if (setCookieHeader != null && setCookieHeader.isNotEmpty && (cookie == null || cookie.isEmpty)) {
              final cookies = setCookieHeader.split(',');
              if (cookies.isNotEmpty) {
                final sessionCookie = cookies.first.trim();
                await _saveSessionCookie(sessionCookie);
              }
            }
            
            // Parse JSON and check multiple possible keys
            try {
              final jsonData = jsonDecode(response.body);
              
              List<dynamic>? tasksList;
              
              if (jsonData is List) {
                tasksList = jsonData;
              } else if (jsonData is Map) {
                
                // Check multiple possible keys for tasks data
                for (String key in [
                  'tasks', 
                  'task_list', 
                  'data', 
                  'result', 
                  'pending_tasks', 
                  'task_array',
                  'list',
                  'items',
                ]) {
                  if (jsonData[key] != null) {
                    if (jsonData[key] is List) {
                      tasksList = jsonData[key] as List;
                      break;
                    }
                  }
                }
              }
              
              // Always return data, even if empty list
              if (tasksList != null) {
                return {
                  'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                  'message': jsonData is Map ? (jsonData['message'] ?? 'Success') : 'Success',
                  'tasks': tasksList,
                };
              } else {
                return {
                  'status': jsonData is Map ? (jsonData['status'] ?? 1) : 1,
                  'message': jsonData is Map ? (jsonData['message'] ?? 'No tasks found') : 'No tasks found',
                  'tasks': [],
                };
              }
            } catch (e) {
              
              // Fallback to ResponseValidator
              final data = ResponseValidator.validateAndParseJson(
                response.body,
                'tasks',
              );
              
              // Check multiple keys in fallback
              List<dynamic>? fallbackTasksList;
              
              for (String key in ['tasks', 'task_list', 'data', 'result', 'pending_tasks', 'task_array']) {
                if (data[key] != null && data[key] is List) {
                  fallbackTasksList = data[key] as List;
                  break;
                }
              }
              
              if (fallbackTasksList == null || fallbackTasksList.isEmpty) {
                fallbackTasksList = [];
              }
              
              return {
                'status': data['status'] ?? 1,
                'message': data['message'] ?? 'Success',
                'tasks': fallbackTasksList,
              };
            }
          }
        } catch (e) {
          
        }
      }

      // If no endpoint works, return error
      return {
        'status': 0,
        'message': 'Failed to load pending tasks. Please try again later.',
        'tasks': [],
      };
    } catch (e) {
      
      return {
        'status': 0,
        'message': 'Error loading pending tasks: $e',
        'tasks': [],
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
  
  // Save session cookie to SharedPreferences
  static Future<void> _saveSessionCookie(String cookie) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session_cookie', cookie);
      
    } catch (e) {
      
    }
  }

  // Add/Create a new task
  // API: https://devx.webfeb.com/ss720devaddoninst/api/webservice/addTask
  // cURL format:
  // curl --location 'https://devx.webfeb.com/ss720devaddoninst/api/webservice/addTask' \
  // --header 'Client-Service: smartschool' \
  // --header 'Auth-Key: schoolAdmin@' \
  // --header 'User-ID: 51' \
  // --header 'Authorization: OAOQMwMwNw' \
  // --header 'Content-Type: application/json' \
  // --header 'Cookie: ci_session=7817sm8paohmq9ais2lg22ltubbtisf4' \
  // --data '{
  //     "event_title": "Test Task",
  //     "date": "2025-12-20",
  //     "user_id": "17",
  //     "task_id": ""
  // }'
  static Future<Map<String, dynamic>> addTask({
    required String userId,
    required String title,
    required String dueDate,
    String? taskId, // Optional: if provided, will edit the task
  }) async {
    try {

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': '0',
          'message': 'Please configure the base URL in settings',
        };
      }

      // Primary endpoint: addTask (as per curl command)
      final endpoints = [
        await AppConfig.getApiEndpoint('addTask'), // Primary endpoint (from curl)
        await AppConfig.getApiEndpoint('createTask'),
        await AppConfig.getApiEndpoint('addtask'),
        await AppConfig.getApiEndpoint('create_task'),
        await AppConfig.getApiEndpoint('saveTask'),
        await AppConfig.getApiEndpoint('save_task'),
      ];

      // Get dynamic headers (all values are dynamic)
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      // Ensure Content-Type is application/json (as per cURL)
      headers['Content-Type'] = 'application/json';
      
      
      // Add session cookie if available (dynamic)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        // Ensure cookie format is correct (should start with ci_session=)
        String cookieValue = cookie;
        if (!cookieValue.startsWith('ci_session=')) {
          // If it doesn't start with ci_session=, add it
          cookieValue = 'ci_session=$cookie';
        }
        headers['Cookie'] = cookieValue;
      }

      // Build request body as per curl command format (EXACT MATCH)
      // Fields: event_title, date, user_id, task_id (empty for new tasks, provided for editing)
      // Note: user_id in body should be the student/user ID, not the User-ID header value
      final requestBody = {
        'event_title': title.trim(), // Dynamic: from user input
        'date': dueDate.trim(), // Dynamic: from user input (format: YYYY-MM-DD)
        'user_id': userId.trim(), // Dynamic: from AuthService (student ID)
        'task_id': taskId?.trim() ?? '', // Empty string for new tasks, task_id for editing (as per cURL)
        // User pattern: status: "0" for pending/unchecked (consistent with markTask), status: "1" for completed/checked
        if (taskId == null || taskId.isEmpty) ...{
          'status': 'no', // Default status for new tasks is 'no' (pending)
          'is_active': 'yes', // is_active: yes means it's an active event/entry
          'active': 'yes', // Add 'active' key as well, just in case (like markTask)
        },
      };
      
      final body = jsonEncode(requestBody);
      

      for (String endpoint in endpoints) {
        try {
          final url = Uri.parse(endpoint);
          final response = await http.post(url, headers: headers, body: body);
          
          if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
            try {
              final jsonData = jsonDecode(response.body);
              
              // Check status in multiple formats
              final statusValue = jsonData['status'];
              final status = statusValue?.toString() ?? '0';
              
              // Check for success in multiple ways
              final isSuccess = status == '1' ||
                  status == '1.0' ||
                  statusValue == 1 ||
                  statusValue == '1' ||
                  (statusValue is String && statusValue.toLowerCase() == 'success') ||
                  jsonData['success'] == true ||
                  jsonData['success'] == 'true' ||
                  jsonData['success'] == 1 ||
                  jsonData['success'] == '1';
              
              final message = jsonData['message'] ?? 
                             jsonData['msg'] ?? 
                             jsonData['Message'] ??
                             jsonData['error'] ??
                             jsonData['Error'] ??
                             (isSuccess ? 'Task added successfully' : 'Failed to add task');
              if (isSuccess) {
                return {
                  'status': '1',
                  'message': message,
                  'success': true,
                  'response': jsonData, // Include full response for debugging
                };
              } else {
                // Return the error response immediately (don't try other endpoints)
                // This allows the UI to show the actual error message from the API
                return {
                  'status': status,
                  'message': message,
                  'success': false,
                  'response': jsonData, // Include full response for debugging
                };
              }
            } catch (e) {
              // If we got a 200 response but can't parse it, try next endpoint
              continue;
            }
          }
        } catch (e) {
          continue;
        }
      }
      return {
        'status': '0',
        'message': 'Failed to add task: All endpoints failed',
      };
    } catch (e) {
      return {
        'status': '0',
        'message': 'Error adding task: $e',
      };
    }
  }


  // Delete a task
  // API: https://devx.webfeb.com/ss720devaddoninst/api/webservice/deletetask
  // Body:  // Delete a task
  // Delete a task
  static Future<Map<String, dynamic>> deleteTask(String taskId) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {
          'status': '0',
          'message': 'Please configure the base URL in settings',
          'success': false,
        };
      }

      final endpoints = [
        await AppConfig.getApiEndpoint('deletetask'),
        await AppConfig.getApiEndpoint('deleteTask'),
        await AppConfig.getApiEndpoint('removeTask'),
      ];

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'application/json';
      
      // Add session cookie
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        String cookieValue = cookie;
        if (!cookieValue.startsWith('ci_session=')) {
          cookieValue = 'ci_session=$cookie';
        }
        headers['Cookie'] = cookieValue;
      }

      final body = jsonEncode({'task_id': taskId});

      for (String endpoint in endpoints) {
        try {
          final response = await http.post(
            Uri.parse(endpoint),
            headers: headers,
            body: body,
          );

          if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
            final jsonData = jsonDecode(response.body);
            
            final status = jsonData['status']?.toString() ?? '0';
            final isSuccess = status == '1' || jsonData['success'] == true;
            final message = jsonData['msg'] ?? jsonData['message'] ?? (isSuccess ? 'Task deleted successfully' : 'Failed to delete task');

            if (isSuccess) {
              return {
                'status': '1',
                'message': message,
                'success': true,
              };
            }
          }
        } catch (e) {
          // Continue to next endpoint
        }
      }

      return {
        'status': '0',
        'message': 'Failed to delete task',
        'success': false,
      };

    } catch (e) {
      return {
        'status': '0',
        'message': 'Error deleting task: $e',
        'success': false,
      };
    }
  }

  // Mark task as completed/incomplete
  static Future<Map<String, dynamic>> markTask({
    required String taskId,
    required bool isCompleted,
    String? title,
    String? date,
    String? userId,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'Base URL not configured'};
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie.startsWith('ci_session=') ? cookie : 'ci_session=$cookie';
      }
      
      final activeStatus = isCompleted ? 'no' : 'yes';
      final statusValue = isCompleted ? '1' : '0';
      
      final endpoints = [
        await AppConfig.getApiEndpoint('markasdone'),
        await AppConfig.getApiEndpoint('markTask'),
        await AppConfig.getApiEndpoint('addTask'), // Some Smart School use addTask/editTask for toggling
        await AppConfig.getApiEndpoint('updateTaskStatus'),
        await AppConfig.getApiEndpoint('editTask'), 
        await AppConfig.getApiEndpoint('todo'),
        await AppConfig.getApiEndpoint('addtodo'),
      ];

      final bodyMap = {
        'task_id': taskId,
        'status': statusValue,
        'id': taskId,
        'active': activeStatus,
        'is_active': activeStatus,
        'completed': isCompleted ? '1' : '0',
      };

      if (title != null && title.isNotEmpty) {
        bodyMap['event_title'] = title;
        bodyMap['title'] = title;
      }
      if (date != null && date.isNotEmpty) {
         if (date.contains('/')) {
            final parts = date.split('/');
            if (parts.length == 3) {
               bodyMap['date'] = '${parts[2]}-${parts[1]}-${parts[0]}';
            } else {
               bodyMap['date'] = date;
            }
         } else {
            bodyMap['date'] = date;
         }
      }
      if (userId != null && userId.isNotEmpty) bodyMap['user_id'] = userId;

      String lastErrorMessage = 'Could not find a working endpoint to update task status';

      for (var endpoint in endpoints) {
        // Try BOTH JSON and Form-Data for each endpoint
        final variants = [
           {'type': 'json', 'contentType': 'application/json'},
           {'type': 'form', 'contentType': 'application/x-www-form-urlencoded'},
        ];

        for (var variant in variants) {
          try {
            final url = Uri.parse(endpoint);
            final variantHeaders = Map<String, String>.from(headers);
            variantHeaders['Content-Type'] = variant['contentType']!;

            http.Response response;
            if (variant['type'] == 'json') {
              response = await http.post(url, headers: variantHeaders, body: jsonEncode(bodyMap));
            } else {
              // Create form-encoded body string
              final formBody = bodyMap.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}').join('&');
              response = await http.post(url, headers: variantHeaders, body: formBody);
            }
            
            if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
              final data = jsonDecode(response.body);
              final respStatus = data['status']?.toString() ?? '0';
              
              if (respStatus == '1' || 
                  data['result'] == 'success' || 
                  data['success'] == true || 
                  data['success'] == 'true' ||
                  (data['message'] != null && data['message'].toString().toLowerCase().contains('success'))) {
                return {
                  'status': 1, 
                  'message': data['message'] ?? data['msg'] ?? 'Task updated successfully',
                  'data': data
                };
              } else {
                if (data['message'] != null) lastErrorMessage = data['message'];
                else if (data['msg'] != null) lastErrorMessage = data['msg'];
              }
            }
          } catch (e) {
            // Continue
          }
        }
      }

      return {'status': 0, 'message': lastErrorMessage};
    } catch (e) {
      return {'status': 0, 'message': 'Internal error: $e'};
    }
  }

  // New Update Task Status API as per user's request
  // API: https://devx.webfeb.com/ss2526demo/api/webservice/updatetask
  // status: "yes" (checked) / "no" (unchecked)
  static Future<Map<String, dynamic>> updateTaskStatus({
    required String taskId,
    required bool isCompleted,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        return {'status': 0, 'message': 'Base URL not configured'};
      }

      final url = Uri.parse(await AppConfig.getApiEndpoint('updatetask'));
      
      // Get headers and explicitly set Content-Type to text/plain to match user's working curl
      final headers = await DynamicApiHeaders.getCompleteHeaders();
      headers['Content-Type'] = 'text/plain';

      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) {
        headers['Cookie'] = cookie.startsWith('ci_session=') ? cookie : 'ci_session=$cookie';
      }

      final body = jsonEncode({
        'task_id': taskId.toString(),
        'status': isCompleted ? 'no' : 'yes', 
      });

      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode == 200 && !ResponseValidator.isHtmlResponse(response.body)) {
        final data = jsonDecode(response.body);
        // API returns status: "1" for success as per curl response
        final isSuccess = data['status'] == 1 || data['status'] == '1' || data['success'] == true;
        return {
          'status': isSuccess ? 1 : 0,
          'message': data['message'] ?? data['msg'] ?? (isSuccess ? 'Success' : 'Failed'),
          'data': data
        };
      }
      return {'status': 0, 'message': 'Failed to update (HTTP ${response.statusCode})'};
    } catch (e) {
      return {'status': 0, 'message': 'Internal error: $e'};
    }
  }
}

