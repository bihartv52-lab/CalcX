import 'dart:async';
import 'package:calcx/app/app_theme.dart';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/services/theme_service.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/media/data/media_repository.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/chat/presentation/chat_page.dart';
import 'package:calcx/features/chat/presentation/widgets/forward_recipient_picker_dialog.dart';
import 'package:calcx/core/widgets/quick_panic_calculator_button.dart';
import 'package:calcx/features/chat/presentation/widgets/interactive_message_text.dart';
import 'package:calcx/features/chat/presentation/widgets/message_hover_copy_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomChatPage extends ConsumerStatefulWidget {
  const RoomChatPage({super.key, required this.roomId, required this.roomName});

  final String roomId;
  final String roomName;

  @override
  ConsumerState<RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends ConsumerState<RoomChatPage> with WidgetsBindingObserver {
  final _messageController = TextEditingController();
  final _messageFocusNode = FocusNode();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final Map<String, String> _profileNames = {};

  bool _isTextEmpty = true;
  bool _lastSentTypingState = false;
  Timer? _typingThrottleTimer;
  Timer? _typingClearTimer;

  bool _isSearching = false;
  String _searchQuery = '';
  List<Message> _searchResults = [];
  int _currentSearchMatchIndex = 0;

  bool _isSelectionMode = false;
  Set<String> _selectedMessageIds = {};

  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;
  List<Message> _allMessages = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    _messageController.addListener(() {
      final text = _messageController.text;
      final isEmpty = text.trim().isEmpty;
      if (isEmpty != _isTextEmpty) {
        setState(() {
          _isTextEmpty = isEmpty;
        });
      }
      _onTextChanged(text);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _messageFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_lastSentTypingState) {
      _lastSentTypingState = false;
      _sendTypingBroadcast(false);
    }
    _typingThrottleTimer?.cancel();
    _typingClearTimer?.cancel();
    _messageController.dispose();
    _messageFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
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

  Future<void> _sendTypingBroadcast(bool isTyping) async {
    if (!mounted) return;
    final myId = ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
    if (myId == null) return;
    
    String myName = 'Someone';
    try {
      final profile = await ref.read(friendsRepositoryProvider).getUserById(myId);
      if (profile != null) {
        myName = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
      }
    } catch (_) {}

    final channel = ref.read(roomTypingSendChannelProvider(widget.roomId));
    if (channel != null) {
      channel.sendBroadcastMessage(
        event: 'typing',
        payload: {
          'senderId': myId,
          'senderName': myName,
          'isTyping': isTyping,
        },
      );
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
      final remoteMatches = await ref.read(chatRepositoryProvider).searchRoomMessages(widget.roomId, trimmed);
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

    final key = _messageKeys[msgId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      final index = _allMessages.indexWhere((m) => m.id == msgId);
      if (index != -1 && _scrollController.hasClients) {
        _scrollController.animateTo(
          index * 85.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _onTextChanged(String val) {
    if (val.isNotEmpty) {
      if (!_lastSentTypingState || _typingThrottleTimer == null) {
        _lastSentTypingState = true;
        _sendTypingBroadcast(true);
        _typingThrottleTimer = Timer(const Duration(seconds: 2), () {
          _typingThrottleTimer = null;
        });
      }
      _typingClearTimer?.cancel();
      _typingClearTimer = Timer(const Duration(milliseconds: 2500), () {
        _lastSentTypingState = false;
        _sendTypingBroadcast(false);
      });
    } else {
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

  Future<String> _getSenderName(String senderId) async {
    if (_profileNames.containsKey(senderId)) {
      return _profileNames[senderId]!;
    }

    try {
      final repo = ref.read(friendsRepositoryProvider);
      final profile = await repo.getUserById(senderId);
      if (profile != null) {
        final name = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
        if (mounted) {
          setState(() {
            _profileNames[senderId] = name;
          });
        }
        return name;
      }
    } catch (_) {}

    return senderId.substring(0, 8);
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
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
    
    _typingThrottleTimer?.cancel();
    _typingThrottleTimer = null;
    _typingClearTimer?.cancel();
    _typingClearTimer = null;
    if (_lastSentTypingState) {
      _lastSentTypingState = false;
      _sendTypingBroadcast(false);
    }

    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMessage(
        receiverId: null,
        content: content,
        roomId: widget.roomId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message could not be sent. Please try again.')),
        );
      }
    }
  }

  Future<void> _sendImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...'), duration: Duration(seconds: 4)),
      );

      final mediaRepo = ref.read(mediaRepositoryProvider);
      final uploadResult = await mediaRepo.uploadMedia(
        file: image,
        fileType: 'image',
      );

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMediaMessage(
        receiverId: null,
        messageType: 'image',
        mediaUrl: uploadResult['url']!,
        mediaThumbnail: uploadResult['thumbnail'],
        content: '📷 Image',
        roomId: widget.roomId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send image. Please try again.')),
        );
      }
    }
  }

  Future<void> _sendVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading video...'), duration: Duration(seconds: 4)),
      );

      final mediaRepo = ref.read(mediaRepositoryProvider);
      final uploadResult = await mediaRepo.uploadMedia(
        file: video,
        fileType: 'video',
      );

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMediaMessage(
        receiverId: null,
        messageType: 'video',
        mediaUrl: uploadResult['url']!,
        mediaThumbnail: uploadResult['thumbnail'],
        content: '🎥 Video',
        roomId: widget.roomId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send video. Please try again.')),
        );
      }
    }
  }

  Future<void> _sendFile() async {
    try {
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final file = await mediaRepo.pickFile();
      if (file == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading file...'), duration: Duration(seconds: 4)),
      );

      final uploadResult = await mediaRepo.uploadMedia(
        file: file,
        fileType: 'file',
      );

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMediaMessage(
        receiverId: null,
        messageType: 'file',
        mediaUrl: uploadResult['url']!,
        content: '📎 ${file.name}',
        roomId: widget.roomId,
      );
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not send file. Please try again.')),
        );
      }
    }
  }

  void _showMediaOptions() {
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
              leading: const Icon(Icons.image_rounded),
              title: const Text('Send Image'),
              onTap: () {
                Navigator.pop(context);
                _sendImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam_rounded),
              title: const Text('Send Video'),
              onTap: () {
                Navigator.pop(context);
                _sendVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file_rounded),
              title: const Text('Send File'),
              onTap: () {
                Navigator.pop(context);
                _sendFile();
              },
            ),
          ],
        ),
      ),
    );
  }

  String _getRoomTypingText(Map<String, String> typingUsers) {
    if (typingUsers.isEmpty) return '';
    final names = typingUsers.values.where((n) => n.isNotEmpty).toSet().toList();
    if (names.isEmpty) return '';
    if (names.length == 1) {
      return '${names[0]} is typing...';
    } else if (names.length == 2) {
      return '${names[0]} and ${names[1]} are typing...';
    } else {
      return '${names[0]}, ${names[1]} and ${names.length - 2} others are typing...';
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref.watch(chatRepositoryProvider).watchRoomMessages(widget.roomId);
    final roomTypingMap = ref.watch(roomTypingStatesProvider(widget.roomId)).value ?? {};
    final typingText = _getRoomTypingText(roomTypingMap);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final activePreset = ref.watch(themeServiceProvider).getChatWallpaperPreset(widget.roomId);
    final sentBubbleColor = AppTheme.resolveThreadPrimaryColor(threadPreset: activePreset, themeData: Theme.of(context));
    final receivedBubbleColor = isLight ? const Color(0xFFEFEFEF) : const Color(0xFF262626);

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
              title: _isSearching
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            style: TextStyle(color: isLight ? Colors.black87 : Colors.white, fontSize: 15),
                            decoration: const InputDecoration(
                              hintText: 'Search room history...',
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
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.roomName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isLight ? Colors.black87 : Colors.white,
                          ),
                        ),
                        const Text(
                          'Room Chat',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.normal),
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
                ],
              ],
            ),
      body: Column(
        children: [
          Expanded(
            child: SelectionArea(
              child: StreamBuilder<List<Message>>(
                stream: messagesStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                  }

                  final messages = snapshot.data ?? [];
                  final reversedMessages = messages.reversed.toList();
                  _allMessages = reversedMessages;

                  if (reversedMessages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 56,
                            color: Colors.grey.withOpacity(0.5),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No messages yet',
                            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Start the conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(16),
                    itemCount: reversedMessages.length,
                    itemBuilder: (context, index) {
                      final message = reversedMessages[index];
                      final isMe = message.senderId == ref.read(chatRepositoryProvider).supabase?.auth.currentUser?.id;
                      final msgKey = _messageKeys.putIfAbsent(message.id, () => GlobalKey());
                      final isHighlighted = _highlightedMessageId == message.id;
                      final isSelected = _selectedMessageIds.contains(message.id);

                      return Padding(
                        key: msgKey,
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: GestureDetector(
                          onTap: _isSelectionMode
                              ? () {
                                  setState(() {
                                    if (_selectedMessageIds.contains(message.id)) {
                                      _selectedMessageIds.remove(message.id);
                                      if (_selectedMessageIds.isEmpty) {
                                        _isSelectionMode = false;
                                      }
                                    } else {
                                      _selectedMessageIds.add(message.id);
                                    }
                                  });
                                }
                              : null,
                          onLongPress: () {
                            HapticFeedback.mediumImpact();
                            setState(() {
                              _isSelectionMode = true;
                              _selectedMessageIds.add(message.id);
                            });
                          },
                          child: Row(
                            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (_isSelectionMode)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Icon(
                                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                    color: sentBubbleColor,
                                    size: 20,
                                  ),
                                ),
                              if (!isMe) ...[
                                FutureBuilder<String>(
                                  future: _getSenderName(message.senderId),
                                  builder: (context, snapshot) {
                                    final name = snapshot.data ?? '?';
                                    return CircleAvatar(
                                      radius: 14,
                                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                              Flexible(
                                child: MessageHoverWrapper(
                                  isMe: isMe,
                                  textToCopy: message.content,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isHighlighted
                                          ? Colors.amber.withOpacity(0.45)
                                          : (isMe ? sentBubbleColor : receivedBubbleColor),
                                      borderRadius: BorderRadius.only(
                                        topLeft: const Radius.circular(16),
                                        topRight: const Radius.circular(16),
                                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                                        bottomRight: Radius.circular(isMe ? 4 : 16),
                                      ),
                                      border: isHighlighted
                                          ? Border.all(color: Colors.amber, width: 1.5)
                                          : null,
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!isMe)
                                          FutureBuilder<String>(
                                            future: _getSenderName(message.senderId),
                                            builder: (context, snapshot) {
                                              final name = snapshot.data ?? '';
                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 3.0),
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    color: isLight ? Colors.black54 : Colors.grey,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        if (message.messageType == 'image')
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(8),
                                              child: Image.network(
                                                message.mediaUrl ?? '',
                                                fit: BoxFit.cover,
                                                height: 140,
                                                width: 180,
                                                errorBuilder: (c, e, s) => const Icon(Icons.broken_image_rounded),
                                              ),
                                            ),
                                          )
                                        else if (message.messageType == 'video')
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Container(
                                              height: 140,
                                              width: 180,
                                              color: Colors.black26,
                                              child: const Icon(Icons.play_circle_fill_rounded, size: 36, color: Colors.white70),
                                            ),
                                          )
                                        else if (message.messageType == 'file')
                                          Padding(
                                            padding: const EdgeInsets.only(bottom: 4.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.attach_file_rounded, size: 16),
                                                const SizedBox(width: 4),
                                                Text(
                                                  message.content.split(' ').last,
                                                  style: const TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                                                ),
                                              ],
                                            ),
                                          ),
                                        if (message.content.isNotEmpty && message.messageType == 'text')
                                          InteractiveMessageText(
                                            text: message.content,
                                            isMe: isMe,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isMe ? Colors.white : (isLight ? Colors.black87 : Colors.white),
                                            ),
                                            searchQuery: _searchQuery,
                                          ),
                                        const SizedBox(height: 2),
                                        Text(
                                          DateFormat('HH:mm').format(message.createdAt),
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: isMe ? Colors.white60 : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          if (typingText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    typingText,
                    style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isLight ? Colors.white : Colors.black,
              border: Border(
                top: BorderSide(color: isLight ? const Color(0xFFDBDBDB) : const Color(0xFF262626), width: 0.5),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _showMediaOptions,
                  icon: Icon(Icons.add_circle_outline_rounded, size: 24, color: isLight ? Colors.black87 : Colors.white),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 10),
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
                        autofocus: true,
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
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: _isTextEmpty
                      ? const SizedBox.shrink()
                      : TextButton(
                          onPressed: _sendMessage,
                          child: Text(
                            'Send',
                            style: TextStyle(
                              color: sentBubbleColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
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
