import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';

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
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      // Listen for token refresh
      messaging.onTokenRefresh.listen((token) {
        syncToken(token);
      });

      // Check if launched from a terminated notification click
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        _processNotificationPayload(initialMessage.data);
      }

      // Handle message clicks when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened by notification: ${message.data}');
        _processNotificationPayload(message.data);
      });

      // Try initial sync if logged in
      final token = await messaging.getToken();
      if (token != null) {
        await syncToken(token);
      }

    } catch (e) {
      debugPrint('Notification init skipped or failed: $e');
    }
  }

  /// Syncs the FCM token to the user's profile in Supabase database
  static Future<void> syncToken([String? token]) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final actualToken = token ?? await FirebaseMessaging.instance.getToken();
      if (actualToken == null) return;

      await client.from('profiles').update({'fcm_token': actualToken}).eq('id', userId);
      debugPrint('FCM Token synced successfully to Supabase profiles.');
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }
}

