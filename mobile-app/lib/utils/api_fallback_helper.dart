import 'package:flutter/foundation.dart';
import 'url_manager.dart';

class ApiFallbackHelper {
  /// Check if base URL is configured and return appropriate response
  static Future<Map<String, dynamic>?> checkBaseUrlAndReturnFallback({
    required String moduleName,
    required String dataKey,
    required List<Map<String, dynamic>> sampleData,
  }) async {
    try {
      final baseUrl = await UrlManager.getBaseUrl();
      
      if (baseUrl.isEmpty) {
        
        return {
          'status': 1,
          'message': 'Using sample data - No base URL configured',
          dataKey: sampleData,
        };
      }
      
      return null; // Continue with normal API call
    } catch (e) {
      
      return {
        'status': 1,
        'message': 'Using sample data due to error: $e',
        dataKey: sampleData,
      };
    }
  }
}
