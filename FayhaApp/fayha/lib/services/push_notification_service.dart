import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ─── Background handler ────────────────────────────────────────────────────
// Must be a top-level function (not a class member) for FCM to invoke it when
// the app is terminated or in the background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('[FCM] Background message: ${message.messageId}');
  // flutter_local_notifications shows a heads-up banner automatically on
  // Android when the app is in the background. On iOS the system handles it.
}

// ─── Service ───────────────────────────────────────────────────────────────

/// Handles FCM token registration, foreground notifications, and tap routing.
///
/// SETUP REQUIRED before this service will work:
///   1. Create a Firebase project at https://console.firebase.google.com
///   2. Android: add `android/app/google-services.json` and apply the
///      `com.google.gms.google-services` Gradle plugin.
///   3. iOS: add `ios/Runner/GoogleService-Info.plist` (drag into Xcode),
///      enable Push Notifications + Background Modes capabilities.
///   4. Deploy the `supabase/functions/send-push` edge function and add
///      `FIREBASE_SERVICE_ACCOUNT` to your Supabase project secrets.
class PushNotificationService {
  static final _fcm = FirebaseMessaging.instance;
  static final _localNotif = FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'fayha_default',
    'Fayha Choir',
    description: 'Choir announcements, events, messages and updates.',
    importance: Importance.high,
  );

  /// Call once after the signed-in member is resolved, passing the app's
  /// navigator key for deep-link routing on notification tap.
  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    try {
      // Request OS permission (iOS shows a system dialog; Android 13+ too).
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] Push permission denied by user.');
        return;
      }

      // Android: create notification channel so heads-up banners work.
      await _localNotif
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(_androidChannel);

      // Initialise flutter_local_notifications.
      const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initDarwin = DarwinInitializationSettings();
      await _localNotif.initialize(
        const InitializationSettings(android: initAndroid, iOS: initDarwin),
        onDidReceiveNotificationResponse: (details) {
          _routeFromPayload(navigatorKey, details.payload);
        },
      );

      // Save / refresh token.
      final token = await _fcm.getToken();
      if (token != null) await _saveToken(token);
      _fcm.onTokenRefresh.listen(_saveToken);

      // ── Foreground: show a local notification banner ──────────────────────
      FirebaseMessaging.onMessage.listen((message) {
        debugPrint('[FCM] Foreground message: ${message.messageId}');
        _showLocalBanner(message);
      });

      // ── Background tap (app was in background, user tapped notification) ──
      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        debugPrint('[FCM] onMessageOpenedApp: ${message.messageId}');
        _routeFromMessage(navigatorKey, message);
      });

      // ── Terminated tap (app was closed, user tapped notification) ─────────
      final initial = await _fcm.getInitialMessage();
      if (initial != null) {
        debugPrint('[FCM] Initial message: ${initial.messageId}');
        // Small delay to let the widget tree settle before navigating.
        await Future.delayed(const Duration(milliseconds: 500));
        _routeFromMessage(navigatorKey, initial);
      }
    } catch (e, st) {
      // Firebase not configured → push notifications silently disabled.
      debugPrint('[FCM] init error (Firebase not configured?): $e\n$st');
    }
  }

  // ── Token persistence ──────────────────────────────────────────────────────

  static Future<void> _saveToken(String token) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client
          .from('members')
          .update({'fcm_token': token})
          .eq('id', uid);
      debugPrint('[FCM] Token saved for $uid');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Clear the token on sign-out so stale tokens don't receive pushes.
  static Future<void> clearToken() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      await Supabase.instance.client
          .from('members')
          .update({'fcm_token': null})
          .eq('id', uid);
      await _fcm.deleteToken();
    } catch (e) {
      debugPrint('[FCM] Failed to clear token: $e');
    }
  }

  // ── Foreground banner ──────────────────────────────────────────────────────

  static Future<void> _showLocalBanner(RemoteMessage message) async {
    final notif = message.notification;
    if (notif == null) return;
    final payload = jsonEncode(message.data);
    await _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannel.id,
          _androidChannel.name,
          channelDescription: _androidChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  // ── Routing ────────────────────────────────────────────────────────────────

  static void _routeFromMessage(
    GlobalKey<NavigatorState> key,
    RemoteMessage message,
  ) {
    _routeFromPayload(key, jsonEncode(message.data));
  }

  static void _routeFromPayload(
    GlobalKey<NavigatorState> key,
    String? payload,
  ) {
    if (payload == null) return;
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final kind = data['kind'] as String? ?? '';
      debugPrint('[FCM] Routing to kind=$kind');
      // Navigation is handled by the MemberShell's navigator; push screens
      // onto the root navigator so they appear above the shell.
      final nav = key.currentState;
      if (nav == null) return;
      // The actual screen routing mirrors notifications_screen.dart _onTap.
      // MemberShell must already be the active route for this to work.
      nav.pushNamed('/notifications', arguments: kind);
    } catch (e) {
      debugPrint('[FCM] Routing error: $e');
    }
  }

  // ── Push dispatch (called by service layer after creating content) ─────────

  /// Send a push notification to all active members (or a subset).
  /// Requires the `send-push` Supabase edge function to be deployed.
  static Future<void> dispatch({
    required String title,
    required String body,
    String kind = 'announcement',
    String? sourceId,
    List<String>? memberIds,
  }) async {
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      final resp = await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'title': title,
          'body': body,
          'kind': kind,
          if (sourceId != null) 'source_id': sourceId,
          if (memberIds != null) 'member_ids': memberIds,
        },
      );
      debugPrint('[FCM] dispatch response: ${resp.data}');
    } catch (e) {
      debugPrint('[FCM] dispatch error: $e');
    }
  }
}
