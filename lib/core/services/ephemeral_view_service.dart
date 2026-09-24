import 'package:calcx/core/models/message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EphemeralViewService {
  static const _prefix = 'ephemeral_views_';

  static Future<int> getViewCount(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('') ?? 0;
  }

  static Future<int> incrementViewCount(String messageId) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getInt('') ?? 0;
    final next = current + 1;
    await prefs.setInt('', next);
    return next;
  }

  static Future<bool> isExpired(Message message) async {
    if (message.content == 'Opened' || message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return true;
    }
    final views = await getViewCount(message.id);
    return views >= message.maxAllowedViews;
  }

  static Future<int> getRemainingViews(Message message) async {
    if (message.content == 'Opened' || message.mediaUrl == null || message.mediaUrl!.isEmpty) {
      return 0;
    }
    final views = await getViewCount(message.id);
    final remaining = message.maxAllowedViews - views;
    return remaining > 0 ? remaining : 0;
  }
}
