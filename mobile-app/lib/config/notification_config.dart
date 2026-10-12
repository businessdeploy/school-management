import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'app_config.dart';

/// A lightweight wrapper for notification credentials that should only exist inside
/// secure configuration files (never commit real keys into source control).
class NotificationCredentials {
  final String projectId;
  final String clientEmail;
  final String privateKey;
  final String tokenUri;
  final String authProviderCertUrl;

  const NotificationCredentials({
    required this.projectId,
    required this.clientEmail,
    required this.privateKey,
    required this.tokenUri,
    required this.authProviderCertUrl,
  });

  bool get isValid =>
      projectId.isNotEmpty &&
      clientEmail.isNotEmpty &&
      privateKey.isNotEmpty &&
      tokenUri.isNotEmpty;

  factory NotificationCredentials.fromJson(Map<String, dynamic> json) {
    return NotificationCredentials(
      projectId: json['project_id']?.toString() ?? '',
      clientEmail: json['client_email']?.toString() ?? '',
      privateKey: json['private_key']?.toString() ?? '',
      tokenUri: json['token_uri']?.toString() ?? '',
      authProviderCertUrl:
          json['auth_provider_x509_cert_url']?.toString() ?? '',
    );
  }
}

/// Helper for loading notification credentials from a centralized asset file.
class NotificationConfig {
  /// Location of the JSON holding notification credentials.
  static const String assetPath = AppConfig.notificationConfigAsset;

  /// Loads the notification credentials from the configured asset file.
  static Future<NotificationCredentials?> loadCredentials() async {
    try {
      final raw = await rootBundle.loadString(assetPath);
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) {
        final creds = NotificationCredentials.fromJson(parsed);
        if (creds.isValid) {
          
          return creds;
        }
        
      } else {
        
      }
    } on FlutterError catch (error) {
      
    } catch (error) {
      
    }
    return null;
  }
}

