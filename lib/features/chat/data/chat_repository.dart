import 'dart:async';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(SupabaseService.clientOrNull);
});

final typingIndicatorProvider = StreamProvider.family<bool, String>((
  ref,
  userId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchTyping(userId);
});

class ChatRepository {
  ChatRepository(this._supabase);

  final SupabaseClient? _supabase;
  SupabaseClient? get supabase => _supabase;

  Stream<List<Message>> watchDirectMessages(String otherUserId) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    final controller = StreamController<List<Message>>();

    void fetchMessages() async {
      try {
        final response = await supabase
            .from('messages')
            .select()
            .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
            .filter('room_id', 'is', null)
            .order('created_at', ascending: false)
            .limit(100);
        if (controller.isClosed) return;
        final list = (response as List).map(Message.fromMap).toList();
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
    ).subscribe();

    controller.onCancel = () {
      supabase.removeChannel(channel);
    };

    return controller.stream;
  }

  Stream<List<Message>> watchRoomMessages(String roomId) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final controller = StreamController<List<Message>>();

    void fetchMessages() async {
      try {
        final response = await supabase
            .from('messages')
            .select()
            .eq('room_id', roomId)
            .order('created_at', ascending: false)
            .limit(100);
        if (controller.isClosed) return;
        final list = (response as List).map(Message.fromMap).toList();
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
          for (final p in list) {
            final pUserId = p['user_id'] as String?;
            if (pUserId != null && pUserId != myId) {
              await supabase.from('notifications').insert({
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
          for (final p in list) {
            final pUserId = p['user_id'] as String?;
            if (pUserId != null && pUserId != myId) {
              await supabase.from('notifications').insert({
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

    await supabase.from('typing_indicators').upsert({
      'user_id': myId,
      'chat_with': chatWithUserId,
      'room_id': roomId,
      'is_typing': isTyping,
      'updated_at': DateTime.now().toIso8601String(),
    });
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

    await supabase.from('message_reads').upsert({
      'message_id': messageId,
      'user_id': myId,
      'read_at': DateTime.now().toIso8601String(),
    });
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

        for (final partnerId in chats.keys) {
          chats[partnerId]!['partner_profile'] = profilesMap[partnerId];

          final unreadResponse = await supabase
              .from('messages')
              .select('id, message_reads(id, user_id)')
              .eq('sender_id', partnerId)
              .eq('receiver_id', myId)
              .filter('room_id', 'is', null);

          final unreadCount = (unreadResponse as List)
              .where((m) {
                final reads = m['message_reads'] as List? ?? [];
                return !reads.any((r) => r['user_id'] == myId);
              })
              .length;

          chats[partnerId]!['unread_count'] = unreadCount;
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
}
