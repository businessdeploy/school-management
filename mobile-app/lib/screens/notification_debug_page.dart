import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debug page to check notification setup and test FCM token
class NotificationDebugPage extends StatefulWidget {
  const NotificationDebugPage({super.key});

  @override
  State<NotificationDebugPage> createState() => _NotificationDebugPageState();
}

class _NotificationDebugPageState extends State<NotificationDebugPage> {
  String? _fcmToken;
  String? _studentId;
  bool _isLoading = true;
  String _status = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkNotificationSetup();
  }

  Future<void> _checkNotificationSetup() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking notification setup...';
    });

    try {
      // Check if Firebase is initialized
      String? token;
      try {
        token = await FirebaseMessaging.instance.getToken();
      } catch (firebaseError) {
        setState(() {
          _fcmToken = null;
          _studentId = null;
          _isLoading = false;
          _status = '❌ Firebase Not Initialized';
        });
        
        return;
      }
      
      // Get student ID
      final prefs = await SharedPreferences.getInstance();
      String? studentId = prefs.getString('student_id');
      if (studentId == null || studentId.isEmpty) {
        studentId = prefs.getString('user_id');
      }

      setState(() {
        _fcmToken = token;
        _studentId = studentId;
        _isLoading = false;
        
        if (token != null && studentId != null && studentId.isNotEmpty) {
          _status = '✅ Setup Complete';
        } else if (token == null) {
          _status = '❌ FCM Token Missing';
        } else if (studentId == null || studentId.isEmpty) {
          _status = '⚠️ Not Logged In';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _status = '❌ Error: $e';
      });
      
    }
  }

  Future<void> _reregisterToken() async {
    setState(() {
      _status = 'Re-registering token...';
    });

    try {
      await NotificationService.registerCurrentToken(force: true);
      
      // Wait a moment for the registration to complete
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _status = '✅ Token Re-registered';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Token re-registered! Check console logs for backend response.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = '❌ Registration Failed';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to register: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyToken() {
    if (_fcmToken != null) {
      Clipboard.setData(ClipboardData(text: _fcmToken!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('FCM Token copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Debug'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  Card(
                    color: _status.startsWith('✅')
                        ? Colors.green.shade50
                        : _status.startsWith('❌')
                            ? Colors.red.shade50
                            : Colors.orange.shade50,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            _status.startsWith('✅')
                                ? Icons.check_circle
                                : _status.startsWith('❌')
                                    ? Icons.error
                                    : Icons.warning,
                            size: 40,
                            color: _status.startsWith('✅')
                                ? Colors.green
                                : _status.startsWith('❌')
                                    ? Colors.red
                                    : Colors.orange,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _status,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Student ID
                  _buildInfoSection(
                    'Student ID',
                    _studentId ?? 'Not logged in',
                    _studentId != null && _studentId!.isNotEmpty
                        ? Icons.person
                        : Icons.person_off,
                    _studentId != null && _studentId!.isNotEmpty
                        ? Colors.green
                        : Colors.red,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // FCM Token
                  _buildInfoSection(
                    'FCM Token',
                    _fcmToken ?? 'Not available',
                    _fcmToken != null ? Icons.token : Icons.error,
                    _fcmToken != null ? Colors.green : Colors.red,
                    showCopy: _fcmToken != null,
                    onCopy: _copyToken,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Action Buttons
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _reregisterToken,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Re-register Token'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _checkNotificationSetup,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh Status'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Instructions
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'How to Test Notifications',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildStep('1', 'Make sure you are logged in'),
                          _buildStep('2', 'Tap "Re-register Token" and check console logs'),
                          _buildStep('3', 'Copy the FCM Token above'),
                          _buildStep('4', 'Send a test notification from Firebase Console or your backend'),
                          _buildStep('5', 'Check if notification appears'),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline, size: 16, color: Colors.blue.shade700),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Check Console Logs',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'When you tap "Re-register Token", check the console/logcat for:\n'
                                  '• "✅ Device token registered successfully"\n'
                                  '• "❌ Failed to register device token" (shows backend error)',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Note: If token registration fails, check your backend API endpoint and network connection.',
                            style: TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoSection(
    String title,
    String value,
    IconData icon,
    Color iconColor, {
    bool showCopy = false,
    VoidCallback? onCopy,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    value,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (showCopy)
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: onCopy,
                    tooltip: 'Copy',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
