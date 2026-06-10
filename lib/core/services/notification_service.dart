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

      // Try initial sync if logged in
      final token = await messaging.getToken();
      if (token != null) {
        await syncToken(token);
      }

      // Handle message clicks when app is in background/terminated
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened by notification: ${message.data}');
      });

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

