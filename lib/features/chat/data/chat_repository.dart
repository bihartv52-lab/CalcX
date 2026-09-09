import 'dart:async';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(SupabaseService.clientOrNull);
});

// A provider that keeps track of active typing states mapping: partnerUserId -> isTyping
final typingStatesProvider = NotifierProvider<TypingStatesNotifier, Map<String, bool>>(
  TypingStatesNotifier.new,
);

class TypingStatesNotifier extends Notifier<Map<String, bool>> {
  RealtimeChannel? _myBroadcastChannel;
  final Map<String, Timer> _expiryTimers = {};

  @override
  Map<String, bool> build() {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return {};

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return {};

    // Listen to typing broadcasts sent directly to us
    _myBroadcastChannel = supabase.channel('typing_broadcast_$myId');
    _myBroadcastChannel!.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final senderId = payload['senderId'] as String?;
        final isTyping = payload['isTyping'] as bool? ?? false;
        if (senderId != null) {
          _updateTypingState(senderId, isTyping);
        }
      },
    );
    _myBroadcastChannel!.subscribe();

    ref.onDispose(() {
      if (_myBroadcastChannel != null) {
        supabase.removeChannel(_myBroadcastChannel!);
      }
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
    });

    return {};
  }

  void _updateTypingState(String senderId, bool isTyping) {
    _expiryTimers[senderId]?.cancel();
    if (isTyping) {
      state = {...state, senderId: true};
      // Auto expire typing state after 4 seconds as a fallback
      _expiryTimers[senderId] = Timer(const Duration(seconds: 4), () {
        state = {...state, senderId: false};
      });
    } else {
      state = {...state, senderId: false};
    }
  }
}

// Auto-dispose sender channel provider.
// When ChatPage is closed, it's disposed and channel is unsubscribed.
final typingSendChannelProvider = Provider.autoDispose.family<RealtimeChannel?, String>((ref, targetUserId) {
  final supabase = SupabaseService.clientOrNull;
  if (supabase == null) return null;

  final channel = supabase.channel('typing_broadcast_$targetUserId');
  channel.subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });

  return channel;
});

// Group Typing Indicators mapping: roomId -> (Map of typing users: senderId -> displayName)
final roomTypingStatesProvider = StreamProvider.family<Map<String, String>, String>((ref, roomId) {
  final controller = StreamController<Map<String, String>>();
  final supabase = SupabaseService.clientOrNull;
  if (supabase == null) {
    controller.add({});
    return controller.stream;
  }

  final Map<String, String> currentTyping = {};
  final Map<String, Timer> expiryTimers = {};

  final channel = supabase.channel('typing_room_$roomId');
  channel.onBroadcast(
    event: 'typing',
    callback: (payload) {
      final senderId = payload['senderId'] as String?;
      final senderName = payload['senderName'] as String?;
      final isTyping = payload['isTyping'] as bool? ?? false;
      if (senderId != null && senderName != null) {
        expiryTimers[senderId]?.cancel();
        if (isTyping) {
          currentTyping[senderId] = senderName;
          expiryTimers[senderId] = Timer(const Duration(seconds: 4), () {
            currentTyping.remove(senderId);
            if (!controller.isClosed) {
              controller.add(Map<String, String>.from(currentTyping));
            }
          });
        } else {
          currentTyping.remove(senderId);
        }
        if (!controller.isClosed) {
          controller.add(Map<String, String>.from(currentTyping));
        }
      }
    },
  );
  channel.subscribe();

  controller.add({});

  ref.onDispose(() {
    supabase.removeChannel(channel);
    for (final timer in expiryTimers.values) {
      timer.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

final roomTypingSendChannelProvider = Provider.autoDispose.family<RealtimeChannel?, String>((ref, roomId) {
  final supabase = SupabaseService.clientOrNull;
  if (supabase == null) return null;

  final channel = supabase.channel('typing_room_$roomId');
  channel.subscribe();

  ref.onDispose(() {
    supabase.removeChannel(channel);
  });

  return channel;
});

// Redefine typingIndicatorProvider as a StreamProvider wrapping typingStatesProvider
final typingIndicatorProvider = StreamProvider.family<bool, String>((ref, userId) {
  final controller = StreamController<bool>();
  
  // Watch the changes in typingStatesProvider and push to controller
  ref.listen<Map<String, bool>>(typingStatesProvider, (previous, next) {
    if (!controller.isClosed) {
      controller.add(next[userId] ?? false);
    }
  }, fireImmediately: true);

  // We push initial value
  final initialMap = ref.read(typingStatesProvider);
  controller.add(initialMap[userId] ?? false);

  ref.onDispose(() {
    controller.close();
  });

  return controller.stream;
});

class ChatRepository {
  ChatRepository(this._supabase);

  final SupabaseClient? _supabase;
  SupabaseClient? get supabase => _supabase;

  Stream<List<Message>> watchDirectMessages(String otherUserId, {int limit = 100}) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    final controller = StreamController<List<Message>>();

    void fetchMessages() async {
      try {
        final response = await supabase
            .from('messages')
            .select('*, message_reactions(emoji, user_id), message_reads(user_id)')
            .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
            .filter('room_id', 'is', null)
            .order('created_at', ascending: false)
            .limit(limit);
        if (controller.isClosed) return;
        final list = (response as List).map((e) => Message.fromMap(e as Map<String, dynamic>)).toList();
        controller.add(list);
      } catch (e) {
        debugPrint('Error fetching direct messages: $e');
      }
    }

    // Initial fetch
    fetchMessages();

    // Setup channel for realtime changes
    final channel = supabase.channel('dm_${myId}_$otherUserId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;
        final oldRecord = payload.oldRecord;
        
        final sId = record['sender_id'] ?? oldRecord['sender_id'];
        final rId = record['receiver_id'] ?? oldRecord['receiver_id'];
        final roomId = record['room_id'] ?? oldRecord['room_id'];
        
        if (roomId == null && 
            ((sId == myId && rId == otherUserId) || (sId == otherUserId && rId == myId))) {
          fetchMessages();
        }
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reactions',
      callback: (payload) => fetchMessages(),
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reads',
      callback: (payload) => fetchMessages(),
    ).subscribe();

    controller.onCancel = () {
      supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  Stream<List<Message>> watchRoomMessages(String roomId, {int limit = 100}) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final controller = StreamController<List<Message>>();

    void fetchMessages() async {
      try {
        final response = await supabase
            .from('messages')
            .select('*, message_reactions(emoji, user_id), message_reads(user_id)')
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(limit);
        if (controller.isClosed) return;
        final list = (response as List).map((e) => Message.fromMap(e as Map<String, dynamic>)).toList();
        controller.add(list.reversed.toList());
      } catch (e) {
        debugPrint('Error fetching room messages: $e');
      }
    }

    // Initial fetch
    fetchMessages();

    // Setup channel for realtime changes
    final channel = supabase.channel('room_$roomId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;
        final oldRecord = payload.oldRecord;
        final rId = record['room_id'] ?? oldRecord['room_id'];
        if (rId == roomId) {
          fetchMessages();
        }
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reactions',
      callback: (payload) => fetchMessages(),
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reads',
      callback: (payload) => fetchMessages(),
    ).subscribe();

    controller.onCancel = () {
      supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  Future<void> sendMessage({
    String? receiverId,
    required String content,
    String? roomId,
    String? replyTo,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    final response = await supabase.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'room_id': roomId,
      'content': content,
      'message_type': 'text',
      'reply_to': replyTo,
      'created_at': DateTime.now().toIso8601String(),
    }).select();

    final insertedMsg = response.firstOrNull;

    // Send notification client-side
    if (insertedMsg != null) {
      if (receiverId != null) {
        try {
          final senderProfile = await supabase.from('profiles').select('username').eq('id', myId).maybeSingle();
          final senderName = senderProfile?['username'] as String? ?? 'Someone';
          await supabase.from('notifications').insert({
            'user_id': receiverId,
            'type': 'message',
            'title': 'New Message',
            'body': '$senderName: $content',
            'data': {
              'message_id': insertedMsg['id'],
              'sender_id': myId,
            },
          });
        } catch (e) {
          debugPrint('Error inserting message notification: $e');
        }
      } else if (roomId != null) {
        try {
          final senderProfile = await supabase.from('profiles').select('username').eq('id', myId).maybeSingle();
          final senderName = senderProfile?['username'] as String? ?? 'Someone';
          final participants = await supabase.from('room_participants').select('user_id').eq('room_id', roomId);
          final List<dynamic> list = participants as List<dynamic>? ?? [];
          final List<Map<String, dynamic>> notificationInserts = [];
          for (final p in list) {
            final pUserId = p['user_id'] as String?;
            if (pUserId != null && pUserId != myId) {
              notificationInserts.add({
                'user_id': pUserId,
                'type': 'message',
                'title': 'New Message in Room',
                'body': '$senderName: $content',
                'data': {
                  'room_id': roomId,
                  'message_id': insertedMsg['id'],
                  'sender_id': myId,
                },
              });
            }
          }
          if (notificationInserts.isNotEmpty) {
            await supabase.from('notifications').insert(notificationInserts);
          }
        } catch (e) {
          debugPrint('Error inserting room message notifications: $e');
        }
      }
    }
  }

  Future<void> sendMediaMessage({
    String? receiverId,
    required String messageType,
    required String mediaUrl,
    String? mediaThumbnail,
    String? content,
    String? roomId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    final response = await supabase.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'room_id': roomId,
      'content': content ?? '',
      'message_type': messageType,
      'media_url': mediaUrl,
      'media_thumbnail': mediaThumbnail,
      'created_at': DateTime.now().toIso8601String(),
    }).select();

    final insertedMsg = response.firstOrNull;

    // Send notification client-side
    if (insertedMsg != null) {
      final notificationBody = messageType == 'image'
          ? 'Sent an image'
          : messageType == 'video'
              ? 'Sent a video'
              : messageType == 'audio' || messageType == 'voice'
                  ? 'Sent a voice message'
                  : 'Sent a file';

      if (receiverId != null) {
        try {
          final senderProfile = await supabase.from('profiles').select('username').eq('id', myId).maybeSingle();
          final senderName = senderProfile?['username'] as String? ?? 'Someone';
          await supabase.from('notifications').insert({
            'user_id': receiverId,
            'type': 'message',
            'title': 'New Message',
            'body': '$senderName: $notificationBody',
            'data': {
              'message_id': insertedMsg['id'],
              'sender_id': myId,
            },
          });
        } catch (e) {
          debugPrint('Error inserting media message notification: $e');
        }
      } else if (roomId != null) {
        try {
          final senderProfile = await supabase.from('profiles').select('username').eq('id', myId).maybeSingle();
          final senderName = senderProfile?['username'] as String? ?? 'Someone';
          final participants = await supabase.from('room_participants').select('user_id').eq('room_id', roomId);
          final List<dynamic> list = participants as List<dynamic>? ?? [];
          final List<Map<String, dynamic>> notificationInserts = [];
          for (final p in list) {
            final pUserId = p['user_id'] as String?;
            if (pUserId != null && pUserId != myId) {
              notificationInserts.add({
                'user_id': pUserId,
                'type': 'message',
                'title': 'New Message in Room',
                'body': '$senderName: $notificationBody',
                'data': {
                  'room_id': roomId,
                  'message_id': insertedMsg['id'],
                  'sender_id': myId,
                },
              });
            }
          }
          if (notificationInserts.isNotEmpty) {
            await supabase.from('notifications').insert(notificationInserts);
          }
        } catch (e) {
          debugPrint('Error inserting room media message notifications: $e');
        }
      }
    }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    final supabase = _supabase;
    if (supabase == null) return;

    await supabase
        .from('messages')
        .update({
          'content': newContent,
          'edited': true,
          'edited_at': DateTime.now().toIso8601String(),
        })
        .eq('id', messageId);
  }

  Future<void> deleteMessage(String messageId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    await supabase
        .from('messages')
        .update({'deleted': true, 'content': 'This message was deleted'})
        .eq('id', messageId);
  }

  Future<void> setTyping({
    required String chatWithUserId,
    required bool isTyping,
    String? roomId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await supabase.from('typing_indicators').upsert({
        'user_id': myId,
        'chat_with': chatWithUserId,
        'room_id': roomId,
        'is_typing': isTyping,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error updating typing indicator: $e');
    }
  }

  Stream<bool> watchTyping(String otherUserId) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    return supabase
        .from('typing_indicators')
        .stream(primaryKey: ['id'])
        .eq('user_id', otherUserId)
        .map((data) {
          final filtered = data.where((json) => json['chat_with'] == myId);
          if (filtered.isEmpty) return false;
          final indicator = filtered.first;
          final isTyping = indicator['is_typing'] as bool? ?? false;
          final updatedAt = DateTime.parse(indicator['updated_at'] as String);
          final isRecent = DateTime.now().toUtc().difference(updatedAt.toUtc()).inSeconds.abs() < 30;
          return isTyping && isRecent;
        });
  }

  Future<void> markAllAsRead(String partnerId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final unreadResponse = await supabase
          .from('messages')
          .select('id, message_reads(id, user_id)')
          .eq('sender_id', partnerId)
          .eq('receiver_id', myId)
          .filter('room_id', 'is', null);

      final unreadMsgIds = (unreadResponse as List)
          .where((m) {
            final reads = m['message_reads'] as List? ?? [];
            return !reads.any((r) => r['user_id'] == myId);
          })
          .map((m) => m['id'] as String)
          .toList();

      if (unreadMsgIds.isEmpty) return;

      final inserts = unreadMsgIds.map((msgId) => {
        'message_id': msgId,
        'user_id': myId,
        'read_at': DateTime.now().toIso8601String(),
      }).toList();

      await supabase.from('message_reads').upsert(inserts);
    } catch (e) {
      debugPrint('Error marking all messages as read: $e');
    }
  }

  Future<void> markAsRead(String messageId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await supabase.from('message_reads').upsert({
        'message_id': messageId,
        'user_id': myId,
        'read_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getRecentChats() async {
    final supabase = _supabase;
    if (supabase == null) return [];

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await supabase
          .from('messages')
          .select()
          .or('sender_id.eq.$myId,receiver_id.eq.$myId')
          .order('created_at', ascending: false)
          .limit(100);

      final chats = <String, Map<String, dynamic>>{};
      for (final msg in response) {
        final senderId = msg['sender_id'] as String;
        final receiverId = msg['receiver_id'] as String?;
        final partnerId = senderId == myId ? receiverId : senderId;

        if (partnerId == null || chats.containsKey(partnerId)) continue;

        chats[partnerId] = {
          'partner_id': partnerId,
          'partner_profile': null,
          'last_message': msg,
          'unread_count': 0,
        };
      }

      if (chats.isNotEmpty) {
        final partnerIds = chats.keys.toList();
        final profilesResponse = await supabase
            .from('profiles')
            .select()
            .inFilter('id', partnerIds);

        final profilesMap = {
          for (final p in profilesResponse as List)
            p['id'] as String: p
        };

        // Fetch all unread messages for all partners in a single query
        final unreadResponse = await supabase
            .from('messages')
            .select('id, sender_id, message_reads(id, user_id)')
            .inFilter('sender_id', partnerIds)
            .eq('receiver_id', myId)
            .filter('room_id', 'is', null);

        final unreadList = unreadResponse as List;

        for (final partnerId in chats.keys) {
          chats[partnerId]!['partner_profile'] = profilesMap[partnerId];

          final partnerUnreadCount = unreadList
              .where((m) => m['sender_id'] == partnerId)
              .where((m) {
                final reads = m['message_reads'] as List? ?? [];
                return !reads.any((r) => r['user_id'] == myId);
              })
              .length;

          chats[partnerId]!['unread_count'] = partnerUnreadCount;
        }
      }

      return chats.values.toList();
    } catch (e) {
      debugPrint('Error getting recent chats: $e');
      return [];
    }
  }

  Future<void> addReaction(String messageId, String emoji) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    await supabase.from('message_reactions').insert({
      'message_id': messageId,
      'user_id': myId,
      'emoji': emoji,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    await supabase
        .from('message_reactions')
        .delete()
        .eq('message_id', messageId)
        .eq('user_id', myId)
        .eq('emoji', emoji);
  }

  /// Search direct messages using Supabase .ilike filter
  Future<List<Message>> searchDirectMessages(String otherUserId, String query) async {
    final supabase = _supabase;
    if (supabase == null || query.trim().isEmpty) return [];

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await supabase
          .from('messages')
          .select('*, message_reactions(emoji, user_id), message_reads(user_id)')
          .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
          .filter('room_id', 'is', null)
          .ilike('content', '%${query.trim()}%')
          .order('created_at', ascending: false);

      return (response as List).map((e) => Message.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error searching direct messages: $e');
      return [];
    }
  }

  /// Search room messages using Supabase .ilike filter
  Future<List<Message>> searchRoomMessages(String roomId, String query) async {
    final supabase = _supabase;
    if (supabase == null || query.trim().isEmpty) return [];

    try {
      final response = await supabase
          .from('messages')
          .select('*, message_reactions(emoji, user_id), message_reads(user_id)')
          .eq('room_id', roomId)
          .ilike('content', '%${query.trim()}%')
          .order('created_at', ascending: false);

      return (response as List).map((e) => Message.fromMap(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error searching room messages: $e');
      return [];
    }
  }

  /// Batch insert forwarded messages to target direct chats or rooms
  Future<void> forwardMessages({
    required List<Message> messages,
    List<String> targetReceiverIds = const [],
    List<String> targetRoomIds = const [],
  }) async {
    final supabase = _supabase;
    if (supabase == null || messages.isEmpty) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    final inserts = <Map<String, dynamic>>[];
    final now = DateTime.now().toIso8601String();

    for (final message in messages) {
      for (final receiverId in targetReceiverIds) {
        inserts.add({
          'sender_id': myId,
          'receiver_id': receiverId,
          'room_id': null,
          'content': message.content,
          'message_type': message.messageType,
          'media_url': message.mediaUrl,
          'media_thumbnail': message.mediaThumbnail,
          'created_at': now,
        });
      }
      for (final roomId in targetRoomIds) {
        inserts.add({
          'sender_id': myId,
          'receiver_id': null,
          'room_id': roomId,
          'content': message.content,
          'message_type': message.messageType,
          'media_url': message.mediaUrl,
          'media_thumbnail': message.mediaThumbnail,
          'created_at': now,
        });
      }
    }

    if (inserts.isNotEmpty) {
      await supabase.from('messages').insert(inserts);
    }
  }
}
