import 'package:flutter/material.dart';
import 'splash_screen.dart';

/// Blocking screen shown when school verification fails
/// Prevents user from proceeding until school is verified
class SchoolVerificationBlockedPage extends StatelessWidget {
  final String message;
  final bool isNetworkError;

  const SchoolVerificationBlockedPage({
    super.key,
    required this.message,
    this.isNetworkError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Error Icon
                Icon(
                  isNetworkError ? Icons.wifi_off : Icons.error_outline,
                  size: 80,
                  color: Colors.red[400],
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  isNetworkError ? 'Connection Error' : 'School Not Verified',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                
                // Message
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Retry Button (only for network errors)
                if (isNetworkError)
                  ElevatedButton.icon(
                    onPressed: () {
                      // Navigate back to splash to retry verification
                      // Clear all routes and go back to root (splash screen)
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (context) {
                            // Import splash screen dynamically to avoid circular dependency
                            return const SplashScreen();
                          },
                        ),
                        (route) => false, // Remove all previous routes
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.blue[600],
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

