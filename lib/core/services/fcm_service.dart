import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'auth_service.dart';
import '../../features/cleaner/jobs/cleaner_job_detail_screen.dart';

// Top-level background message handler
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

class FcmService {
  static final FcmService instance = FcmService._internal();
  FcmService._internal();

  FirebaseMessaging? _messaging;
  GlobalKey<NavigatorState>? navigatorKey;

  void init(GlobalKey<NavigatorState> navKey) {
    navigatorKey = navKey;
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    try {
      _messaging = FirebaseMessaging.instance;

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // Request permission for iOS/Android 13+
      NotificationSettings settings = await _messaging!.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      debugPrint('User granted permission: ${settings.authorizationStatus}');

      // Handle token updates
      _messaging!.onTokenRefresh.listen((String token) {
        debugPrint("FCM Token refreshed: $token");
        _sendTokenToBackend(token);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification}');
          // Could show a local notification or snackbar here if desired
        }
      });

      // Handle message open (app in background)
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessage(message);
      });

      // Check if the app was opened from a terminated state via a notification
      RemoteMessage? initialMessage = await _messaging!.getInitialMessage();
      if (initialMessage != null) {
        // Need to wait slightly for UI to be ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleMessage(initialMessage);
        });
      }

    } catch (e) {
      debugPrint('Failed to initialize Firebase FCM: $e');
    }
  }

  Future<void> updateTokenToServer() async {
    try {
      // Only proceed if user is logged in
      if (!await AuthService.isLoggedIn()) return;
      if (_messaging == null) return;
      
      String? token = await _messaging!.getToken();
      if (token != null) {
        debugPrint("Got FCM Token: $token");
        await _sendTokenToBackend(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    try {
      if (await AuthService.isLoggedIn()) {
        await AuthService.updateFcmToken(token);
        debugPrint("FCM token successfully sent to backend.");
      }
    } catch (e) {
      debugPrint("Failed to send token to backend: $e");
    }
  }

  void _handleMessage(RemoteMessage message) {
    debugPrint("Handling notification click: ${message.data}");
    if (message.data['type'] == 'new_job' && message.data['screen'] == 'detail_pesanan') {
      final String? cleanerIdStr = message.data['pesanan_cleaner_id'];
      if (cleanerIdStr != null && navigatorKey?.currentContext != null) {
        final int? cleanerId = int.tryParse(cleanerIdStr);
        if (cleanerId != null) {
           Navigator.of(navigatorKey!.currentContext!).push(
             MaterialPageRoute(
               builder: (_) => CleanerJobDetailScreen(
                 job: {'id': cleanerId, 'status_pengerjaan': 'notified'},
               ),
             ),
           );
        }
      }
    }
  }
}
