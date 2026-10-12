import 'dart:convert';
import 'package:flutter/foundation.dart';

class ResponseValidator {
  // Validate and parse JSON response
  static Map<String, dynamic> validateAndParseJson(
    String responseBody,
    String expectedKey,
  ) {
    try {
      // CRITICAL: Check for empty response body BEFORE parsing
      if (responseBody.isEmpty || responseBody.trim().isEmpty) {
        
        return {
          'status': 0,
          'message': 'Unable to process payment. Please try again later.',
          expectedKey: [],
        };
      }
      
      // Check if response is HTML (error page)
      if (responseBody.contains('<!DOCTYPE html>')) {
        
        return {
          'status': 0,
          'message': 'Server returned HTML error page',
          expectedKey: [],
        };
      }

      // Parse JSON
      final cleanedBody = cleanJsonResponse(responseBody);
      final data = jsonDecode(cleanedBody);
      
      // Check if it's a valid response structure
      if (data is Map<String, dynamic>) {
        
        
        return data;
      } else if (data is List) {
        return {
          'status': 1,
          'message': 'Success',
          expectedKey: data,
        };
      } else {
        return {
          'status': 0,
          'message': 'Unexpected response format',
          expectedKey: [],
        };
      }
    } catch (e) {
      
      
      // CRITICAL: Handle FormatException for empty input
      if (e is FormatException && e.message.contains('Unexpected end of input')) {
        
        return {
          'status': 0,
          'message': 'Unable to process payment. Please try again later.',
          expectedKey: [],
        };
      }
      
      // CRITICAL: Always return user-friendly message, never show technical errors
      String userMessage = 'Unable to process request. Please try again later.';
      
      // Only show technical details in debug logs, not to user
      if (e is FormatException) {
        userMessage = 'Unable to process payment. Please try again later.';
      }
      
      return {
        'status': 0,
        'message': userMessage,
        expectedKey: [],
      };
    }
  }

  // Check if response is HTML (error page)
  static bool isHtmlResponse(String responseBody) {
    return responseBody.contains('<!DOCTYPE html>') || 
           responseBody.contains('<html') ||
           responseBody.contains('<HTML');
  }

  // Validate API response status
  static bool isSuccessResponse(Map<String, dynamic> response) {
    return response['status'] == 1 || response['status'] == '1';
  }

  // Get error message from response
  static String getErrorMessage(Map<String, dynamic> response) {
    return response['message'] ?? 'Unknown error occurred';
  }

  // Validate and parse JSON response as Map (alias for validateAndParseJson)
  static Map<String, dynamic> validateAndParseJsonMap(
    String responseBody,
    String context,
  ) {
    return validateAndParseJson(responseBody, 'data');
  }

  // Validate and parse JSON response as List
  static List<Map<String, dynamic>> validateAndParseJsonList(
    String responseBody,
    String context,
  ) {
    try {
      // Check if response is HTML (error page)
      if (responseBody.contains('<!DOCTYPE html>')) {
        
        return [];
      }

      // Parse JSON
      final cleanedBody = cleanJsonResponse(responseBody);
      final data = jsonDecode(cleanedBody);
      
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      } else if (data is Map<String, dynamic> && data['data'] is List) {
        return (data['data'] as List).cast<Map<String, dynamic>>();
      } else {
        return [];
      }
    } catch (e) {
      
      return [];
    }
  }

  // Clean JSON response (strip PHP warnings/HTML)
  static String cleanJsonResponse(String body) {
    if (body.isEmpty) return '{"status": 0, "message": "Empty response"}';
    
    final trimmed = body.trim();
    // Quick check if it's already a valid-looking JSON object or array
    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) || 
        (trimmed.startsWith('[') && trimmed.endsWith(']'))) {
      return trimmed;
    }
    
    // Find the first and last structural characters
    final firstBrace = body.indexOf('{');
    final firstBracket = body.indexOf('[');
    
    int startIndex = -1;
    if (firstBrace != -1 && firstBracket != -1) {
      startIndex = firstBrace < firstBracket ? firstBrace : firstBracket;
    } else if (firstBrace != -1) {
      startIndex = firstBrace;
    } else if (firstBracket != -1) {
      startIndex = firstBracket;
    }
    
    if (startIndex == -1) {
      
      return '{"status": 0, "message": "Invalid server response format"}';
    }

    final lastBrace = body.lastIndexOf('}');
    final lastBracket = body.lastIndexOf(']');
    
    int endIndex = -1;
    if (lastBrace != -1 && lastBracket != -1) {
      endIndex = (lastBrace > lastBracket ? lastBrace : lastBracket) + 1;
    } else if (lastBrace != -1) {
      endIndex = lastBrace + 1;
    } else if (lastBracket != -1) {
      endIndex = lastBracket + 1;
    }

    if (endIndex == -1 || endIndex <= startIndex) {
      
      return '{"status": 0, "message": "Malformed server response"}';
    }

    final cleaned = body.substring(startIndex, endIndex);
    
    return cleaned;
    
    return cleaned;
  }

  // Generate a cURL command for debugging purposes and print it to terminal
  static String logAsCurl(String url, Map<String, String> headers, String body) {
    String curl = 'curl -X POST "$url"';
    headers.forEach((key, value) {
      curl += ' -H "$key: $value"';
    });
    curl += ' -d \'$body\'';
    
    if (kDebugMode) {
      debugPrint('\n[API CURL]:\n$curl\n');
    }
    
    return curl;
  }
}