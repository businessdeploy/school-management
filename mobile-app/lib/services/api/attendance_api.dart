import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/url_manager.dart';
import '../../utils/dynamic_api_headers.dart';
import '../../config/app_config.dart';

class AttendanceApi {
  /// Fetch attendance records for given student, month, and year
  static Future<Map<String, dynamic>> getAttendance(
    String studentId, {
    String? month,
    String? year,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      
      // If no base URL is configured, return error
      if (baseUrl.isEmpty) {
        
        return {
          'status': 0,
          'message': 'No base URL configured. Please set the school URL first.',
          'attendance': [],
        };
      }
      
      // Try both known endpoints (installations differ)
      final endpoints = [
        Uri.parse(await AppConfig.getApiEndpoint('getAttendance')),
        Uri.parse(await AppConfig.getApiEndpoint('getAttendenceRecords')),
      ];
      final headers = await DynamicApiHeaders.getCompleteHeaders();

      // Optional: Attach saved session cookie (if backend requires)
      final cookie = await _getSessionCookie();
      if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;

      // Default month/year (fallbacks)
      final now = DateTime.now();

      // Helper to normalize and extract attendance list from various API formats
      List<Map<String, dynamic>> extractAttendanceList(
        Map<String, dynamic> parsed,
      ) {
        // Common keys used by different Smart School versions / installations
        const possibleKeys = [
          'data',
          'attendance',
          'attendence',
          'attendance_list',
          'attendence_list',
          'records',
          'result',
          'attendanceData',
          'attendance_records',
        ];

        for (final key in possibleKeys) {
          final value = parsed[key];
          if (value is List && value.isNotEmpty) {
            return List<Map<String, dynamic>>.from(
              value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
            );
          }
        }

        // Some APIs nest attendance inside "data" → { data: { attendance: [...] } }
        if (parsed['data'] is Map) {
          final data = parsed['data'] as Map;
          for (final key in possibleKeys) {
            final value = data[key];
            if (value is List && value.isNotEmpty) {
              return List<Map<String, dynamic>>.from(
                value.whereType<Map>().map((e) => Map<String, dynamic>.from(e)),
              );
            }
          }
        }

        return <Map<String, dynamic>>[];
      }

      Future<Map<String, dynamic>> tryCall(
        Uri url,
        Map<String, dynamic> bodyMap,
        String label,
      ) async {
        final bodyStr = jsonEncode(bodyMap);
        final res = await http.post(url, headers: headers, body: bodyStr);

        if (res.statusCode != 200 || res.body.contains('<!DOCTYPE html>')) {
          return {'status': 0};
        }

        final parsed = jsonDecode(res.body);
        if (parsed is! Map<String, dynamic>) {
          return {'status': 0};
        }

        final list = extractAttendanceList(parsed);
        if (list.isEmpty) {
          return {'status': 0};
        }

        return {
          'status': 1,
          'message': parsed['message']?.toString() ?? 'Attendance loaded successfully',
          'attendance': list,
          'attendence_type': parsed['attendence_type'] ?? parsed['attendance_type'] ?? [],
        };
      }

      // Try: endpoint x body variants (strict cURL first, then with month/year)
      final variants = <Map<String, dynamic>>[
        {
          'student_id': studentId,
        },
        {
          'student_id': studentId,
          'month': month ?? now.month.toString(),
          'year': year ?? now.year.toString(),
        },
      ];

      // Try all endpoint x body variants in parallel for maximum speed
      final List<Future<Map<String, dynamic>?>> trials = [];

      for (final ep in endpoints) {
        for (int i = 0; i < variants.length; i++) {
          final variant = variants[i];
          final label = i == 0 ? 'primary' : 'with-month-year';
          
          trials.add(() async {
            try {
              final result = await tryCall(ep, variant, label).timeout(const Duration(seconds: 10));
              if (result != null && result['status'] == 1) {
                return result;
              }
            } catch (_) {}
            return null;
          }());
        }
      }

      // Wait for all to finish or time out
      final results = await Future.wait(trials);
      for (final r in results) {
        if (r != null && r['status'] == 1) {
          return r;
        }
      }

      return {
        'status': 0,
        'message': 'no attendance marked yet',
        'attendance': [],
      };
    } catch (e) {
      
      return {
        "status": 0,
        "message": "Exception occurred: $e",
        "attendance": [],
      };
    }
  }


  /// Read stored session cookie (if exists)
  static Future<String?> _getSessionCookie() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('session_cookie');
    } catch (e) {
      
      return null;
    }
  }
}
