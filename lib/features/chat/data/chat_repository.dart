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
  static TypingStatesNotifier? instance;
  RealtimeChannel? _myBroadcastChannel;
  final Map<String, Timer> _expiryTimers = {};

  @override
  Map<String, bool> build() {
    instance = this;
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
      if (instance == this) {
        instance = null;
      }
      if (_myBroadcastChannel != null) {
        supabase.removeChannel(_myBroadcastChannel!);
      }
      for (final timer in _expiryTimers.values) {
        timer.cancel();
      }
    });

    return {};
  }

  void updateTyping(String senderId, bool isTyping) {
    _updateTypingState(senderId, isTyping);
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

  // Track active controllers and caches by otherUserId to allow instantaneous 0ms message injection
  static final Map<String, StreamController<List<Message>>> _activeDirectControllers = {};
  static final Map<String, List<Message>> _activeDirectCaches = {};
  static final Map<String, RealtimeChannel> _activeDirectChannels = {};
  static final Map<String, Timer> _activeDirectPollTimers = {};

  static String getConversationChannelName(String id1, String id2) {
    final sorted = [id1, id2]..sort();
    return 'chat_dm_${sorted[0]}_${sorted[1]}';
  }

  static void _injectDirectMessage(String partnerId, Message msg) {
    final controller = _activeDirectControllers[partnerId];
    if (controller != null && !controller.isClosed) {
      final currentList = _activeDirectCaches[partnerId] ?? [];
      if (!currentList.any((m) => m.id == msg.id)) {
        final updatedList = [msg, ...currentList];
        _activeDirectCaches[partnerId] = updatedList;
        controller.add(updatedList);
      }
    }
  }

  Future<void> _broadcastDirectMessage(String myId, String receiverId, Map<String, dynamic> insertedMsg) async {
    final supabase = _supabase;
    if (supabase == null) return;
    try {
      final channelName = getConversationChannelName(myId, receiverId);
      var channel = _activeDirectChannels[receiverId];
      if (channel == null) {
        channel = supabase.channel(channelName);
        _activeDirectChannels[receiverId] = channel;
        channel.subscribe();
      }
      channel.sendBroadcastMessage(
        event: 'new_message',
        payload: {'message': insertedMsg},
      );
    } catch (e) {
      debugPrint('Error broadcasting direct message: $e');
    }
  }

  Future<void> sendDirectTyping(String otherUserId, bool isTyping) async {
    final supabase = _supabase;
    if (supabase == null) return;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      final channelName = getConversationChannelName(myId, otherUserId);
      var channel = _activeDirectChannels[otherUserId];
      if (channel == null) {
        channel = supabase.channel(channelName);
        _activeDirectChannels[otherUserId] = channel;
        channel.subscribe();
      }
      channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'senderId': myId,
          'isTyping': isTyping,
        },
      );

      final targetChannel = supabase.channel('typing_broadcast_$otherUserId');
      targetChannel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'senderId': myId,
          'isTyping': isTyping,
        },
      );
    } catch (e) {
      debugPrint('Error sending direct typing broadcast: $e');
    }
  }

  Future<List<Message>> fetchOlderDirectMessages(String otherUserId, DateTime before, {int limit = 30}) async {
    final supabase = _supabase;
    if (supabase == null) return [];

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await supabase
          .from('messages')
          .select('*, message_reactions(emoji, user_id), message_reads(user_id)')
          .or('and(sender_id.eq.$myId,receiver_id.eq.$otherUserId),and(sender_id.eq.$otherUserId,receiver_id.eq.$myId)')
          .filter('room_id', 'is', null)
          .lt('created_at', before.toIso8601String())
          .order('created_at', ascending: false)
          .limit(limit);

      final list = (response as List).map((e) => Message.fromMap(e as Map<String, dynamic>)).toList();
      
      final controller = _activeDirectControllers[otherUserId];
      if (controller != null && !controller.isClosed) {
        final currentCache = _activeDirectCaches[otherUserId] ?? [];
        final currentIds = currentCache.map((m) => m.id).toSet();
        final newOldMessages = list.where((m) => !currentIds.contains(m.id)).toList();
        if (newOldMessages.isNotEmpty) {
          final updated = [...currentCache, ...newOldMessages];
          updated.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          _activeDirectCaches[otherUserId] = updated;
          controller.add(updated);
        }
      }

      return list;
    } catch (e) {
      debugPrint('Error fetching older direct messages: $e');
      return [];
    }
  }

  Stream<List<Message>> watchDirectMessages(String otherUserId, {int limit = 100}) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    _activeDirectPollTimers[otherUserId]?.cancel();
    _activeDirectControllers[otherUserId]?.close();

    final controller = StreamController<List<Message>>.broadcast();
    _activeDirectControllers[otherUserId] = controller;
    _activeDirectCaches[otherUserId] = [];

    Future<void> fetchMessages({bool silent = false}) async {
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
        
        final existingCache = _activeDirectCaches[otherUserId] ?? [];
        final fetchedIds = list.map((m) => m.id).toSet();
        final unmerged = existingCache.where((m) => !fetchedIds.contains(m.id)).toList();
        final combined = [...unmerged, ...list];
        combined.sort((a, b) => b.createdAt.compareTo(a.createdAt));

        _activeDirectCaches[otherUserId] = combined;
        controller.add(combined);
      } catch (e) {
        if (!silent) debugPrint('Error fetching direct messages: $e');
      }
    }

    // Initial fetch
    fetchMessages();

    // Canonical conversation channel for both Postgres CDC & Instant Peer-to-Peer Broadcast
    final channelName = getConversationChannelName(myId, otherUserId);
    final channel = supabase.channel(channelName);
    _activeDirectChannels[otherUserId] = channel;

    // 1. Instant peer-to-peer message broadcast (<50ms latency)
    channel.onBroadcast(
      event: 'new_message',
      callback: (payload) {
        try {
          final msgMap = payload['message'] as Map<String, dynamic>?;
          if (msgMap != null) {
            final msg = Message.fromMap(msgMap);
            _injectDirectMessage(otherUserId, msg);
          }
        } catch (e) {
          debugPrint('Error handling broadcast new_message: $e');
        }
      },
    );

    // 2. Typing indicator broadcast
    channel.onBroadcast(
      event: 'typing',
      callback: (payload) {
        final senderId = payload['senderId'] as String?;
        final isTyping = payload['isTyping'] as bool? ?? false;
        if (senderId != null) {
          TypingStatesNotifier.instance?.updateTyping(senderId, isTyping);
        }
      },
    );

    // 2b. Instant read receipt broadcast (turns ticks blue in <10ms)
    channel.onBroadcast(
      event: 'messages_read',
      callback: (payload) {
        try {
          final readerId = payload['readerId'] as String?;
          final readAtStr = payload['readAt'] as String?;
          final rawMsgIds = payload['messageIds'] as List?;
          final msgIds = rawMsgIds?.map((e) => e.toString()).toSet() ?? {};
          if (readerId != null && readerId == otherUserId) {
            final cache = _activeDirectCaches[otherUserId];
            if (cache != null && cache.isNotEmpty) {
              final readAt = readAtStr != null ? DateTime.tryParse(readAtStr) : null;
              var changed = false;
              final updated = cache.map((msg) {
                if (msg.senderId == myId) {
                  final isTarget = msgIds.contains(msg.id) ||
                      (readAt != null && !msg.createdAt.isAfter(readAt));
                  if (isTarget && !msg.readUserIds.contains(readerId)) {
                    changed = true;
                    return msg.copyWith(readUserIds: [...msg.readUserIds, readerId]);
                  }
                }
                return msg;
              }).toList();
              if (changed) {
                _activeDirectCaches[otherUserId] = updated;
                controller.add(updated);
              }
            }
          }
        } catch (e) {
          debugPrint('Error handling broadcast messages_read: $e');
        }
      },
    );

    // 3. Postgres changes
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
          fetchMessages(silent: true);
        }
      },
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reactions',
      callback: (payload) => fetchMessages(silent: true),
    ).onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'message_reads',
      callback: (payload) => fetchMessages(silent: true),
    ).subscribe();

    // 4. Background heartbeat poll (every 4 seconds) as safety fallback
    final pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!controller.isClosed) {
        fetchMessages(silent: true);
      }
    });
    _activeDirectPollTimers[otherUserId] = pollTimer;

    controller.onCancel = () {
      pollTimer.cancel();
      _activeDirectPollTimers.remove(otherUserId);
      _activeDirectControllers.remove(otherUserId);
      _activeDirectCaches.remove(otherUserId);
      final ch = _activeDirectChannels.remove(otherUserId);
      if (ch != null) {
        supabase.removeChannel(ch);
      }
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

  Future<Message?> sendMessage({
    String? receiverId,
    required String content,
    String? roomId,
    String? replyTo,
    String messageType = 'text',
    String? mediaUrl,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return null;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return null;

    final response = await supabase.from('messages').insert({
      'sender_id': myId,
      'receiver_id': receiverId,
      'room_id': roomId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'reply_to': replyTo,
      'created_at': DateTime.now().toIso8601String(),
    }).select();

    final insertedMsg = response.firstOrNull;
    if (insertedMsg == null) return null;

    final messageObj = Message.fromMap(insertedMsg);

    // 1. Instantly inject into local cache & stream controller (0ms UI latency)
    if (receiverId != null) {
      _injectDirectMessage(receiverId, messageObj);
      // 2. Broadcast immediately over websocket to recipient (<50ms delivery)
      _broadcastDirectMessage(myId, receiverId, insertedMsg);
    }

    // 3. Dispatch notification in background (non-blocking)
    _dispatchMessageNotification(
      supabase: supabase,
      myId: myId,
      receiverId: receiverId,
      roomId: roomId,
      insertedMsg: insertedMsg,
      content: content,
    );

    return messageObj;
  }

  void _dispatchMessageNotification({
    required SupabaseClient supabase,
    required String myId,
    String? receiverId,
    String? roomId,
    required Map<String, dynamic> insertedMsg,
    required String content,
  }) {
    unawaited(() async {
      try {
        final senderProfile = await supabase.from('profiles').select('username, display_name').eq('id', myId).maybeSingle();
        final senderName = senderProfile?['display_name'] as String? ?? senderProfile?['username'] as String? ?? 'Friend';

        if (receiverId != null) {
          await supabase.from('notifications').insert({
            'user_id': receiverId,
            'type': 'message',
            'title': senderName,
            'body': content,
            'data': {
              'message_id': insertedMsg['id'],
              'sender_id': myId,
              'sender_name': senderName,
              'content': content,
            },
          });
        } else if (roomId != null) {
          final participants = await supabase.from('room_participants').select('user_id').eq('room_id', roomId);
          final List<dynamic> list = participants as List<dynamic>? ?? [];
          final List<Map<String, dynamic>> notificationInserts = [];
          for (final p in list) {
            final pUserId = p['user_id'] as String?;
            if (pUserId != null && pUserId != myId) {
              notificationInserts.add({
                'user_id': pUserId,
                'type': 'message',
                'title': senderName,
                'body': content,
                'data': {
                  'room_id': roomId,
                  'message_id': insertedMsg['id'],
                  'sender_id': myId,
                  'sender_name': senderName,
                  'content': content,
                },
              });
            }
          }
          if (notificationInserts.isNotEmpty) {
            await supabase.from('notifications').insert(notificationInserts);
          }
        }
      } catch (e) {
        debugPrint('Error dispatching message notification: $e');
      }
    }());
  }

  Future<Message?> sendMediaMessage({
    String? receiverId,
    required String messageType,
    required String mediaUrl,
    String? mediaThumbnail,
    String? content,
    String? roomId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return null;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return null;

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
    if (insertedMsg == null) return null;

    final messageObj = Message.fromMap(insertedMsg);

    // 1. Instantly inject into local cache & stream controller (0ms UI latency)
    if (receiverId != null) {
      _injectDirectMessage(receiverId, messageObj);
      // 2. Broadcast immediately over websocket to recipient (<50ms delivery)
      _broadcastDirectMessage(myId, receiverId, insertedMsg);
    }

    // 3. Dispatch notification in background (non-blocking)
    final notificationBody = messageType == 'image'
        ? 'Sent an image'
        : messageType == 'video'
            ? 'Sent a video'
            : messageType == 'audio' || messageType == 'voice'
                ? 'Sent a voice message'
                : 'Sent an attachment';

    _dispatchMessageNotification(
      supabase: supabase,
      myId: myId,
      receiverId: receiverId,
      roomId: roomId,
      insertedMsg: insertedMsg,
      content: notificationBody,
    );

    return messageObj;
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

      final nowIso = DateTime.now().toIso8601String();
      final inserts = unreadMsgIds.map((msgId) => {
        'message_id': msgId,
        'user_id': myId,
        'read_at': nowIso,
      }).toList();

      await supabase.from('message_reads').upsert(inserts);

      // Mark message notifications as read so pending notification count resets
      try {
        await supabase
            .from('notifications')
            .update({'read': true})
            .eq('user_id', myId)
            .eq('type', 'message');
      } catch (_) {}

      // Broadcast read receipt event across conversation channel (<10ms UI update)
      try {
        final channelName = getConversationChannelName(myId, partnerId);
        final ch = _activeDirectChannels[partnerId] ?? supabase.channel(channelName);
        await ch.sendBroadcastMessage(
          event: 'messages_read',
          payload: {
            'readerId': myId,
            'partnerId': partnerId,
            'readAt': nowIso,
            'messageIds': unreadMsgIds,
          },
        );
      } catch (broadcastErr) {
        debugPrint('Error broadcasting messages_read: $broadcastErr');
      }
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
