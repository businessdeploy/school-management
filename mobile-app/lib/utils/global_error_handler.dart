import 'package:flutter/material.dart';

class GlobalErrorHandler {
  /// Handle API errors globally and show appropriate messages to users
  static void handleApiError(dynamic error, BuildContext context) {
    String errorMessage = 'An unexpected error occurred';

    if (error is Exception) {
      final errorString = error.toString();

      // Check for HTML response errors
      if (errorString.contains('Server returned HTML page')) {
        errorMessage =
            'Server returned an error page. Please check your login status or try again.';
      } else if (errorString.contains('Failed to parse JSON')) {
        errorMessage = 'Server returned invalid data. Please try again.';
      } else if (errorString.contains('HTTP request failed')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('authentication') ||
          errorString.contains('login')) {
        errorMessage = 'Authentication failed. Please login again.';
      } else {
        errorMessage = errorString.replaceFirst('Exception: ', '');
      }
    }

    // Show error to user
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  /// Check if an error is related to HTML responses
  static bool isHtmlResponseError(dynamic error) {
    if (error is Exception) {
      final errorString = error.toString();
      return errorString.contains('Server returned HTML page') ||
          errorString.contains('Failed to parse JSON');
    }
    return false;
  }

  /// Get user-friendly error message
  static String getUserFriendlyMessage(dynamic error) {
    if (error is Exception) {
      final errorString = error.toString();

      if (errorString.contains('Server returned HTML page')) {
        return 'Server error. Please check your login status.';
      } else if (errorString.contains('Failed to parse JSON')) {
        return 'Invalid server response. Please try again.';
      } else if (errorString.contains('HTTP request failed')) {
        return 'Network error. Please check your connection.';
      } else if (errorString.contains('authentication') ||
          errorString.contains('login')) {
        return 'Please login again to continue.';
      } else {
        return errorString.replaceFirst('Exception: ', '');
      }
    }
    return 'An unexpected error occurred';
  }
}
