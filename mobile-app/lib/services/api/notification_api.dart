import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/app_config.dart';
import '../../utils/dynamic_api_headers.dart';

/// Simple helper to register FCM tokens with the backend.
class NotificationApi {
  NotificationApi._();

  static Future<void> registerDeviceToken({
    required String studentId,
    required String token,
  }) async {
    try {
      final endpoint =
          await AppConfig.getApiEndpoint('updateDeviceToken');
      if (endpoint.isEmpty) {
        
        return;
      }

      final headers = await DynamicApiHeaders.getCompleteHeaders();
      final payload = jsonEncode({
        'student_id': studentId,
        'device_token': token,
        'token': token, // Alias for some backend versions
        'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      });

      final response = await http
          .post(Uri.parse(endpoint), headers: headers, body: payload)
          .timeout(AppConfig.requestTimeout);

      if (response.statusCode != 200) {
        
      } else {
        
        
      }
    } catch (e) {
      
    }
  }
}

