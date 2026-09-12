import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:calcx/core/models/message.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/media/data/media_repository.dart';
import 'package:calcx/app/app_theme.dart';
import 'package:calcx/core/services/theme_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/chat/presentation/chat_list_page.dart';
import 'package:calcx/features/chat/presentation/widgets/forward_recipient_picker_dialog.dart';
import 'package:calcx/core/widgets/quick_panic_calculator_button.dart';
import 'package:calcx/features/chat/presentation/widgets/interactive_message_text.dart';
import 'package:calcx/features/chat/presentation/widgets/message_hover_copy_button.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:http/http.dart' as http;
import 'package:calcx/features/rooms/presentation/room_detail_page.dart';
import 'package:calcx/core/utils/platform_file_helper.dart' as pf;

const Map<String, String> animatedEmojiMap = {
  '❤️': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Red%20Heart.webp',
  '👍': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Thumbs%20Up.webp',
  '😂': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20With%20Tears%20Of%20Joy.webp',
  '😮': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20With%20Open%20Mouth.webp',
  '😢': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Crying%20Face.webp',
  '🙏': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Folded%20Hands.webp',
  '🔥': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Animals%20and%20Nature/Fire.webp',
  '👏': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Clapping%20Hands.webp',
  '💀': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Skull.webp',
  '🤔': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Thinking%20Face.webp',
  '😎': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Smiling%20Face%20With%20Sunglasses.webp',
  '👀': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Eyes.webp',
  '💯': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Hundred%20Points.webp',
  '🚀': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Travel%20and%20Places/Rocket.webp',
  '😭': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Loudly%20Crying%20Face.webp',
  '🤮': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20Vomiting.webp',
  '❌': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Cross%20Mark.webp',
  '✅': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Check%20Mark%20Button.webp',
  '💡': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Objects/Light%20Bulb.webp',
  '😉': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Winking%20Face.webp',
  '🌟': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Animals%20and%20Nature/Glowing%20Star.webp',
  '👑': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Objects/Crown.webp',
  '💔': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Broken%20Heart.webp',
  '😡': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Angry%20Face.webp',
  '😘': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20Blowing%20A%20Kiss.webp',
  '💋': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Kiss%20Mark.webp',
  '😚': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Kissing%20Face%20With%20Closed%20Eyes.webp',
  '😗': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Kissing%20Face.webp',
  '💖': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Sparkling%20Heart.webp',
  '💕': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Two%20Hearts.webp',
  '💓': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Beating%20Heart.webp',
  '💗': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Growing%20Heart.webp',
  '💘': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Heart%20With%20Arrow.webp',
  '💝': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Heart%20With%20Ribbon.webp',
  '💞': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Revolving%20Hearts.webp',
};

final RegExp emojiRegex = RegExp(
  r'(' +
      [
        '❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '👏', '💀', '🤔', '😎', '👀',
        '💯', '🚀', '😭', '🤮', '❌', '✅', '💡', '😉', '🌟', '👑', '💔', '😡',
        '😘', '💋', '😚', '😗', '💖', '💕', '💓', '💗', '💘', '💝', '💞'
      ].map((e) => RegExp.escape(e)).join('|') +
      r')',
);

class ChatMessageLimitsNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => {};

  void incrementLimit(String userId) {
    state = {
      ...state,
      userId: (state[userId] ?? 30) + 30,
    };
  }
}

final chatMessageLimitsProvider = NotifierProvider<ChatMessageLimitsNotifier, Map<String, int>>(
  ChatMessageLimitsNotifier.new,
);

final chatMessagesProvider = StreamProvider.family<List<Message>, String>((ref, userId) {
  final limits = ref.watch(chatMessageLimitsProvider);
  final limit = limits[userId] ?? 30;
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchDirectMessages(userId, limit: limit);
});

final otherUserProfileProvider = StreamProvider.family<UserProfile?, String>((ref, userId) {
  final client = SupabaseService.clientOrNull;
  if (client == null) return const Stream.empty();
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) => data.isNotEmpty ? UserProfile.fromMap(data.first) : null);
});

final replyMessageProvider = FutureProvider.family<Message?, String>((ref, replyToId) async {
  final client = SupabaseService.clientOrNull;
  if (client == null) return null;
  try {
    final response = await client.from('messages').select().eq('id', replyToId).maybeSingle();
    if (response == null) return null;
    return Message.fromMap(response);
  } catch (_) {
    return null;
  }
});

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key, required this.otherUserId});

  final String otherUserId;

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _scrollController = ScrollController();
  
  UserProfile? _otherUser;
  Message? _replyingTo;
  
  bool _isNearBottom = true;
  bool _showNewMessagesBanner = false;
  int _unreadCount = 0;

  RealtimeChannel? _readsSubscription;
  DateTime? _otherUserLastReadAt;

  Timer? _typingThrottleTimer;
  Timer? _typingClearTimer;
  bool _lastSentTypingState = false;
  
  final List<Message> _optimisticMessages = [];
  Timer? _autoRetryTimer;
  bool _isSearching = false;
  String _searchQuery = '';
  List<Message> _searchResults = [];
  int _currentSearchMatchIndex = 0;

  bool _isSelectionMode = false;
  Set<String> _selectedMessageIds = {};
  static final Map<String, String> _chatDrafts = {};

  bool _isTextEmpty = true;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  late final AudioRecorder _audioRecorder;

  // Map to store keys for message elements so we can scroll to them
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  List<Message> _allMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioRecorder = AudioRecorder();
    _loadOtherUser();
    _scrollController.addListener(_scrollListener);
    
    final draft = _chatDrafts[widget.otherUserId];
    if (draft != null && draft.isNotEmpty) {
      _messageController.text = draft;
      _isTextEmpty = false;
    }

    _messageController.addListener(() {
      final text = _messageController.text;
      _onTextChanged(text);
    });

    final client = SupabaseService.clientOrNull;
    if (client != null) {
      _readsSubscription = client
          .channel('dm_reads_${widget.otherUserId}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'message_reads',
            callback: (payload) {
              final record = payload.newRecord;
              final oldRecord = payload.oldRecord;
              final userId = record['user_id'] ?? oldRecord['user_id'];
              if (userId == widget.otherUserId) {
                _fetchLastReadCursor();
              }
            },
          );
      _readsSubscription!.subscribe();
      _fetchLastReadCursor();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markAllAsRead(widget.otherUserId);
      ref.invalidate(recentChatsProvider);
    });

    _autoRetryTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      final failedMsgs = _optimisticMessages.where((m) => m.status == MessageStatus.failed).toList();
      for (final msg in failedMsgs) {
        if (mounted) {
          setState(() {
            final idx = _optimisticMessages.indexWhere((m) => m.id == msg.id);
            if (idx != -1) {
              _optimisticMessages[idx] = _optimisticMessages[idx].copyWith(status: MessageStatus.sending);
            }
          });
        }
        _sendOptimistic(msg);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Clear typing indicator immediately
    if (_lastSentTypingState) {
      _lastSentTypingState = false;
      _sendTypingBroadcast(false);
    }
    
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    _typingThrottleTimer?.cancel();
    _typingClearTimer?.cancel();
    _recordTimer?.cancel();
    _autoRetryTimer?.cancel();
    _audioRecorder.dispose();

    final client = SupabaseService.clientOrNull;
    if (client != null && _readsSubscription != null) {
      client.removeChannel(_readsSubscription!);
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Clear typing indicator when app goes to background
      if (_lastSentTypingState) {
        _lastSentTypingState = false;
        _sendTypingBroadcast(false);
        _typingThrottleTimer?.cancel();
        _typingThrottleTimer = null;
        _typingClearTimer?.cancel();
        _typingClearTimer = null;
      }
    }
  }

  void _sendTypingBroadcast(bool isTyping) {
    if (!mounted) return;
    final myId = ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
    if (myId == null) return;

    final channel = ref.read(typingSendChannelProvider(widget.otherUserId));
    if (channel != null) {
      channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'senderId': myId,
          'isTyping': isTyping,
        },
      );
    }
  }

  void _onTextChanged(String val) {
    _chatDrafts[widget.otherUserId] = val;
    final isEmpty = val.trim().isEmpty;
    if (isEmpty != _isTextEmpty) {
      setState(() {
        _isTextEmpty = isEmpty;
      });
    }

    if (val.isNotEmpty) {
      // Throttle: Send typing event at most once every 2 seconds
      if (!_lastSentTypingState || _typingThrottleTimer == null) {
        _lastSentTypingState = true;
        _sendTypingBroadcast(true);
        _typingThrottleTimer = Timer(const Duration(seconds: 2), () {
          _typingThrottleTimer = null;
        });
      }
      
      // Debounce: Clear typing state after 2.5 seconds of inactivity
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(milliseconds: 2500), () {
        _lastSentTypingState = false;
        _sendTypingBroadcast(false);
      });
    } else {
      // Clear typing immediately on empty text
      _typingThrottleTimer?.cancel();
      _typingThrottleTimer = null;
      _typingClearTimer?.cancel();
      _typingClearTimer = null;
      if (_lastSentTypingState) {
        _lastSentTypingState = false;
        _sendTypingBroadcast(false);
      }
    }
  }

  Future<void> _fetchLastReadCursor() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    try {
      final response = await client
          .from('message_reads')
          .select('read_at, messages!inner(sender_id, receiver_id)')
          .eq('user_id', widget.otherUserId)
          .eq('messages.sender_id', client.auth.currentUser!.id)
          .order('read_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null && response['read_at'] != null) {
        final readAtStr = response['read_at'] as String;
        final readAt = DateTime.parse(readAtStr);
        if (mounted) {
          setState(() {
            _otherUserLastReadAt = readAt;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching last read cursor: $e');
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final tempDirPath = await pf.getTempDirectoryPath();
          path = '$tempDirPath/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
        }

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path ?? '',
        );

        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });

        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordDuration++;
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      final path = await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });

      if (path != null) {
        final xfile = XFile(path);
        await _uploadAndSendMedia(xfile, 'audio', messageType: 'voice');
      }
    } catch (e) {
      debugPrint('Error stopping recording: $e');
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    _recordTimer = null;
    try {
      await _audioRecorder.stop();
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    } catch (e) {
      debugPrint('Error cancelling recording: $e');
    }
  }

  String _formatRecordDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  void _scrollListener() {
    if (!_scrollController.hasClients) return;
    final currentScroll = _scrollController.position.pixels;
    final nearBottom = currentScroll < 200;

    if (nearBottom != _isNearBottom) {
      setState(() {
        _isNearBottom = nearBottom;
        if (nearBottom) {
          _showNewMessagesBanner = false;
          _unreadCount = 0;
        }
      });
    }

    if (_scrollController.position.maxScrollExtent > 0 &&
        currentScroll >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(chatMessageLimitsProvider.notifier).incrementLimit(widget.otherUserId);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
      setState(() {
        _showNewMessagesBanner = false;
        _unreadCount = 0;
      });
    }
  }

  void _onSearchQueryChanged(String query) async {
    final trimmed = query.trim();
    setState(() {
      _searchQuery = query;
      _currentSearchMatchIndex = 0;
    });

    if (trimmed.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    final localMatches = _allMessages.where((m) => m.content.toLowerCase().contains(trimmed.toLowerCase())).toList();
    setState(() {
      _searchResults = localMatches;
    });

    try {
      final remoteMatches = await ref.read(chatRepositoryProvider).searchDirectMessages(widget.otherUserId, trimmed);
      if (mounted && _searchQuery.trim() == trimmed) {
        final Map<String, Message> combinedMap = {};
        for (final m in localMatches) {
          combinedMap[m.id] = m;
        }
        for (final m in remoteMatches) {
          combinedMap[m.id] = m;
        }
        final list = combinedMap.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        setState(() {
          _searchResults = list;
          if (_searchResults.isNotEmpty) {
            _scrollToMessage(_searchResults[0].id);
          }
        });
      }
    } catch (_) {}
  }

  void _scrollToMessage(String msgId) {
    setState(() {
      _highlightedMessageId = msgId;
    });

    Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });

    final index = _allMessages.indexWhere((m) => m.id == msgId);
    if (index == -1) {
      ref.read(chatMessageLimitsProvider.notifier).incrementLimit(widget.otherUserId);
    }

    final key = _messageKeys[msgId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (index != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          index * 85.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  Future<void> _loadOtherUser() async {
    try {
      final profile = await ref
          .read(friendsRepositoryProvider)
          .getUserById(widget.otherUserId);
      if (mounted) {
        setState(() {
          _otherUser = profile;
        });
      }
    } catch (_) {}
  }

  Future<void> _sendOptimistic(Message msg) async {
    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMessage(
        receiverId: msg.receiverId,
        content: msg.content,
        replyTo: msg.replyTo,
      );
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == msg.id);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _optimisticMessages.indexWhere((m) => m.id == msg.id);
          if (idx != -1) {
            _optimisticMessages[idx] = _optimisticMessages[idx].copyWith(status: MessageStatus.failed);
          }
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) {
      _messageFocusNode.requestFocus();
      return;
    }

    _messageController.clear();
    _messageFocusNode.requestFocus();
    
    // Clear typing states immediately on message send
    _typingThrottleTimer?.cancel();
    _typingThrottleTimer = null;
    _typingClearTimer?.cancel();
    _typingClearTimer = null;
    if (_lastSentTypingState) {
      _lastSentTypingState = false;
      _sendTypingBroadcast(false);
    }

    final replyId = _replyingTo?.id;
    setState(() {
      _replyingTo = null;
    });

    final myId = ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
    if (myId == null) return;

    final optimisticId = 'opt-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1000)}';
    final optimisticMsg = Message(
      id: optimisticId,
      senderId: myId,
      receiverId: widget.otherUserId,
      content: content,
      replyTo: replyId,
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    setState(() {
      _optimisticMessages.insert(0, optimisticMsg);
    });
    _scrollToBottom();

    await _sendOptimistic(optimisticMsg);
  }

  void _showMessageMenu(Message message) {
    final myId = ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
    final isMyMsg = message.senderId == myId;
    final isLight = Theme.of(context).brightness == Brightness.light;

    HapticFeedback.mediumImpact();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'MessageMenu',
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 150),
      pageBuilder: (context, animation, secondaryAnimation) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          child: Center(
            child: ScaleTransition(
              scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
              child: FadeTransition(
                opacity: animation,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.82,
                    decoration: BoxDecoration(
                      color: isLight ? Colors.white : const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Quick Emojis
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: ['❤️', '👍', '😂', '😮', '😢', '🔥'].map((emoji) {
                              return GestureDetector(
                                onTap: () {
                                  ref.read(chatRepositoryProvider).addReaction(message.id, emoji);
                                  Navigator.pop(context);
                                },
                                child: Text(
                                  emoji,
                                  style: const TextStyle(fontSize: 26),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const Divider(height: 1, thickness: 0.5, color: Colors.grey),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.reply_rounded, color: isLight ? Colors.black87 : Colors.white70),
                          title: Text('Reply', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _replyingTo = message;
                            });
                          },
                        ),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.copy_rounded, color: isLight ? Colors.black87 : Colors.white70),
                          title: Text('Copy Text', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: message.content));
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Copied to clipboard')),
                            );
                          },
                        ),
                        ListTile(
                          dense: true,
                          leading: Icon(Icons.forward_rounded, color: isLight ? Colors.black87 : Colors.white70),
                          title: Text('Forward', style: TextStyle(color: isLight ? Colors.black87 : Colors.white)),
                          onTap: () {
                            Navigator.pop(context);
                            setState(() {
                              _isSelectionMode = true;
                              _selectedMessageIds = {message.id};
                            });
                          },
                        ),
                        if (isMyMsg) ...[
                          const Divider(height: 1, thickness: 0.5, color: Colors.grey),
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                            title: const Text('Unsend message', style: TextStyle(color: Colors.redAccent)),
                            onTap: () {
                              ref.read(chatRepositoryProvider).deleteMessage(message.id);
                              Navigator.pop(context);
                            },
                          ),
                        ],
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyPreview() {
    final isLight = Theme.of(context).brightness == Brightness.light;
    if (_replyingTo == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLight ? const Color(0xFFF1F1F4) : const Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: isLight ? Colors.black12 : Colors.white10)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.reply_rounded,
            color: isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to partner',
                  style: TextStyle(
                    fontSize: 11,
                    color: isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content.isNotEmpty ? _replyingTo!.content : 'Media message',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isLight ? Colors.black54 : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatMessagesProvider(widget.otherUserId));
    final isTypingAsync = ref.watch(typingIndicatorProvider(widget.otherUserId));
    final otherUserAsync = ref.watch(otherUserProfileProvider(widget.otherUserId));
    final otherUser = otherUserAsync.value ?? _otherUser;
    final themeSettings = ref.watch(themeServiceProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    ref.listen(chatMessagesProvider(widget.otherUserId), (prev, next) {
      final messages = next.value ?? [];
      final prevCount = prev?.value?.length ?? 0;
      
      ref.read(chatRepositoryProvider).markAllAsRead(widget.otherUserId);
      ref.invalidate(recentChatsProvider);

      if (messages.length > prevCount && messages.isNotEmpty) {
        final lastMsg = messages.first;
        final myId = ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
        final isFromMe = lastMsg.senderId == myId;

        if (isFromMe || _isNearBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        } else {
          setState(() {
            _showNewMessagesBanner = true;
            _unreadCount = messages.length - prevCount;
          });
        }
      }
    });

    // Check for shared chat theme/wallpaper set by either friend in this conversation
    String? sharedWallpaper;
    final allChatMessages = [..._optimisticMessages, ...?(messagesAsync.value ?? <Message>[])];
    for (final m in allChatMessages.reversed) {
      if (m.messageType == 'chat_wallpaper' && m.mediaUrl != null && m.mediaUrl!.isNotEmpty) {
        if (m.mediaUrl == 'reset') {
          sharedWallpaper = null;
        } else {
          sharedWallpaper = m.mediaUrl;
        }
        break;
      }
    }

    final wallpaperPath = sharedWallpaper ??
        themeSettings.chatWallpapers[widget.otherUserId] ??
        themeSettings.globalWallpaperPath;

    return Scaffold(
      backgroundColor: isLight ? Colors.white : Colors.black,
      appBar: _isSelectionMode
          ? AppBar(
              backgroundColor: isLight ? Colors.white : Colors.black,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  setState(() {
                    _isSelectionMode = false;
                    _selectedMessageIds.clear();
                  });
                },
              ),
              title: Text(
                '${_selectedMessageIds.length} Selected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
              ),
              actions: [
                const QuickPanicCalculatorButton(),
                IconButton(
                  icon: const Icon(Icons.forward_rounded),
                  onPressed: _selectedMessageIds.isEmpty
                      ? null
                      : () async {
                          final selectedMsgs = _allMessages.where((m) => _selectedMessageIds.contains(m.id)).toList();
                          final res = await ForwardRecipientPickerDialog.show(context, selectedMsgs);
                          if (res == true && mounted) {
                            setState(() {
                              _isSelectionMode = false;
                              _selectedMessageIds.clear();
                            });
                          }
                        },
                ),
              ],
            )
          : AppBar(
              backgroundColor: isLight ? Colors.white : Colors.black,
              elevation: 0,
              scrolledUnderElevation: 0,
              shape: Border(
                bottom: BorderSide(
                  color: isLight ? const Color(0xFFDBDBDB) : const Color(0xFF262626),
                  width: 0.5,
                ),
              ),
              titleSpacing: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              title: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Search history...',
                              border: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              filled: false,
                            ),
                            onChanged: _onSearchQueryChanged,
                          ),
                        ),
                        if (_searchResults.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: Text(
                              'Match ${_currentSearchMatchIndex + 1} of ${_searchResults.length}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                          backgroundImage: otherUser?.avatarUrl != null ? NetworkImage(otherUser!.avatarUrl!) : null,
                          child: otherUser?.avatarUrl == null
                              ? Text(
                                  otherUser?.displayName.isNotEmpty == true
                                      ? otherUser!.displayName[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                otherUser?.displayName ?? 'Chat',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: isLight ? Colors.black87 : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                isTypingAsync.maybeWhen(
                                  data: (isTyping) => isTyping ? 'typing...' : (otherUser?.getPresenceText() ?? 'Offline'),
                                  orElse: () => otherUser?.getPresenceText() ?? 'Offline',
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isTypingAsync.value == true
                                      ? (isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0))
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
              actions: [
                const QuickPanicCalculatorButton(),
                if (_isSearching) ...[
                  if (_searchResults.isNotEmpty) ...[
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 22),
                      onPressed: () {
                        if (_searchResults.isEmpty) return;
                        setState(() {
                          _currentSearchMatchIndex = (_currentSearchMatchIndex - 1 + _searchResults.length) % _searchResults.length;
                        });
                        _scrollToMessage(_searchResults[_currentSearchMatchIndex].id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 22),
                      onPressed: () {
                        if (_searchResults.isEmpty) return;
                        setState(() {
                          _currentSearchMatchIndex = (_currentSearchMatchIndex + 1) % _searchResults.length;
                        });
                        _scrollToMessage(_searchResults[_currentSearchMatchIndex].id);
                      },
                    ),
                  ],
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchQuery = '';
                        _searchResults.clear();
                        _currentSearchMatchIndex = 0;
                      });
                    },
                  ),
                ] else ...[
                  IconButton(
                    icon: const Icon(Icons.search_rounded, size: 22),
                    onPressed: () {
                      setState(() {
                        _isSearching = true;
                      });
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.phone_outlined, size: 22),
                    onPressed: () async {
                      if (otherUser == null) return;
                      try {
                        final newCall = await ref.read(callRepositoryProvider).initiateCall(
                          receiverId: otherUser.id,
                          callType: 'audio',
                        );
                        if (context.mounted) {
                          ref.read(isCallScreenShowingProvider.notifier).state = true;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveCallPage(call: newCall),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not start the call. Please try again.')),
                          );
                        }
                      }
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam_outlined, size: 24),
                    onPressed: () async {
                      if (otherUser == null) return;
                      try {
                        final newCall = await ref.read(callRepositoryProvider).initiateCall(
                          receiverId: otherUser.id,
                          callType: 'video',
                        );
                        if (context.mounted) {
                          ref.read(isCallScreenShowingProvider.notifier).state = true;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ActiveCallPage(call: newCall),
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Could not start the video call. Please try again.')),
                          );
                        }
                      }
                    },
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.info_outline_rounded, size: 22),
                    onSelected: (val) async {
                      if (val == 'wallpaper') {
                        try {
                          final picker = ImagePicker();
                          final picked = await picker.pickImage(source: ImageSource.gallery);
                          if (picked == null) return;
                          
                          // 1. Upload to Supabase Storage media bucket
                          final bytes = await picked.readAsBytes();
                          final client = SupabaseService.clientOrNull;
                          if (client == null) throw 'Supabase not initialized';
                          final fileName = 'chat_wallpapers/wp_${widget.otherUserId}_${DateTime.now().millisecondsSinceEpoch}.png';
                          await client.storage.from('media').uploadBinary(
                            fileName,
                            bytes,
                            fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
                          );
                          final publicUrl = client.storage.from('media').getPublicUrl(fileName);

                          // 2. Broadcast and save message so friend also receives it
                          await ref.read(chatRepositoryProvider).sendMessage(
                            receiverId: widget.otherUserId,
                            content: 'updated the chat theme',
                            messageType: 'chat_wallpaper',
                            mediaUrl: publicUrl,
                          );

                          // 3. Update local theme service
                          await ref.read(themeServiceProvider.notifier).setChatWallpaperPreset(
                            widget.otherUserId,
                            publicUrl,
                          );

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('✅ Chat wallpaper updated for both friends!')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not update wallpaper: $e')),
                            );
                          }
                        }
                      } else if (val.startsWith('preset_')) {
                        await ref.read(chatRepositoryProvider).sendMessage(
                          receiverId: widget.otherUserId,
                          content: 'updated the chat theme',
                          messageType: 'chat_wallpaper',
                          mediaUrl: val,
                        );
                        await ref.read(themeServiceProvider.notifier).setChatWallpaperPreset(
                              widget.otherUserId,
                              val,
                            );
                        if (mounted) {
                          final themeTitle = val == 'preset_emerald'
                              ? 'Emerald'
                              : val == 'preset_crimson'
                                  ? 'Crimson'
                                  : val == 'preset_amoled'
                                      ? 'AMOLED'
                                      : val == 'preset_sunset'
                                          ? 'Sunset'
                                          : 'Theme';
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('✅ $themeTitle theme set for both friends!')),
                          );
                        }
                      } else if (val == 'reset_wallpaper') {
                        await ref.read(chatRepositoryProvider).sendMessage(
                          receiverId: widget.otherUserId,
                          content: 'reset the chat theme',
                          messageType: 'chat_wallpaper',
                          mediaUrl: 'reset',
                        );
                        await ref.read(themeServiceProvider.notifier).removeChatWallpaper(widget.otherUserId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Chat theme reset to default for both!')),
                          );
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'wallpaper',
                        child: Row(
                          children: [
                            Icon(Icons.wallpaper_rounded, size: 18, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Custom Wallpaper'),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      const PopupMenuItem(
                        value: 'preset_emerald',
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 16, color: Color(0xFF00E676)),
                            SizedBox(width: 8),
                            Text('Emerald Theme'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'preset_crimson',
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 16, color: Color(0xFFFF1744)),
                            SizedBox(width: 8),
                            Text('Crimson Theme'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'preset_amoled',
                        child: Row(
                          children: [
                            Icon(Icons.circle, size: 16, color: Color(0xFF00DBE9)),
                            SizedBox(width: 8),
                            Text('AMOLED Theme'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'preset_sunset',
                        child: Row(
                          children: [
                            Icon(Icons.wb_sunny_rounded, size: 18, color: Color(0xFFFF5722)),
                            SizedBox(width: 8),
                            Text('Sunset Theme'),
                          ],
                        ),
                      ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'reset_wallpaper',
                  child: Row(
                    children: [
                      Icon(Icons.layers_clear_rounded, size: 18, color: Colors.redAccent),
                      SizedBox(width: 8),
                      Text('Reset Theme'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          // Background wallpaper layer
          if (wallpaperPath != null)
            Positioned.fill(
              child: Opacity(
                opacity: themeSettings.wallpaperOpacity,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(
                    sigmaX: themeSettings.wallpaperBlur,
                    sigmaY: themeSettings.wallpaperBlur,
                  ),
                  child: Container(
                    decoration: _getPresetDecoration(wallpaperPath),
                    child: Container(
                      color: Colors.black.withOpacity(themeSettings.wallpaperDim),
                    ),
                  ),
                ),
              ),
            ),
          
          Column(
            children: [
              Expanded(
                child: SelectionArea(
                  child: messagesAsync.when(
                    data: (dbMessages) {
                      _allMessages = [..._optimisticMessages, ...dbMessages];
                      final filteredMessages = _searchQuery.isEmpty
                          ? _allMessages
                          : _allMessages
                              .where((m) => m.content.toLowerCase().contains(_searchQuery.toLowerCase()))
                              .toList();

                      if (filteredMessages.isEmpty) {
                        return const Center(child: Text('No messages found'));
                      }

                      return Stack(
                        children: [
                          ListView.builder(
                            controller: _scrollController,
                            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                            reverse: true,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: filteredMessages.length + (isTypingAsync.value == true ? 1 : 0),
                            itemBuilder: (context, index) {
                              final hasTyping = isTypingAsync.value == true;
                              if (hasTyping && index == 0) {
                                return _buildTypingBubble(context, otherUser);
                              }

                              final messageIndex = hasTyping ? index - 1 : index;
                              final message = filteredMessages[messageIndex];
                              final isMe = message.senderId != widget.otherUserId;

                              // Consecutive message grouping within 2 minutes
                              bool isGrouped = false;
                              bool isLastInGroup = true;
                              bool isFirstInGroup = true;

                              if (messageIndex < filteredMessages.length - 1) {
                                final nextMsg = filteredMessages[messageIndex + 1];
                                if (nextMsg.senderId == message.senderId &&
                                    message.createdAt.difference(nextMsg.createdAt).inMinutes.abs() < 2) {
                                  isGrouped = true;
                                  isFirstInGroup = false; // Next is older in reversed order
                                }
                              }

                              if (messageIndex > 0) {
                                final prevMsg = filteredMessages[messageIndex - 1];
                                if (prevMsg.senderId == message.senderId &&
                                    prevMsg.createdAt.difference(message.createdAt).inMinutes.abs() < 2) {
                                  isLastInGroup = false; // Prev is newer in reversed order
                                }
                              }

                              final showDivider = _showNewMessagesBanner && 
                                  messageIndex == (_unreadCount - 1);

                              // Ensure a global key exists for scrolling to replies
                              final msgKey = _messageKeys.putIfAbsent(message.id, () => GlobalKey());

                              Widget bubbleCore = _MessageBubble(
                                key: msgKey,
                                message: message,
                                isMe: isMe,
                                isGrouped: isGrouped,
                                isFirstInGroup: isFirstInGroup,
                                isLastInGroup: isLastInGroup,
                                otherUserLastReadAt: _otherUserLastReadAt,
                                searchQuery: _searchQuery,
                                isHighlighted: _highlightedMessageId == message.id,
                                onReplyTap: (replyId) => _scrollToMessage(replyId),
                                onReply: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _replyingTo = message;
                                  });
                                  _messageFocusNode.requestFocus();
                                },
                                onLongPress: () => _showMessageMenu(message),
                                otherUserAvatarUrl: otherUser?.avatarUrl,
                                otherUserInitials: otherUser?.displayName.isNotEmpty == true
                                    ? otherUser!.displayName[0].toUpperCase()
                                    : '?',
                              );

                              if (message.status == MessageStatus.failed) {
                                bubbleCore = Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                                  children: [
                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          final idx = _optimisticMessages.indexWhere((m) => m.id == message.id);
                                          if (idx != -1) {
                                            _optimisticMessages[idx] = _optimisticMessages[idx].copyWith(status: MessageStatus.sending);
                                          }
                                        });
                                        _sendOptimistic(message);
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 20),
                                      ),
                                    ),
                                    bubbleCore,
                                  ],
                                );
                              } else if (message.status == MessageStatus.sending) {
                                bubbleCore = Opacity(
                                  opacity: 0.6,
                                  child: bubbleCore,
                                );
                              }

                              final bubbleWidget = SwipeToReply(
                                onSwipe: () {
                                  HapticFeedback.lightImpact();
                                  setState(() {
                                    _replyingTo = message;
                                  });
                                  _messageFocusNode.requestFocus();
                                },
                                child: GestureDetector(
                                  onSecondaryTap: () => _showMessageMenu(message),
                                  onDoubleTap: () {
                                    HapticFeedback.lightImpact();
                                    ref.read(chatRepositoryProvider).addReaction(message.id, '❤️');
                                  },
                                  onLongPress: () => _showMessageMenu(message),
                                  child: bubbleCore,
                                ),
                              );

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showDivider)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                                      child: Row(
                                        children: [
                                          const Expanded(child: Divider(color: Colors.blueAccent, thickness: 0.5)),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: Colors.blueAccent.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: const Text(
                                              'Unread Messages',
                                              style: TextStyle(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                          const Expanded(child: Divider(color: Colors.blueAccent, thickness: 0.5)),
                                        ],
                                      ),
                                    ),
                                  bubbleWidget,
                                ],
                              );
                            },
                          ),

                          if (!_isNearBottom)
                            Positioned(
                              bottom: 12,
                              right: 12,
                              child: FloatingActionButton.small(
                                onPressed: _scrollToBottom,
                                elevation: 2,
                                backgroundColor: isLight ? Colors.white : const Color(0xFF262626),
                                foregroundColor: isLight ? Colors.black87 : Colors.white,
                                child: _unreadCount > 0
                                    ? Badge(
                                        label: Text(_unreadCount.toString()),
                                        child: const Icon(Icons.arrow_downward_rounded, size: 18),
                                      )
                                    : const Icon(Icons.arrow_downward_rounded, size: 18),
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    error: (error, stack) => Center(child: Text('Error: $error')),
                  ),
                ),
              ),

              // Bottom entry bar panel
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedSize(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeInOut,
                    child: _replyingTo != null ? _buildReplyPreview() : const SizedBox.shrink(),
                  ),

                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isLight ? Colors.white : Colors.black,
                        border: Border(top: BorderSide(color: isLight ? const Color(0xFFDBDBDB) : const Color(0xFF262626), width: 0.5)),
                      ),
                      child: _isRecording
                          ? Row(
                              children: [
                                const SizedBox(width: 8),
                                const PulsingRecordDot(),
                                const SizedBox(width: 8),
                                Text(
                                  _formatRecordDuration(_recordDuration),
                                  style: TextStyle(
                                    color: isLight ? Colors.black87 : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Recording voice message...',
                                    style: TextStyle(color: isLight ? Colors.black54 : Colors.white70, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                  onPressed: _cancelRecording,
                                ),
                                IconButton(
                                  icon: Icon(Icons.check_circle_rounded, color: isLight ? Colors.green : Colors.greenAccent),
                                  onPressed: _stopAndSendRecording,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                // Attachment picker
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline_rounded, size: 24, color: isLight ? Colors.black87 : Colors.white),
                                  onPressed: _showMediaPicker,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 10),
                                
                                // Pill Container
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isLight ? const Color(0xFFF1F1F4) : const Color(0xFF1C1C1E),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: isLight ? const Color(0xFFDBDBDB) : const Color(0xFF363636),
                                        width: 0.5,
                                      ),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Focus(
                                            onKeyEvent: (node, event) {
                                              if (event is KeyDownEvent &&
                                                  event.logicalKey == LogicalKeyboardKey.enter &&
                                                  !HardwareKeyboard.instance.isShiftPressed) {
                                                if (_messageController.text.trim().isNotEmpty) {
                                                  _sendMessage();
                                                }
                                                _messageFocusNode.requestFocus();
                                                return KeyEventResult.handled;
                                              }
                                              return KeyEventResult.ignored;
                                            },
                                            child: TextField(
                                              focusNode: _messageFocusNode,
                                              controller: _messageController,
                                              style: TextStyle(fontSize: 14, color: isLight ? Colors.black87 : Colors.white),
                                              decoration: InputDecoration(
                                                hintText: 'Message...',
                                                hintStyle: TextStyle(color: isLight ? Colors.black38 : Colors.grey),
                                                border: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                                                filled: false,
                                              ),
                                              maxLines: 5,
                                              minLines: 1,
                                              textCapitalization: TextCapitalization.sentences,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Dynamic Microphone or Send Button
                                AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 150),
                                  child: _isTextEmpty
                                      ? IconButton(
                                          key: const ValueKey('mic_btn'),
                                          icon: Icon(Icons.mic_none_outlined, size: 24, color: isLight ? Colors.black87 : Colors.white),
                                          onPressed: _startRecording,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                        )
                                      : TextButton(
                                          key: const ValueKey('send_btn'),
                                          onPressed: _sendMessage,
                                          child: Text(
                                            'Send',
                                            style: TextStyle(
                                              color: isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.light ? Colors.white : const Color(0xFF262626),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Photo Library'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takeAndSendPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_outlined),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage() async {
    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final file = await mediaRepo.pickImage();
      if (file == null) return;
      await _uploadAndSendMedia(file, 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send image.')));
      }
    }
  }

  Future<void> _takeAndSendPhoto() async {
    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final file = await mediaRepo.takePhoto();
      if (file == null) return;
      await _uploadAndSendMedia(file, 'image');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not take photo.')));
      }
    }
  }

  Future<void> _pickAndSendVideo() async {
    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final file = await mediaRepo.pickVideo();
      if (file == null) return;
      await _uploadAndSendMedia(file, 'video');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send video.')));
      }
    }
  }

  Future<void> _pickAndSendFile() async {
    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final file = await mediaRepo.pickFile();
      if (file == null) return;
      await _uploadAndSendMedia(file, 'file');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send file.')));
      }
    }
  }

  Future<void> _uploadAndSendMedia(XFile file, String fileType, {String? messageType}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading media...'), duration: Duration(seconds: 4)),
      );
    }
    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final result = await mediaRepo.uploadMedia(file: file, fileType: fileType);

      final chatRepo = ref.read(chatRepositoryProvider);
      await chatRepo.sendMediaMessage(
        receiverId: widget.otherUserId,
        messageType: messageType ?? fileType,
        mediaUrl: result['url']!,
        mediaThumbnail: result['thumbnail'],
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload failed.')));
      }
    }
  }

  Widget _buildTypingBubble(BuildContext context, UserProfile? otherUser) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
              backgroundImage: otherUser?.avatarUrl != null ? NetworkImage(otherUser!.avatarUrl!) : null,
              child: otherUser?.avatarUrl == null
                  ? Text(
                      otherUser?.displayName.isNotEmpty == true ? otherUser!.displayName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isLight ? const Color(0xFFF1F1F4) : const Color(0xFF262626),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: const BouncingDotsIndicator(),
            ),
          ],
        ),
      ),
    );
  }

  Decoration _getPresetDecoration(String path) {
    if (path == 'preset_emerald') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF030805), Color(0xFF003819), Color(0xFF0F1712)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (path == 'preset_crimson') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E0008), Color(0xFF160D0E), Color(0xFF4A0010)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (path == 'preset_amoled') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF05191C), Color(0xFF000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (path == 'preset_sunset') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF3553C), Color(0xFFF07E33), Color(0xFFC13584)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (path == 'preset_cyberpunk') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1D092A), Color(0xFF08020F), Color(0xFF1B0326)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else if (path == 'preset_cosmic_dark') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0B0D1B), Color(0xFF030408), Color(0xFF110E1C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    } else if (path == 'preset_glassmorphism') {
      return const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1F1F2E), Color(0xFF13131A), Color(0xFF1E1E2C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      );
    } else {
      ImageProvider imageProvider;
      if (path.startsWith('http://') || path.startsWith('https://')) {
        imageProvider = CachedNetworkImageProvider(path);
      } else {
        imageProvider = pf.getWallpaperImageProvider(path);
      }
      return BoxDecoration(
        image: DecorationImage(
          image: imageProvider,
          fit: BoxFit.cover,
        ),
      );
    }
  }
}

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;

  const SwipeToReply({required this.child, required this.onSwipe, super.key});

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> {
  double _dragOffset = 0.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (details.delta.dx > 0) {
          setState(() {
            _dragOffset += details.delta.dx;
            if (_dragOffset > 50.0) _dragOffset = 50.0;
          });
        } else if (details.delta.dx < 0 && _dragOffset > 0) {
          setState(() {
            _dragOffset += details.delta.dx;
            if (_dragOffset < 0) _dragOffset = 0.0;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset >= 35.0) {
          widget.onSwipe();
        }
        setState(() {
          _dragOffset = 0.0;
        });
      },
      child: Transform.translate(
        offset: Offset(_dragOffset, 0),
        child: Row(
          children: [
            if (_dragOffset > 0)
              Opacity(
                opacity: _dragOffset / 50.0,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8.0, left: 4.0),
                  child: Icon(Icons.reply_rounded, color: Colors.blueAccent, size: 20),
                ),
              ),
            Expanded(child: widget.child),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.isGrouped,
    required this.isFirstInGroup,
    required this.isLastInGroup,
    this.otherUserLastReadAt,
    this.searchQuery,
    required this.isHighlighted,
    required this.onReplyTap,
    this.onReply,
    this.onLongPress,
    this.otherUserAvatarUrl,
    required this.otherUserInitials,
    super.key,
  });

  final Message message;
  final bool isMe;
  final bool isGrouped;
  final bool isFirstInGroup;
  final bool isLastInGroup;
  final DateTime? otherUserLastReadAt;
  final String? searchQuery;
  final bool isHighlighted;
  final ValueChanged<String> onReplyTap;
  final VoidCallback? onReply;
  final VoidCallback? onLongPress;
  final String? otherUserAvatarUrl;
  final String otherUserInitials;

  Widget _buildSongCard(BuildContext context, WidgetRef ref) {
    final parts = message.content.split('|');
    final title = parts[0];
    final artist = parts.length > 1 ? parts[1] : 'Unknown';

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.music_note_rounded, color: Colors.white70),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                ),
                Text(
                  artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, WidgetRef ref) {
    final roomName = message.content;
    final roomId = message.mediaUrl ?? '';

    return Container(
      width: 200,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF7C3AED).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.groups_rounded, color: Color(0xFF7C3AED), size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Listening Room Invite',
                      style: TextStyle(fontSize: 10, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
              ),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => RoomDetailPage(roomId: roomId),
                  ),
                );
              },
              child: const Text('Join', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatPartnerId = message.roomId ?? (isMe ? (message.receiverId ?? '') : message.senderId);
    final isRead = (otherUserLastReadAt != null && message.createdAt.isBefore(otherUserLastReadAt!)) ||
        message.readUserIds.contains(chatPartnerId);
    final isLight = Theme.of(context).brightness == Brightness.light;

    if (message.messageType == 'chat_wallpaper') {
      final isReset = message.mediaUrl == 'reset';
      final isPreset = message.mediaUrl?.startsWith('preset_') ?? false;
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isLight ? Colors.black12 : Colors.white12,
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isReset ? Icons.refresh_rounded : Icons.palette_outlined,
                size: 14,
                color: isLight ? Colors.black87 : Colors.white70,
              ),
              const SizedBox(width: 6),
              Text(
                isReset
                    ? '${isMe ? "You" : "Friend"} reset the chat theme'
                    : '${isMe ? "You" : "Friend"} updated the chat ${isPreset ? "theme" : "wallpaper"}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Instagram message bubble radii logic
    BorderRadius borderRadius;
    if (isMe) {
      if (!isGrouped) {
        borderRadius = BorderRadius.circular(18);
      } else if (isFirstInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        );
      } else if (isLastInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        );
      } else {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(4),
        );
      }
    } else {
      if (!isGrouped) {
        borderRadius = BorderRadius.circular(18);
      } else if (isFirstInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(18),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        );
      } else if (isLastInGroup) {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(18),
          bottomRight: Radius.circular(18),
        );
      } else {
        borderRadius = const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(18),
        );
      }
    }

    final activePreset = ref.watch(themeServiceProvider).getChatWallpaperPreset(chatPartnerId);
    final sentBubbleColor = AppTheme.resolveThreadPrimaryColor(threadPreset: activePreset, themeData: Theme.of(context));
    final receivedBubbleColor = isLight ? const Color(0xFFEFEFEF) : const Color(0xFF262626);

    final highlightColor = Colors.amber.withOpacity(0.45);

    Widget bubbleContent = Container(
      margin: EdgeInsets.only(
        bottom: 2,
        top: (isGrouped && !isFirstInGroup) ? 2 : 10,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: isHighlighted
            ? highlightColor
            : (isMe ? sentBubbleColor : receivedBubbleColor),
        borderRadius: borderRadius,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reply preview banner inside bubble
          if (message.replyTo != null)
            GestureDetector(
              onTap: () => onReplyTap(message.replyTo!),
              child: ref.watch(replyMessageProvider(message.replyTo!)).when(
                    data: (replyMsg) {
                      if (replyMsg == null) return const SizedBox.shrink();
                      return Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          replyMsg.content.isNotEmpty ? replyMsg.content : 'Media message',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : (isLight ? Colors.black54 : Colors.grey),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            ),

          if (message.messageType == 'share_song')
            _buildSongCard(context, ref)
          else if (message.messageType == 'share_room')
            _buildRoomCard(context, ref)
          else ...[
            if (message.messageType == 'image' && message.mediaUrl != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(imageUrl: message.mediaUrl!),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Hero(
                    tag: message.mediaUrl!,
                    child: CachedNetworkImage(
                      imageUrl: message.mediaUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        height: 140,
                        color: Colors.grey.withOpacity(0.1),
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        height: 140,
                        color: Colors.grey.withOpacity(0.1),
                        child: const Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
                  ),
                ),
              )
            else if ((message.messageType == 'voice' || message.messageType == 'audio') && message.mediaUrl != null)
              AudioBubblePlayer(audioUrl: message.mediaUrl!)
            else if (message.messageType == 'video' && message.mediaUrl != null)
              _buildVideoBubble(context, message),
            
            if (message.deleted)
              const Text(
                'Message was unsent',
                style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              )
            else if (message.content.isNotEmpty)
              InteractiveMessageText(
                text: message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : (isLight ? Colors.black87 : Colors.white),
                  fontSize: 14.5,
                ),
                isMe: isMe,
                searchQuery: searchQuery,
              ),
          ],
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('HH:mm').format(message.createdAt),
                style: TextStyle(
                  fontSize: 9,
                  color: isMe ? Colors.white60 : Colors.grey,
                ),
              ),
              if (message.edited) ...[
                const SizedBox(width: 4),
                Text(
                  '(edited)',
                  style: TextStyle(
                    fontSize: 9,
                    color: isMe ? Colors.white60 : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (isMe) ...[
                const SizedBox(width: 4),
                if (message.status == MessageStatus.sending)
                  const SizedBox(
                    width: 8,
                    height: 8,
                    child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white60),
                  )
                else if (message.status == MessageStatus.failed)
                  const Icon(Icons.error_outline_rounded, size: 10, color: Colors.redAccent)
                else
                  Icon(
                    isRead ? Icons.done_all_rounded : Icons.done_all_rounded,
                    size: 11,
                    color: isRead 
                        ? (isLight ? const Color(0xFF34B7F1) : const Color(0xFF3797F0))
                        : Colors.grey,
                  ),
              ],
            ],
          ),
        ],
      ),
    );

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar for incoming messages next to the LAST message of consecutive group
              if (!isMe) ...[
                if (isLastInGroup)
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                    backgroundImage: otherUserAvatarUrl != null ? NetworkImage(otherUserAvatarUrl!) : null,
                    child: otherUserAvatarUrl == null
                        ? Text(
                            otherUserInitials,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                          )
                        : null,
                  )
                else
                  const SizedBox(width: 28), // Spacer to offset avatar
                const SizedBox(width: 8),
              ],
              MessageHoverWrapper(
                isMe: isMe,
                textToCopy: message.content,
                onReply: onReply,
                child: GestureDetector(
                  onSecondaryTap: onLongPress,
                  child: bubbleContent,
                ),
              ),
            ],
          ),
          
          // Reactions list
          if (message.reactions.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(
                bottom: 6.0, 
                left: isMe ? 0 : 38, 
                right: isMe ? 12 : 0,
              ),
              child: Wrap(
                spacing: 3,
                children: () {
                  final reactionsList = message.reactions.map((r) => r['emoji'] as String).toList();
                  return reactionsList.toSet().map((emoji) {
                    final count = reactionsList.where((e) => e == emoji).length;
                    return _AnimatedReactionChip(
                      emoji: emoji,
                      count: count,
                      messageId: message.id,
                    );
                  }).toList();
                }(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoBubble(BuildContext context, Message msg) {
    final videoUrl = msg.mediaUrl!;
    final thumbnailUrl = msg.mediaThumbnail;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 140,
              width: 180,
              color: Colors.grey.withOpacity(0.1),
              child: thumbnailUrl != null && thumbnailUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: thumbnailUrl,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (context, url, error) => const Center(
                        child: Icon(Icons.videocam_rounded, size: 32, color: Colors.grey),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.videocam_rounded, size: 32, color: Colors.grey),
                    ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}

class BouncingDotsIndicator extends StatefulWidget {
  const BouncingDotsIndicator({super.key});

  @override
  State<BouncingDotsIndicator> createState() => _BouncingDotsIndicatorState();
}

class _BouncingDotsIndicatorState extends State<BouncingDotsIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) {
      return AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 500),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: -6.0).animate(
        CurvedAnimation(
          parent: controller,
          curve: Curves.easeInOut,
        ),
      );
    }).toList();

    _startAnimations();
  }

  void _startAnimations() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      _controllers[i].repeat(reverse: true);
      await Future.delayed(const Duration(milliseconds: 130));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final dotColor = isLight ? Colors.black38 : Colors.white70;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return AnimatedBuilder(
          animation: _animations[index],
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _animations[index].value),
              child: child,
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _AnimatedReactionChip extends StatefulWidget {
  const _AnimatedReactionChip({
    required this.emoji,
    required this.count,
    required this.messageId,
  });

  final String emoji;
  final int count;
  final String messageId;

  @override
  State<_AnimatedReactionChip> createState() => _AnimatedReactionChipState();
}

class _AnimatedReactionChipState extends State<_AnimatedReactionChip>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scaleAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _AnimatedReactionChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count) {
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Consumer(
        builder: (context, ref, child) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(chatRepositoryProvider).removeReaction(widget.messageId, widget.emoji);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: isLight ? Colors.white : const Color(0xFF1C1C1E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isLight ? Colors.black12 : Colors.white10,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 12)),
                  if (widget.count > 1) ...[
                    const SizedBox(width: 3),
                    Text('${widget.count}', style: TextStyle(fontSize: 10, color: isLight ? Colors.black54 : Colors.grey)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PulsingRecordDot extends StatefulWidget {
  const PulsingRecordDot({super.key});

  @override
  State<PulsingRecordDot> createState() => _PulsingRecordDotState();
}

class _PulsingRecordDotState extends State<PulsingRecordDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _opacityAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacityAnimation,
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

Future<void> _saveFileToDevice({
  required BuildContext context,
  required String url,
  required String defaultPrefix,
  required String extension,
}) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Downloading file...')),
  );

  try {
    final uri = Uri.parse(url);
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to download file');
    }

    final bytes = response.bodyBytes;
    String fileName = '${defaultPrefix}_${DateTime.now().millisecondsSinceEpoch}.$extension';
    if (uri.pathSegments.isNotEmpty) {
      fileName = uri.pathSegments.last;
    }
    if (!fileName.contains('.')) {
      fileName = '$fileName.$extension';
    }

    final savedDirectly = await pf.saveBytesToDownloads(bytes, fileName);
    if (savedDirectly) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved to Downloads: $fileName')),
      );
    } else {
      await pf.shareFile(bytes, fileName);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to save file')),
    );
  }
}

class FullScreenImageViewer extends StatelessWidget {
  final String imageUrl;

  const FullScreenImageViewer({required this.imageUrl, super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download',
            onPressed: () => _saveFileToDevice(
              context: context,
              url: imageUrl,
              defaultPrefix: 'image',
              extension: 'png',
            ),
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          clipBehavior: Clip.none,
          minScale: 0.5,
          maxScale: 4.0,
          child: Hero(
            tag: imageUrl,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.broken_image, color: Colors.white70, size: 40),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class FullScreenVideoPlayer extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideoPlayer({required this.videoUrl, super.key});

  @override
  State<FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}

class _FullScreenVideoPlayerState extends State<FullScreenVideoPlayer> {
  late BetterPlayerController _betterPlayerController;

  @override
  void initState() {
    super.initState();
    BetterPlayerConfiguration betterPlayerConfiguration = const BetterPlayerConfiguration(
      aspectRatio: 16 / 9,
      fit: BoxFit.contain,
      autoPlay: true,
      looping: false,
    );
    BetterPlayerDataSource dataSource = BetterPlayerDataSource(
      BetterPlayerDataSourceType.network,
      widget.videoUrl,
    );
    _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
    _betterPlayerController.setupDataSource(dataSource);
  }

  @override
  void dispose() {
    _betterPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white),
            tooltip: 'Download',
            onPressed: () => _saveFileToDevice(
              context: context,
              url: widget.videoUrl,
              defaultPrefix: 'video',
              extension: 'mp4',
            ),
          ),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: BetterPlayer(controller: _betterPlayerController),
        ),
      ),
    );
  }
}

class AudioBubblePlayer extends StatefulWidget {
  final String audioUrl;

  const AudioBubblePlayer({required this.audioUrl, super.key});

  @override
  State<AudioBubblePlayer> createState() => _AudioBubblePlayerState();
}

class _AudioBubblePlayerState extends State<AudioBubblePlayer> {
  late final AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerStateSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _completionSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    
    _audioPlayer.setSourceUrl(widget.audioUrl).catchError((err) {
      debugPrint('Error setting audio sourceUrl: $err');
    });

    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((newDuration) {
      if (mounted) {
        setState(() {
          _duration = newDuration;
        });
      }
    });

    _positionSubscription = _audioPlayer.onPositionChanged.listen((newPosition) {
      if (mounted) {
        setState(() {
          _position = newPosition;
        });
      }
    });

    _completionSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completionSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        await _audioPlayer.play(UrlSource(widget.audioUrl));
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 8.0),
                    activeTrackColor: Colors.white,
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: progress.clamp(0.0, 1.0),
                    onChanged: (val) async {
                      final targetMs = (val * _duration.inMilliseconds).toInt();
                      await _audioPlayer.seek(Duration(milliseconds: targetMs));
                    },
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 18),
            onPressed: () => _saveFileToDevice(
              context: context,
              url: widget.audioUrl,
              defaultPrefix: 'voice',
              extension: 'mp3',
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

class EmojiTextParser extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double emojiSize;
  final String? searchQuery;

  const EmojiTextParser({
    required this.text,
    required this.style,
    this.emojiSize = 18,
    this.searchQuery,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    List<InlineSpan> parseTextWithHighlight(String chunk) {
      final query = searchQuery;
      if (query == null || query.isEmpty) {
        return [TextSpan(text: chunk, style: style)];
      }

      final List<InlineSpan> resultSpans = [];
      final lowerChunk = chunk.toLowerCase();
      final lowerQuery = query.toLowerCase();
      
      int index = 0;
      while (true) {
        final matchIdx = lowerChunk.indexOf(lowerQuery, index);
        if (matchIdx == -1) {
          resultSpans.add(TextSpan(
            text: chunk.substring(index),
            style: style,
          ));
          break;
        }

        if (matchIdx > index) {
          resultSpans.add(TextSpan(
            text: chunk.substring(index, matchIdx),
            style: style,
          ));
        }

        resultSpans.add(TextSpan(
          text: chunk.substring(matchIdx, matchIdx + query.length),
          style: style.copyWith(
            backgroundColor: Colors.yellow.withOpacity(0.35),
            fontWeight: FontWeight.bold,
          ),
        ));

        index = matchIdx + query.length;
      }
      
      return resultSpans;
    }

    final trimmed = text.trim();
    final matches = emojiRegex.allMatches(trimmed).toList();
    
    int totalEmojiLen = 0;
    for (final match in matches) {
      totalEmojiLen += match.group(0)!.length;
    }
    
    final spaceCount = trimmed.split('').where((char) => RegExp(r'\s').hasMatch(char)).length;
    final isJumbo = matches.isNotEmpty && 
        matches.length <= 3 && 
        (totalEmojiLen + spaceCount >= trimmed.length);

    if (isJumbo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Wrap(
          spacing: 4,
          children: matches.map((match) {
            final emoji = match.group(0)!;
            final url = animatedEmojiMap[emoji]!;
            return Image.network(
              url,
              width: emojiSize * 2.0,
              height: emojiSize * 2.0,
              errorBuilder: (context, error, stackTrace) => Text(
                emoji,
                style: style.copyWith(fontSize: emojiSize * 1.8),
              ),
            );
          }).toList(),
        ),
      );
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.addAll(parseTextWithHighlight(text.substring(lastIndex, match.start)));
      }

      final emoji = match.group(0)!;
      final url = animatedEmojiMap[emoji]!;
      
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1.0),
          child: Image.network(
            url,
            width: emojiSize,
            height: emojiSize,
            errorBuilder: (context, error, stackTrace) => Text(
              emoji,
              style: style.copyWith(fontSize: emojiSize * 0.95),
            ),
          ),
        ),
      ));

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.addAll(parseTextWithHighlight(text.substring(lastIndex)));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: style,
    );
  }
}
