import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'api/notification_api.dart';
import 'api/notification_api.dart';
// import 'auth_service.dart'; // Removed to avoid circular dependency

/// This handler must be a top-level function.
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await NotificationService.showNotification(message);
}

/// Centralized notification handling for FCM + local notifications.
class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final AndroidNotificationChannel _channel =
      const AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'Prime School push notifications',
    importance: Importance.high,
  );

  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;
    await _configureLocalNotifications();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _requestPermission();
    await registerCurrentToken();
    _messaging.onTokenRefresh.listen(_registerTokenIfNeeded);

    FirebaseMessaging.onMessage.listen(showNotification);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  static Future<void> _configureLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
      onDidReceiveNotificationResponse: (response) {
        _handlePayload(response.payload);
      },
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

  }

  static Future<void> registerCurrentToken({bool force = false}) async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        
        
        await _registerToken(token, force: force);
      }
    } catch (e) {
      
    }
  }

  static Future<void> _registerTokenIfNeeded(String token) async {
    if (token.isNotEmpty) {
      await _registerToken(token);
    }
  }

  static Future<void> _registerToken(String token, {bool force = false}) async {
    final storedToken = await AppConfig.getDeviceToken();
    
    // Always ensure the token is saved locally
    if (storedToken != token) {
      await AppConfig.setDeviceToken(token);
    }

    // Use SharedPreferences directly to avoid circular dependency with AuthService
    // final studentId = await AuthService.getStudentId();
    final prefs = await SharedPreferences.getInstance();
    String studentId = prefs.getString('student_id') ?? '';
    if (studentId.isEmpty) {
      // Fallback to user_id if student_id is missing
      studentId = prefs.getString('user_id') ?? '';
    }
    
    if (studentId.isEmpty) {
      
      return;
    }

    // Check if the student ID has changed since last registration
    final lastRegisteredStudentId = prefs.getString('last_registered_student_id');
    if (lastRegisteredStudentId != studentId) {
      
      force = true;
    }

    // Only skip if same token AND not forced
    if (!force && storedToken == token) {
      
      return;
    }

    
    await NotificationApi.registerDeviceToken(
      studentId: studentId,
      token: token,
    );
    
    // Save the student ID we just registered for
    await prefs.setString('last_registered_student_id', studentId);
  }

  static Future<void> showNotification(RemoteMessage message) async {
    // Check for notification payload first
    String? title = message.notification?.title;
    String? body = message.notification?.body;

    // Fallback to data payload if notification payload is missing
    if (title == null && message.data.isNotEmpty) {
      title = message.data['title'] ?? message.data['subject'] ?? 'Notification';
      body = message.data['body'] ?? message.data['message'] ?? message.data['msg'];
    }

    if (title == null) return; // Nothing to show

    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(body ?? ''),
    );

    const iosDetails = DarwinNotificationDetails();

    await _localNotifications.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(android: androidDetails, iOS: iosDetails),
      payload: message.data['route'] as String? ?? '',
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    // If a specific route is provided, use it.
    final route = message.data['route']?.toString();
    if (route != null && route.isNotEmpty) {
      _navigatorKey?.currentState?.pushNamed(route);
      return;
    }

    // Check for specific notification types
    final type = message.data['type']?.toString().toLowerCase();
    if (type == 'notice' || type == 'announcement' || type == 'notice_board') {
      _navigatorKey?.currentState?.pushNamed('/notice_board');
      return;
    }

    // Default behavior: Open Notification Page
    _navigatorKey?.currentState?.pushNamed('/notifications');
  }

  static void _handlePayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    _navigatorKey?.currentState?.pushNamed(payload);
  }
}

