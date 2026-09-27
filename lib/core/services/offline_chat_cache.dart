import 'dart:convert';
import 'package:calcx/core/models/message.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local cache for chat messages and recent conversations.
/// Enables 0ms instantaneous loading and full offline chat viewing without internet.
class OfflineChatCache {
  OfflineChatCache._();

  static const _recentChatsPrefix = 'calcx_cache_recent_chats_';
  static const _dmPrefix = 'calcx_cache_dm_';
  static const _roomPrefix = 'calcx_cache_room_';

  /// Save recent chats list to local persistent storage
  static Future<void> saveRecentChats(String myId, List<Map<String, dynamic>> chats) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serialized = jsonEncode(chats);
      await prefs.setString('$_recentChatsPrefix$myId', serialized);
    } catch (e) {
      debugPrint('Error caching recent chats: $e');
    }
  }

  /// Load recent chats list from local persistent storage
  static Future<List<Map<String, dynamic>>> loadRecentChats(String myId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_recentChatsPrefix$myId');
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error loading cached recent chats: $e');
    }
    return [];
  }

  /// Save direct messages for a conversation (persists up to 100 recent messages)
  static Future<void> saveDirectMessages(String myId, String otherUserId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = messages.take(100).map((m) => m.toMap()).toList();
      final serialized = jsonEncode(toSave);
      await prefs.setString('$_dmPrefix${myId}_$otherUserId', serialized);
    } catch (e) {
      debugPrint('Error caching direct messages: $e');
    }
  }

  /// Load cached direct messages
  static Future<List<Message>> loadDirectMessages(String myId, String otherUserId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_dmPrefix${myId}_$otherUserId');
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final list = decoded.map((m) => Message.fromMap(Map<String, dynamic>.from(m as Map))).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error loading cached direct messages: $e');
    }
    return [];
  }

  /// Save room messages (persists up to 100 recent messages)
  static Future<void> saveRoomMessages(String roomId, List<Message> messages) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final toSave = messages.take(100).map((m) => m.toMap()).toList();
      final serialized = jsonEncode(toSave);
      await prefs.setString('$_roomPrefix$roomId', serialized);
    } catch (e) {
      debugPrint('Error caching room messages: $e');
    }
  }

  /// Load cached room messages
  static Future<List<Message>> loadRoomMessages(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('$_roomPrefix$roomId');
      if (str != null && str.isNotEmpty) {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          final list = decoded.map((m) => Message.fromMap(Map<String, dynamic>.from(m as Map))).toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        }
      }
    } catch (e) {
      debugPrint('Error loading cached room messages: $e');
    }
    return [];
  }

  /// Delete cached direct messages by time (e.g. 2hr, 24hr, all) or media only
  static Future<void> deleteDirectMessages({
    required String myId,
    required String otherUserId,
    Duration? duration,
    bool mediaOnly = false,
  }) async {
    try {
      if (duration == null && !mediaOnly) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_dmPrefix${myId}_$otherUserId');
        return;
      }

      final existing = await loadDirectMessages(myId, otherUserId);
      final cutoff = duration != null ? DateTime.now().subtract(duration) : null;

      final updated = existing.where((m) {
        final inTimeWindow = cutoff == null || m.createdAt.isAfter(cutoff);
        if (!inTimeWindow) return true;

        if (mediaOnly) {
          final hasMedia = (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) ||
              m.messageType == 'image' ||
              m.messageType == 'video' ||
              m.messageType == 'audio' ||
              m.messageType == 'file' ||
              m.messageType == 'view_once_image' ||
              m.messageType == 'view_once_video';
          return !hasMedia;
        }

        return false;
      }).toList();

      await saveDirectMessages(myId, otherUserId, updated);
    } catch (e) {
      debugPrint('Error deleting direct messages from cache: $e');
    }
  }

  /// Delete cached room messages by time or media only
  static Future<void> deleteRoomMessages({
    required String roomId,
    Duration? duration,
    bool mediaOnly = false,
  }) async {
    try {
      if (duration == null && !mediaOnly) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('$_roomPrefix$roomId');
        return;
      }

      final existing = await loadRoomMessages(roomId);
      final cutoff = duration != null ? DateTime.now().subtract(duration) : null;

      final updated = existing.where((m) {
        final inTimeWindow = cutoff == null || m.createdAt.isAfter(cutoff);
        if (!inTimeWindow) return true;

        if (mediaOnly) {
          final hasMedia = (m.mediaUrl != null && m.mediaUrl!.isNotEmpty) ||
              m.messageType == 'image' ||
              m.messageType == 'video' ||
              m.messageType == 'audio' ||
              m.messageType == 'file';
          return !hasMedia;
        }

        return false;
      }).toList();

      await saveRoomMessages(roomId, updated);
    } catch (e) {
      debugPrint('Error deleting room messages from cache: $e');
    }
  }
}
