import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
    debugPrint('Handling background message: ${message.messageId}');
  } catch (e) {
    debugPrint('Error handling background message: $e');
  }
}

class NotificationService {
  NotificationService._();

  /// Holds the target chat route when the app is launched or opened from a notification.
  /// After the user unlocks via the Calculator disguise, the app navigates here.
  static String? pendingNotificationRoute;

  /// Holds cached active user ID (synced from WebVault or Native auth)
  static String? cachedUserId;

  static void _processNotificationPayload(Map<String, dynamic> data) {
    final senderId = data['sender_id'] as String?;
    final roomId = data['room_id'] as String?;
    if (senderId != null && senderId.isNotEmpty) {
      pendingNotificationRoute = '/chat/$senderId';
    } else if (roomId != null && roomId.isNotEmpty) {
      pendingNotificationRoute = '/room/$roomId/chat';
    }
  }

  static Future<void> maybeInitialize() async {
    try {
      await Firebase.initializeApp();
      
      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      final messaging = FirebaseMessaging.instance;
      
      // 1. Request Firebase notification permission
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      // 2. Request Android 13+ POST_NOTIFICATIONS runtime permission explicitly
      if (!kIsWeb) {
        try {
          await Permission.notification.request();
        } catch (_) {}
      }

      // 3. Set foreground presentation options to display alerts & play sounds
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // 4. Listen for token refresh
      messaging.onTokenRefresh.listen((token) {
        syncToken(token);
      });

      // 5. Check if launched from a terminated notification click
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _processNotificationPayload(initialMessage.data);
      }

      // 6. Handle message clicks when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened by notification: ${message.data}');
        _processNotificationPayload(message.data);
      });

      // 7. Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Foreground notification received: ${message.notification?.title} - ${message.notification?.body}');
      });

      // 8. Try initial sync if logged in
      final token = await messaging.getToken();
      if (token != null) {
        await syncToken(token);
      }

    } catch (e) {
      debugPrint('Notification init skipped or failed: $e');
    }
  }

  /// Syncs the FCM token to the user's profile in Supabase database
  static Future<void> syncToken([String? token, String? explicitUserId]) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;
      
      if (explicitUserId != null && explicitUserId.isNotEmpty) {
        cachedUserId = explicitUserId;
      }
      
      final userId = explicitUserId ?? cachedUserId ?? client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('syncToken skipped: no user ID available');
        return;
      }

      final actualToken = token ?? await FirebaseMessaging.instance.getToken();
      if (actualToken == null) {
        debugPrint('syncToken skipped: FCM token is null');
        return;
      }

      await client.from('profiles').update({'fcm_token': actualToken}).eq('id', userId);
      debugPrint('FCM Token synced successfully to Supabase profiles for user $userId.');
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }
}
