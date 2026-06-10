import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/media/data/media_repository.dart';
import 'package:calcx/core/services/theme_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/chat/presentation/chat_list_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:better_player_plus/better_player_plus.dart';

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
  
  // Kiss Emojis
  '😘': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20Blowing%20A%20Kiss.webp',
  '💋': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Kiss%20Mark.webp',
  '😚': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Kissing%20Face%20With%20Closed%20Eyes.webp',
  '😗': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Kissing%20Face.webp',
  
  // Heart Variations
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

final _emojiRegex = emojiRegex;
final _animatedEmojiMap = animatedEmojiMap;


final chatMessagesProvider = StreamProvider.family<List<Message>, String>((
  ref,
  userId,
) {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.watchDirectMessages(userId);
});

final otherUserProfileProvider = StreamProvider.family<UserProfile?, String>((
  ref,
  userId,
) {
  final client = SupabaseService.clientOrNull;
  if (client == null) return const Stream.empty();
  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) => data.isNotEmpty ? UserProfile.fromMap(data.first) : null);
});

// Realtime Stream for Message Reactions
final messageReactionsProvider = StreamProvider.family<List<String>, String>((ref, messageId) {
  final client = SupabaseService.clientOrNull;
  if (client == null) return const Stream.empty();
  return client
      .from('message_reactions')
      .stream(primaryKey: ['id'])
      .eq('message_id', messageId)
      .map((data) => data.map((json) => json['emoji'] as String).toList());
});

// Realtime Stream for Message Read Receipts
final messageReadStatusProvider = StreamProvider.family<bool, String>((ref, messageId) {
  final client = SupabaseService.clientOrNull;
  if (client == null) return const Stream.empty();
  return client
      .from('message_reads')
      .stream(primaryKey: ['id'])
      .eq('message_id', messageId)
      .map((data) => data.isNotEmpty);
});

// Future to fetch message details for replies
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

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  UserProfile? _otherUser;
  Message? _replyingTo;
  
  bool _isNearBottom = true;
  bool _showNewMessagesBanner = false;
  int _unreadCount = 0;

  Timer? _typingThrottleTimer;
  Timer? _typingClearTimer;

  bool _isTextEmpty = true;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  late final AudioRecorder _audioRecorder;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _loadOtherUser();
    _scrollController.addListener(_scrollListener);
    _messageController.addListener(() {
      final isEmpty = _messageController.text.trim().isEmpty;
      if (isEmpty != _isTextEmpty) {
        setState(() {
          _isTextEmpty = isEmpty;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatRepositoryProvider).markAllAsRead(widget.otherUserId);
      ref.invalidate(recentChatsProvider);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingThrottleTimer?.cancel();
    _typingClearTimer?.cancel();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    _setTyping(false);
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: path,
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
        final file = File(path);
        if (await file.exists()) {
          await _uploadAndSendMedia(file, 'audio', messageType: 'voice');
        }
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
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      setState(() {
        _showNewMessagesBanner = false;
        _unreadCount = 0;
      });
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

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    _messageController.clear();
    _typingThrottleTimer?.cancel();
    _typingThrottleTimer = null;
    _typingClearTimer?.cancel();
    _typingClearTimer = null;
    _setTyping(false);

    final replyId = _replyingTo?.id;
    setState(() {
      _replyingTo = null;
    });

    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMessage(
        receiverId: widget.otherUserId,
        content: content,
        replyTo: replyId,
      );

      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  void _setTyping(bool isTyping) {
    final repository = ref.read(chatRepositoryProvider);
    repository.setTyping(
      chatWithUserId: widget.otherUserId,
      isTyping: isTyping,
    );
  }

  void _showMessageMenu(Message message) {
    final myId = ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
    final isMyMsg = message.senderId == myId;

    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.85),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: SafeArea(
            child: Wrap(
              children: [
                // Quick emoji reactions
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: ['❤️', '👍', '😂', '😮', '😢', '🙏'].map((emoji) {
                      return GestureDetector(
                        onTap: () {
                          ref.read(chatRepositoryProvider).addReaction(message.id, emoji);
                          Navigator.pop(context);
                        },
                        child: ScaleTransition(
                          scale: const AlwaysStoppedAnimation(1.1),
                          child: _animatedEmojiMap.containsKey(emoji)
                              ? Image.network(
                                  _animatedEmojiMap[emoji]!,
                                  width: 32,
                                  height: 32,
                                  errorBuilder: (c, e, s) => Text(emoji, style: const TextStyle(fontSize: 30)),
                                )
                              : Text(emoji, style: const TextStyle(fontSize: 30)),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const Divider(color: Colors.white10),
                ListTile(
                  leading: const Icon(Icons.reply_rounded, color: Colors.blue),
                  title: const Text('Reply', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _replyingTo = message;
                    });
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded, color: Colors.white70),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.content));
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
                if (isMyMsg) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.redAccent),
                    title: const Text('Delete for Everyone', style: TextStyle(color: Colors.redAccent)),
                    onTap: () {
                      ref.read(chatRepositoryProvider).deleteMessage(message.id);
                      Navigator.pop(context);
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview() {
    if (_replyingTo == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply_rounded, color: Colors.blue, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Replying to message',
                  style: TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
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

    // Watch messaging stream and scroll smart
    ref.listen(chatMessagesProvider(widget.otherUserId), (prev, next) {
      final messages = next.value ?? [];
      final prevCount = prev?.value?.length ?? 0;
      
      // Mark as read whenever the messages stream emits
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

    final wallpaperPath = themeSettings.chatWallpapers[widget.otherUserId] ?? themeSettings.globalWallpaperPath;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(otherUser?.displayName ?? 'Chat'),
            if (otherUser != null)
              Text(
                isTypingAsync.maybeWhen(
                  data: (isTyping) => isTyping ? 'typing...' : otherUser.getPresenceText(),
                  orElse: () => otherUser.getPresenceText(),
                ),
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () async {
              if (_otherUser == null) return;
              try {
                final newCall = await ref.read(callRepositoryProvider).initiateCall(
                  receiverId: _otherUser!.id,
                  callType: 'audio',
                );
                if (context.mounted) {
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
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () async {
              if (_otherUser == null) return;
              try {
                final newCall = await ref.read(callRepositoryProvider).initiateCall(
                  receiverId: _otherUser!.id,
                  callType: 'video',
                );
                if (context.mounted) {
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
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (val) async {
              if (val == 'wallpaper') {
                try {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked == null) return;
                  await ref.read(themeServiceProvider.notifier).setChatWallpaper(
                        widget.otherUserId,
                        File(picked.path),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Chat wallpaper updated!')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              } else if (val == 'pikachu') {
                await ref.read(themeServiceProvider.notifier).setChatWallpaperPreset(
                      widget.otherUserId,
                      'pikachu',
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Pikachu wallpaper set!')),
                  );
                }
              } else if (val == 'spiderman') {
                await ref.read(themeServiceProvider.notifier).setChatWallpaperPreset(
                      widget.otherUserId,
                      'spiderman',
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Spider-Man wallpaper set!')),
                  );
                }
              } else if (val == 'cherries') {
                await ref.read(themeServiceProvider.notifier).setChatWallpaperPreset(
                      widget.otherUserId,
                      'cherries',
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Cherries wallpaper set!')),
                  );
                }
              } else if (val == 'zenitsu') {
                await ref.read(themeServiceProvider.notifier).setChatWallpaperPreset(
                      widget.otherUserId,
                      'zenitsu',
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Zenitsu wallpaper set!')),
                  );
                }
              } else if (val == 'reset_wallpaper') {
                await ref.read(themeServiceProvider.notifier).removeChatWallpaper(widget.otherUserId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Chat wallpaper reset to global!')),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'wallpaper',
                child: Row(
                  children: [
                    Icon(Icons.wallpaper_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Custom Wallpaper'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'pikachu',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: Colors.yellow),
                    SizedBox(width: 8),
                    Text('Pikachu Wallpaper'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'spiderman',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Spider-Man Wallpaper'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'cherries',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: Colors.pink),
                    SizedBox(width: 8),
                    Text('Cherries Wallpaper'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'zenitsu',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 20, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Zenitsu Wallpaper'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reset_wallpaper',
                child: Row(
                  children: [
                    Icon(Icons.layers_clear_rounded, size: 20),
                    SizedBox(width: 8),
                    Text('Reset Wallpaper'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          // Background custom wallpaper layer
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
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: wallpaperPath == 'pikachu'
                            ? const AssetImage('assets/images/pikachu_wallpaper.jpg') as ImageProvider
                            : wallpaperPath == 'spiderman'
                                ? const AssetImage('assets/images/spiderman_wallpaper.jpg') as ImageProvider
                                : wallpaperPath == 'cherries'
                                    ? const AssetImage('assets/images/cherries_wallpaper.jpg') as ImageProvider
                                    : wallpaperPath == 'zenitsu'
                                        ? const AssetImage('assets/images/zenitsu_wallpaper.jpg') as ImageProvider
                                        : FileImage(File(wallpaperPath)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      color: Colors.black.withOpacity(themeSettings.wallpaperDim),
                    ),
                  ),
                ),
              ),
            ),
          
          Column(
            children: [
              // Messages Scroll View
              Expanded(
                child: messagesAsync.when(
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(child: Text('No messages yet. Say hi!'));
                    }

                    return Stack(
                      children: [
                        ListView.builder(
                          controller: _scrollController,
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          reverse: true,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: messages.length + (isTypingAsync.value == true ? 1 : 0),
                          itemBuilder: (context, index) {
                            final hasTyping = isTypingAsync.value == true;
                            if (hasTyping && index == 0) {
                              return _buildTypingBubble(context);
                            }

                            final messageIndex = hasTyping ? index - 1 : index;
                            final message = messages[messageIndex];
                            final isMe = message.senderId != widget.otherUserId;

                            // Grouping logic: consecutive messages from same sender within 2 mins
                            final bool isSameSenderAsPrevious = messageIndex < messages.length - 1 &&
                                messages[messageIndex + 1].senderId == message.senderId;
                            final bool isTimeClose = messageIndex < messages.length - 1 &&
                                message.createdAt.difference(messages[messageIndex + 1].createdAt).inMinutes.abs() < 2;
                            final bool isGrouped = isSameSenderAsPrevious && isTimeClose;

                            // Insert Unread message divider if needed
                            final showDivider = _showNewMessagesBanner && 
                                messageIndex == (_unreadCount - 1);

                            final bubbleWidget = SwipeToReply(
                              onSwipe: () {
                                HapticFeedback.lightImpact();
                                setState(() {
                                  _replyingTo = message;
                                });
                              },
                              child: GestureDetector(
                                onDoubleTap: () {
                                  HapticFeedback.lightImpact();
                                  ref.read(chatRepositoryProvider).addReaction(message.id, '❤️');
                                },
                                onLongPress: () => _showMessageMenu(message),
                                child: _MessageBubble(message: message, isMe: isMe, isGrouped: isGrouped),
                              ),
                            );

                            // Micro-animation wrapper
                            final animatedBubble = TweenAnimationBuilder<double>(
                              key: ValueKey(message.id),
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 260),
                              curve: Curves.easeOutQuad,
                              builder: (context, val, child) {
                                return Transform.translate(
                                  offset: Offset(0, 20 * (1.0 - val)),
                                  child: Opacity(opacity: val, child: child),
                                );
                              },
                              child: bubbleWidget,
                            );

                            if (showDivider) {
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                                    child: Row(
                                      children: [
                                        const Expanded(child: Divider(color: Colors.blueAccent, thickness: 1)),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blueAccent.withOpacity(0.25),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Unread Messages',
                                            style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const Expanded(child: Divider(color: Colors.blueAccent, thickness: 1)),
                                      ],
                                    ),
                                  ),
                                  animatedBubble,
                                ],
                              );
                            }

                            return animatedBubble;
                          },
                        ),

                        // Jump to latest floating button
                        if (!_isNearBottom)
                          Positioned(
                            bottom: 16,
                            right: 16,
                            child: FloatingActionButton.small(
                              onPressed: _scrollToBottom,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              child: _unreadCount > 0
                                  ? Badge(
                                      label: Text(_unreadCount.toString()),
                                      child: const Icon(Icons.arrow_downward_rounded),
                                    )
                                  : const Icon(Icons.arrow_downward_rounded),
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (error, stack) =>
                      Center(child: Text('Error loading messages: $error')),
                ),
              ),

              const SizedBox.shrink(),

              // Bottom entry bar panel
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Reply Preview area
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: _replyingTo != null ? _buildReplyPreview() : const SizedBox.shrink(),
                  ),

                  // Standard text bar
                  SafeArea(
                    top: false,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor.withOpacity(0.95),
                        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.06))),
                      ),
                      child: _isRecording
                          ? Row(
                              children: [
                                const SizedBox(width: 8),
                                const PulsingRecordDot(),
                                const SizedBox(width: 8),
                                Text(
                                  _formatRecordDuration(_recordDuration),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Recording audio...',
                                    style: TextStyle(color: Colors.white70, fontSize: 13),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_rounded, color: Colors.redAccent),
                                  onPressed: _cancelRecording,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.check_circle_rounded, color: Colors.greenAccent),
                                  onPressed: _stopAndSendRecording,
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_rounded),
                                  onPressed: () {
                                    _showMediaPicker();
                                  },
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _messageController,
                                    style: const TextStyle(fontSize: 15),
                                    decoration: const InputDecoration(
                                      hintText: 'Type a message...',
                                      border: InputBorder.none,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                                    ),
                                    maxLines: null,
                                    textCapitalization: TextCapitalization.sentences,
                                    onChanged: (value) {
                                      if (value.isNotEmpty) {
                                        if (_typingThrottleTimer == null) {
                                          _setTyping(true);
                                          _typingThrottleTimer = Timer(const Duration(seconds: 3), () {
                                            _typingThrottleTimer = null;
                                          });
                                        }
                                        _typingClearTimer?.cancel();
                                        _typingClearTimer = Timer(const Duration(seconds: 5), () {
                                          _setTyping(false);
                                        });
                                      } else {
                                        _typingThrottleTimer?.cancel();
                                        _typingThrottleTimer = null;
                                        _typingClearTimer?.cancel();
                                        _typingClearTimer = null;
                                        _setTyping(false);
                                      }
                                    },
                                  ),
                                ),
                                if (_isTextEmpty)
                                  IconButton(
                                    icon: const Icon(Icons.mic_rounded, color: Colors.blueAccent),
                                    onPressed: _startRecording,
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                                    onPressed: _sendMessage,
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
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _takeAndSendPhoto();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _uploadAndSendMedia(File file, String fileType, {String? messageType}) async {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading media...'), duration: Duration(seconds: 5)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Widget _buildTypingBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: const BouncingDotsIndicator(),
      ),
    );
  }
}

// Custom Horizontal Swipe detector for reply actions
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
            if (_dragOffset > 70.0) _dragOffset = 70.0;
          });
        } else if (details.delta.dx < 0 && _dragOffset > 0) {
          setState(() {
            _dragOffset += details.delta.dx;
            if (_dragOffset < 0) _dragOffset = 0.0;
          });
        }
      },
      onHorizontalDragEnd: (details) {
        if (_dragOffset >= 45.0) {
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
                opacity: _dragOffset / 70.0,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8.0),
                  child: Icon(Icons.reply_rounded, color: Colors.blueAccent),
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
  });

  final Message message;
  final bool isMe;
  final bool isGrouped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reactionsAsync = ref.watch(messageReactionsProvider(message.id));

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Reply preview indicator inside bubble
          if (message.replyTo != null)
            ref.watch(replyMessageProvider(message.replyTo!)).when(
                  data: (replyMsg) {
                    if (replyMsg == null) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(left: 12, right: 12, top: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        replyMsg.content,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),

          Container(
            margin: EdgeInsets.only(
              bottom: 2,
              top: isGrouped ? 2 : 10,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.72,
            ),
            decoration: BoxDecoration(
              color: isMe 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.85) 
                  : Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      borderRadius: BorderRadius.circular(8),
                      child: Hero(
                        tag: message.mediaUrl!,
                        child: Image.network(
                          message.mediaUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 150,
                              color: Colors.white.withOpacity(0.08),
                              child: const Center(child: Icon(Icons.broken_image_rounded)),
                            );
                          },
                        ),
                      ),
                    ),
                  )
                else if ((message.messageType == 'voice' || message.messageType == 'audio') && message.mediaUrl != null)
                  AudioBubblePlayer(audioUrl: message.mediaUrl!)
                else if (message.messageType == 'video' && message.mediaUrl != null)
                  _buildVideoBubble(context, message.mediaUrl!),
                if (message.deleted)
                  const Text(
                    'This message was deleted',
                    style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                  )
                else if (message.content.isNotEmpty)
                  EmojiTextParser(
                    text: message.content,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.6)),
                    ),
                    if (message.edited) ...[
                      const SizedBox(width: 4),
                      Text(
                        '(edited)',
                        style: TextStyle(fontSize: 9, color: Colors.white.withOpacity(0.6), fontStyle: FontStyle.italic),
                      ),
                    ],
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      ref.watch(messageReadStatusProvider(message.id)).when(
                            data: (isRead) => Icon(
                              isRead ? Icons.done_all_rounded : Icons.check_rounded,
                              size: 13,
                              color: isRead ? const Color(0xFF34B7F1) : Colors.white60,
                            ),
                            loading: () => const Icon(Icons.check_rounded, size: 13, color: Colors.white60),
                            error: (_, __) => const Icon(Icons.check_rounded, size: 13, color: Colors.white60),
                          ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Render reactions list
          reactionsAsync.when(
            data: (reactions) {
              if (reactions.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0, left: 12, right: 12),
                child: Wrap(
                  spacing: 4,
                  children: reactions.toSet().map((emoji) {
                    final count = reactions.where((e) => e == emoji).length;
                    return _AnimatedReactionChip(
                      emoji: emoji,
                      count: count,
                      messageId: message.id,
                    );
                  }).toList(),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBubble(BuildContext context, String videoUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FullScreenVideoPlayer(videoUrl: videoUrl),
          ),
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: 150,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.videocam_rounded, size: 40, color: Colors.white60),
            ),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.55),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
          ),
        ],
      ),
    );
  }
}

// Bouncing Dots Typing Indicator
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
        duration: const Duration(milliseconds: 600),
      );
    });

    _animations = _controllers.map((controller) {
      return Tween<double>(begin: 0.0, end: -8.0).animate(
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
      await Future.delayed(const Duration(milliseconds: 150));
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
    final colors = Theme.of(context).colorScheme;
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
            padding: const EdgeInsets.symmetric(horizontal: 3.0),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: colors.primary.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// Animated reaction chip with elastic pop-in on change
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
      duration: const Duration(milliseconds: 400),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_animatedEmojiMap.containsKey(widget.emoji))
                    Image.network(
                      _animatedEmojiMap[widget.emoji]!,
                      width: 20,
                      height: 20,
                      errorBuilder: (c, e, s) => Text(widget.emoji, style: const TextStyle(fontSize: 12)),
                    )
                  else
                    Text(widget.emoji, style: const TextStyle(fontSize: 12)),
                  if (widget.count > 1) ...[
                    const SizedBox(width: 4),
                    Text('${widget.count}', style: const TextStyle(fontSize: 11, color: Colors.white70)),
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

// -------------------------------------------------------------
// NEW CHAT EXTENSION WIDGETS
// -------------------------------------------------------------

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
      duration: const Duration(milliseconds: 800),
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
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.redAccent,
          shape: BoxShape.circle,
        ),
      ),
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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
                  child: Icon(Icons.broken_image, color: Colors.white, size: 50),
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
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
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

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final double progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      width: 240,
      child: Row(
        children: [
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white,
                size: 24,
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
                    trackHeight: 3.0,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

  const EmojiTextParser({
    required this.text,
    required this.style,
    this.emojiSize = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final trimmed = text.trim();
    final matches = _emojiRegex.allMatches(trimmed).toList();
    
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
          spacing: 6,
          children: matches.map((match) {
            final emoji = match.group(0)!;
            final url = _animatedEmojiMap[emoji]!;
            return Image.network(
              url,
              width: emojiSize * 2.2,
              height: emojiSize * 2.2,
              errorBuilder: (context, error, stackTrace) => Text(
                emoji,
                style: style.copyWith(fontSize: emojiSize * 2.0),
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
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: style,
        ));
      }

      final emoji = match.group(0)!;
      final url = _animatedEmojiMap[emoji]!;
      
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
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
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: style,
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
    );
  }
}

