import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

// ── Background handler (top-level, outside any class) ───────────
/// Handles FCM messages when the app is in the background / terminated.
/// Must be a top-level function annotated with @pragma.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialised before this is called by the plugin.
  // No UI interaction is possible here — just data processing if needed.
  debugPrint('[FCM Background] ${message.notification?.title}: '
      '${message.notification?.body}');
}

// ── Service ─────────────────────────────────────────────────────
/// Manages Firebase Cloud Messaging for Tourvia.
///
/// Responsibilities:
///   • Request notification permissions (iOS / Android 13+)
///   • Retrieve and persist the FCM token to Firestore
///   • Listen for foreground messages and show in-app banners
///   • Handle notification taps (opened-from-background / terminated)
class NotificationService {
  NotificationService._();

  static final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Expose the current FCM token for debugging / manual testing
  static String? currentToken;

  // Stream that the app can listen to for in-app notification display
  static final StreamController<RemoteMessage> _foregroundController =
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get onForegroundMessage =>
      _foregroundController.stream;

  // ── Initialisation ──────────────────────────────────────────

  /// Call once from main() after Firebase.initializeApp().
  static Future<void> initialize() async {
    // 1. Register the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Request permission (required on iOS; on Android 13+ shows dialog)
    final settings = await _fcm.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // 3. Get the FCM token
    try {
      final token = await _fcm.getToken();
      currentToken = token;
      debugPrint('[FCM] Token: $token');
    } catch (e) {
      debugPrint('[FCM] Could not get token: $e');
    }

    // 4. Listen for token refresh and re-save
    _fcm.onTokenRefresh.listen((newToken) {
      currentToken = newToken;
      debugPrint('[FCM] Token refreshed: $newToken');
    });

    // 5. Set foreground notification presentation options (mobile only)
    if (!kIsWeb) {
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // 6. Foreground message listener
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('[FCM Foreground] ${message.notification?.title}');
      _foregroundController.add(message);
    });

    // 7. Handle notification tap when app was in background
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('[FCM Tap from background] ${message.data}');
      _handleMessageTap(message);
    });

    // 8. Check if the app was opened from a terminated-state notification
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('[FCM Tap from terminated] ${initialMessage.data}');
      _handleMessageTap(initialMessage);
    }
  }

  // ── Token persistence ───────────────────────────────────────

  /// Saves the current FCM token to Firestore so the server can send
  /// targeted push notifications.
  ///
  /// Call this after the user logs in, passing their UID.
  static Future<void> saveTokenForUser(String userId) async {
    final token = currentToken ?? await _fcm.getToken();
    if (token == null) return;

    await _db.collection('users').doc(userId).set({
      'fcmToken': token,
      'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[FCM] Token saved for user $userId');
  }

  /// Saves the FCM token for a tourist (identified by their code doc ID).
  static Future<void> saveTokenForTourist(String sessionId, String codeDocId) async {
    final token = currentToken ?? await _fcm.getToken();
    if (token == null) return;

    await _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('tourists')
        .doc(codeDocId)
        .set({
      'fcmToken': token,
      'platform': kIsWeb ? 'web' : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'),
      'tokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint('[FCM] Token saved for tourist $codeDocId');
  }

  // ── Notification tap routing ────────────────────────────────

  static void _handleMessageTap(RemoteMessage message) {
    // Route the user to the correct screen based on notification type.
    // This requires a global navigator key set in main.dart.
    final type = message.data['type'] as String?;
    debugPrint('[FCM] Tapped notification type: $type');
    // Routing is handled by the NavigatorKey in main.dart.
    // The app listens to onMessageOpenedApp and routes accordingly.
  }

  // ── Dispose ─────────────────────────────────────────────────

  static void dispose() {
    _foregroundController.close();
  }
}
