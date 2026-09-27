import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instantaneous in-memory and persistent storage for unsent chat message drafts.
/// Ensures that typed messages are never lost when navigating away, switching chats,
/// or minimizing the app.
class ChatDraftService {
  ChatDraftService._();

  static final Map<String, String> _memoryCache = {};
  static final Map<String, Timer> _debounceTimers = {};
  static const String _prefix = 'calcx_chat_draft_';

  /// Synchronously retrieve draft from memory for 0ms text controller initialization
  static String getDraftSync(String key) {
    return _memoryCache[key] ?? '';
  }

  /// Asynchronously retrieve draft, falling back to persistent storage
  static Future<String> getDraft(String key) async {
    if (_memoryCache.containsKey(key)) {
      return _memoryCache[key] ?? '';
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('$_prefix$key') ?? '';
      if (saved.isNotEmpty) {
        _memoryCache[key] = saved;
      }
      return saved;
    } catch (e) {
      debugPrint('Error loading chat draft: $e');
      return '';
    }
  }

  /// Save draft immediately in memory and debounced to persistent storage
  static void saveDraft(String key, String text) {
    if (text.isEmpty) {
      clearDraft(key);
      return;
    }

    _memoryCache[key] = text;

    _debounceTimers[key]?.cancel();
    _debounceTimers[key] = Timer(const Duration(milliseconds: 300), () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        if (_memoryCache[key]?.isNotEmpty == true) {
          await prefs.setString('$_prefix$key', _memoryCache[key]!);
        } else {
          await prefs.remove('$_prefix$key');
        }
      } catch (e) {
        debugPrint('Error saving chat draft: $e');
      }
    });
  }

  /// Clear draft when a message is successfully sent
  static void clearDraft(String key) {
    _memoryCache.remove(key);
    _debounceTimers[key]?.cancel();
    _debounceTimers.remove(key);

    SharedPreferences.getInstance().then((prefs) {
      prefs.remove('$_prefix$key');
    }).catchError((e) {
      debugPrint('Error clearing chat draft: $e');
    });
  }
}
