import 'dart:io';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/media/data/media_repository.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';

class RoomChatPage extends ConsumerStatefulWidget {
  const RoomChatPage({super.key, required this.roomId, required this.roomName});

  final String roomId;
  final String roomName;

  @override
  ConsumerState<RoomChatPage> createState() => _RoomChatPageState();
}

class _RoomChatPageState extends ConsumerState<RoomChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final Map<String, String> _profileNames = {};

  Future<String> _getSenderName(String senderId) async {
    if (_profileNames.containsKey(senderId)) {
      return _profileNames[senderId]!;
    }

    try {
      final repo = ref.read(friendsRepositoryProvider);
      final profile = await repo.getUserById(senderId);
      if (profile != null) {
        final name = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
        setState(() {
          _profileNames[senderId] = name;
        });
        return name;
      }
    } catch (_) {}

    return senderId.substring(0, 8);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    try {
      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMessage(
        receiverId: null,
        content: content,
        roomId: widget.roomId,
      );
      _messageController.clear();
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
      }
    }
  }

  Future<void> _sendImage() async {
    try {
      final image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading image...'), duration: Duration(days: 1)),
      );

      final mediaRepo = ref.read(mediaRepositoryProvider);
      final uploadResult = await mediaRepo.uploadMedia(
        file: File(image.path),
        fileType: 'image',
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMediaMessage(
        receiverId: null,
        messageType: 'image',
        mediaUrl: uploadResult['url']!,
        mediaThumbnail: uploadResult['thumbnail'],
        content: '📷 Image',
        roomId: widget.roomId,
      );

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image sent!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending image: $e')));
      }
    }
  }

  Future<void> _sendVideo() async {
    try {
      final video = await _imagePicker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading video...'), duration: Duration(days: 1)),
      );

      final mediaRepo = ref.read(mediaRepositoryProvider);
      final uploadResult = await mediaRepo.uploadMedia(
        file: File(video.path),
        fileType: 'video',
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMediaMessage(
        receiverId: null,
        messageType: 'video',
        mediaUrl: uploadResult['url']!,
        mediaThumbnail: uploadResult['thumbnail'],
        content: '🎥 Video',
        roomId: widget.roomId,
      );

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video sent!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending video: $e')));
      }
    }
  }

  Future<void> _sendFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result == null) return;

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading file...'), duration: Duration(days: 1)),
      );

      final mediaRepo = ref.read(mediaRepositoryProvider);
      final uploadResult = await mediaRepo.uploadMedia(
        file: File(filePath),
        fileType: 'file',
      );

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      final repository = ref.read(chatRepositoryProvider);
      await repository.sendMediaMessage(
        receiverId: null,
        messageType: 'file',
        mediaUrl: uploadResult['url']!,
        content: '📎 ${file.name}',
        roomId: widget.roomId,
      );

      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File sent!')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error sending file: $e')));
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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

  void _showEmojiPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        height: 300,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Emojis & GIFs',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 8,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children:
                    [
                      // Smileys
                      '😀', '😂', '🤣', '😊', '😍', '🥰', '😘', '😎',
                      '🤔', '😴', '😭', '😡', '🤯', '🥳', '😇', '🤗',
                      // Gestures
                      '👍', '👎', '👏', '🙌', '🤝', '💪', '🙏', '✌️',
                      // Hearts
                      '❤️', '💕', '💖', '💗', '💓', '💞', '💝', '💟',
                      // Symbols
                      '💯', '🔥', '⭐', '✨', '🎉', '🎊', '🎈', '🎁',
                      // Music
                      '🎵', '🎶', '🎤', '🎧', '🎸', '🎹', '🥁', '🎺',
                      // Tech
                      '📱', '💻', '⌨️', '🖥️', '🖱️', '🎮', '🕹️', '🎯',
                      // Food
                      '🍕', '🍔', '🍟', '🍿', '☕', '🍺', '🍰', '🎂',
                    ].map((emoji) {
                      return InkWell(
                        onTap: () {
                          _messageController.text += emoji;
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 28),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref
        .watch(chatRepositoryProvider)
        .watchRoomMessages(widget.roomId);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName),
            const Text(
              'Room Chat',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 64,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback(
                  (_) => _scrollToBottom(),
                );

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe =
                        message.senderId ==
                        ref
                            .read(chatRepositoryProvider)
                            .supabase
                            ?.auth
                            .currentUser
                            ?.id;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isMe) ...[
                            FutureBuilder<String>(
                              future: _getSenderName(message.senderId),
                              builder: (context, snapshot) {
                                final name = snapshot.data ?? message.senderId;
                                return CircleAvatar(
                                  radius: 16,
                                  child: Text(
                                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: GlassCard(
                              margin: EdgeInsets.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMe)
                                    FutureBuilder<String>(
                                      future: _getSenderName(message.senderId),
                                      builder: (context, snapshot) {
                                        final name = snapshot.data ?? message.senderId.substring(0, 8);
                                        return Text(
                                          name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        );
                                      },
                                    ),
                                  if (message.messageType == 'image')
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.image_rounded,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(message.content),
                                      ],
                                    )
                                  else if (message.messageType == 'video')
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.videocam_rounded,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(message.content),
                                      ],
                                    )
                                  else if (message.messageType == 'file')
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Icon(
                                          Icons.attach_file_rounded,
                                          size: 40,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(message.content),
                                      ],
                                    )
                                  else
                                    Text(
                                      message.content,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat(
                                      'HH:mm',
                                    ).format(message.createdAt),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (isMe) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primary,
                              child: const Icon(Icons.person, size: 16),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // Message input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: _showMediaOptions,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                  tooltip: 'Attach Media',
                ),
                IconButton(
                  onPressed: _showEmojiPicker,
                  icon: const Icon(Icons.emoji_emotions_rounded),
                  tooltip: 'Emoji & GIF',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                    maxLines: null,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: _sendMessage,
                  icon: const Icon(Icons.send_rounded),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
