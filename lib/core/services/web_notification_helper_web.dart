import 'dart:html' as html;

class WebNotificationHelper {
  static Future<void> requestPermission() async {
    try {
      if (html.Notification.supported && html.Notification.permission != 'granted') {
        await html.Notification.requestPermission();
      }
    } catch (_) {}
  }

  static void showDisguisedNotification({String? title, String? body}) {
    try {
      if (html.Notification.supported && html.Notification.permission == 'granted') {
        html.Notification(
          title ?? 'CalcX',
          body: body ?? 'You have a pending calculation.',
          icon: '/icons/Icon-192.png',
        );
      }
    } catch (_) {}
  }
}
