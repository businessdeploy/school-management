import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../utils/url_manager.dart';
import '../../utils/response_validator.dart';
import '../../utils/dynamic_api_headers.dart';
import '../auth_service.dart';
import '../../config/app_config.dart';

class LibraryApi {
  // Get issued books
  // cURL: POST to getLibraryBookIssued with {"studentId": "1"}
  static Future<Map<String, dynamic>> getIssuedBooks(String studentId) async {
    try {
      
      
      

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'books': [],
        };
      }

      // Resolve student ID
      String resolvedStudentId = studentId.trim();
      if (resolvedStudentId.isEmpty ||
          resolvedStudentId.toLowerCase() == 'null') {
        final profile = await AuthService.getUserProfile();
        resolvedStudentId =
            (profile['student_id'] ?? profile['user_id'] ?? profile['id'] ?? '')
                .toString()
                .trim();
        
      }

      if (resolvedStudentId.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Student information missing. Please login again.',
          'books': [],
        };
      }

      // Get dynamic headers
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Ensure User-ID is set
      if (headers['User-ID'] == null || headers['User-ID']!.isEmpty) {
        final userId = await AuthService.getUserId();
        if (userId != null && userId.isNotEmpty) {
          headers['User-ID'] = userId;
          
        }
      }

      // Ensure Cookie is in correct format (ci_session=value)
      if (headers['Cookie'] != null && headers['Cookie']!.isNotEmpty) {
        String cookie = headers['Cookie']!.trim();
        if (!cookie.startsWith('ci_session=')) {
          final match = RegExp(r'ci_session=([^;]+)').firstMatch(cookie);
          if (match != null) {
            cookie = 'ci_session=${match.group(1)}';
          } else {
            cookie = 'ci_session=$cookie';
          }
          headers['Cookie'] = cookie;
        }
        if (cookie.contains(';')) {
          headers['Cookie'] = cookie.split(';').first.trim();
        }
      }

      // Build request
      final endpoint = await AppConfig.getApiEndpoint('getLibraryBookIssued');
      final body = jsonEncode({'studentId': resolvedStudentId.toString()});

      
      
      
      
      headers.forEach((key, value) {
        if (key == 'Authorization' || key == 'Cookie') {
          
        } else {
          
        }
      });

      // Make request
      final url = Uri.parse(endpoint);
      final response = await http.post(url, headers: headers, body: body);

      
      
      
      
      
      

      // Check for HTML error pages
      if (ResponseValidator.isHtmlResponse(response.body)) {
        
        return {
          'status': 0,
          'message': 'Server error. Please try again later.',
          'books': [],
        };
      }

      // Check for empty response
      if (response.body.trim().isEmpty) {
        
        return {
          'status': 0,
          'message': 'Empty response from server',
          'books': [],
        };
      }

      // Parse response
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          
          

          List<dynamic>? booksList;

          // Handle direct array response
          if (jsonData is List) {
            booksList = jsonData;
            
          } else if (jsonData is Map) {
            // Check multiple possible keys
            final possibleKeys = ['books', 'data', 'result', 'issued_books'];
            for (final key in possibleKeys) {
              if (jsonData[key] != null && jsonData[key] is List) {
                booksList = jsonData[key] as List;
                
                break;
              }
            }
          }

          final finalBooks = booksList ?? [];
          

          // Log sample data
          if (finalBooks.isNotEmpty) {
            final first = finalBooks[0];
            if (first is Map) {
              
            }
          }

          return {
            'status': jsonData is Map
                ? (jsonData['status'] ?? (finalBooks.isNotEmpty ? 1 : 0))
                : (finalBooks.isNotEmpty ? 1 : 0),
            'message': jsonData is Map
                ? (jsonData['message'] ?? 'Issued books loaded successfully')
                : 'Issued books loaded successfully',
            'books': finalBooks,
          };
        } catch (e) {
          
          
          return {
            'status': 0,
            'message': 'Error parsing response: $e',
            'books': [],
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load issued books: ${response.statusCode}',
          'books': [],
        };
      }
    } catch (e, stackTrace) {
      
      
      return {
        'status': 0,
        'message': 'Error loading issued books: $e',
        'books': [],
      };
    }
  }

  // Get all books
  // cURL: GET to getLibraryBooks (no body)
  static Future<Map<String, dynamic>> getBooks(String studentId) async {
    try {
      
      
      

      final baseUrl = await UrlManager.getBaseUrl();
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'Please configure the base URL in settings',
          'books': [],
        };
      }

      // Get dynamic headers
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Ensure User-ID is set
      if (headers['User-ID'] == null || headers['User-ID']!.isEmpty) {
        final userId = await AuthService.getUserId();
        if (userId != null && userId.isNotEmpty) {
          headers['User-ID'] = userId;
          
        }
      }

      // Ensure Cookie is in correct format (ci_session=value)
      if (headers['Cookie'] != null && headers['Cookie']!.isNotEmpty) {
        String cookie = headers['Cookie']!.trim();
        if (!cookie.startsWith('ci_session=')) {
          final match = RegExp(r'ci_session=([^;]+)').firstMatch(cookie);
          if (match != null) {
            cookie = 'ci_session=${match.group(1)}';
          } else {
            cookie = 'ci_session=$cookie';
          }
          headers['Cookie'] = cookie;
        }
        if (cookie.contains(';')) {
          headers['Cookie'] = cookie.split(';').first.trim();
        }
      }

      // Build request - GET method, no body
      final endpoint = await AppConfig.getApiEndpoint('getLibraryBooks');

      
      
      
      headers.forEach((key, value) {
        if (key == 'Authorization' || key == 'Cookie') {
          
        } else {
          
        }
      });

      // Make GET request (no body)
      final url = Uri.parse(endpoint);
      final response = await http.get(url, headers: headers);

      
      
      
      
      
      

      // Check for HTML error pages
      if (ResponseValidator.isHtmlResponse(response.body)) {
        
        return {
          'status': 0,
          'message': 'Server error. Please try again later.',
          'books': [],
        };
      }

      // Check for empty response
      if (response.body.trim().isEmpty) {
        
        return {
          'status': 0,
          'message': 'Empty response from server',
          'books': [],
        };
      }

      // Parse response
      if (response.statusCode == 200) {
        try {
          final jsonData = jsonDecode(response.body);
          
          

          List<dynamic>? booksList;

          // Handle direct array response
          if (jsonData is List) {
            booksList = jsonData;
            
          } else if (jsonData is Map) {
            // Check multiple possible keys
            final possibleKeys = ['books', 'data', 'result', 'library_books'];
            for (final key in possibleKeys) {
              if (jsonData[key] != null && jsonData[key] is List) {
                booksList = jsonData[key] as List;
                
                break;
              }
            }
          }

          final finalBooks = booksList ?? [];
          

          // Log sample data
          if (finalBooks.isNotEmpty) {
            final first = finalBooks[0];
            if (first is Map) {
              
            }
          }

          return {
            'status': jsonData is Map
                ? (jsonData['status'] ?? (finalBooks.isNotEmpty ? 1 : 0))
                : (finalBooks.isNotEmpty ? 1 : 0),
            'message': jsonData is Map
                ? (jsonData['message'] ?? 'Books loaded successfully')
                : 'Books loaded successfully',
            'books': finalBooks,
          };
        } catch (e) {
          
          
          return {
            'status': 0,
            'message': 'Error parsing response: $e',
            'books': [],
          };
        }
      } else {
        
        return {
          'status': 0,
          'message': 'Failed to load books: ${response.statusCode}',
          'books': [],
        };
      }
    } catch (e, stackTrace) {
      
      
      return {'status': 0, 'message': 'Error loading books: $e', 'books': []};
    }
  }
}
