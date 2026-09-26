import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/notes/domain/user_note.dart';
import 'package:calcx/features/notes/services/ritune_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ViewNoteDialog extends ConsumerStatefulWidget {
  const ViewNoteDialog({super.key, required this.note});

  final UserNote note;

  static Future<void> show(BuildContext context, UserNote note) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ViewNoteDialog(note: note),
    );
  }

  @override
  ConsumerState<ViewNoteDialog> createState() => _ViewNoteDialogState();
}

class _ViewNoteDialogState extends ConsumerState<ViewNoteDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _replyController = TextEditingController();
  late AnimationController _rotationController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }

  Future<void> _sendReply() async {
    final reply = _replyController.text.trim();
    if (reply.isEmpty) return;

    setState(() => _isSending = true);

    try {
      final repository = ref.read(chatRepositoryProvider);
      final messageContent = '💭 Replying to Note: "${widget.note.content}"\n\n$reply';

      await repository.sendMessage(
        receiverId: widget.note.userId,
        content: messageContent,
      );

      // Stop audio if playing
      ref.read(ritunePlaybackProvider.notifier).stop();

      if (mounted) {
        Navigator.of(context).pop();
        context.push('/chat/${widget.note.userId}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending reply: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final note = widget.note;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playbackState = ref.watch(ritunePlaybackProvider);
    final isPlaying = playbackState.playingTrackId == note.id && playbackState.isPlaying;

    if (isPlaying) {
      if (!_rotationController.isAnimating) _rotationController.repeat();
    } else {
      if (_rotationController.isAnimating) _rotationController.stop();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141721) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 4),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Author info header
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: isDark ? const Color(0xFF25293A) : const Color(0xFFE2E8F0),
                  backgroundImage: note.avatarUrl != null && note.avatarUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(note.avatarUrl!)
                      : null,
                  child: note.avatarUrl == null || note.avatarUrl!.isEmpty
                      ? Text(
                          note.authorName.isNotEmpty ? note.authorName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              note.authorName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (note.audience == 'close_friends') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.18),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star_rounded, size: 12, color: Color(0xFF10B981)),
                                  SizedBox(width: 2),
                                  Text(
                                    'Close',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _formatTimeAgo(note.createdAt),
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    ref.read(ritunePlaybackProvider.notifier).stop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Large Instagram Thought Bubble
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1F2436), const Color(0xFF181C2B)]
                      : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? Colors.white10 : Colors.black12,
                ),
              ),
              child: Text(
                note.content,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
            const SizedBox(height: 16),

            // Music Section (if attached)
            if (note.hasMusic) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1E2C) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isPlaying ? const Color(0xFF00FFCC) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    // Spinning vinyl disc or artwork
                    RotationTransition(
                      turns: _rotationController,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: note.songArtwork != null && note.songArtwork!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: note.songArtwork!,
                                width: 48,
                                height: 48,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  width: 48,
                                  height: 48,
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.music_note_rounded, color: Colors.white),
                                ),
                              )
                            : Container(
                                width: 48,
                                height: 48,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Color(0xFF00FFCC), Color(0xFF00B0FF)],
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.music_note_rounded, color: Colors.black),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Title & Artist
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            note.songTitle ?? 'Unknown Song',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isPlaying ? const Color(0xFF00FFCC) : null,
                            ),
                          ),
                          Text(
                            note.songArtist ?? 'RiTune Track',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),

                    // Play / Pause button
                    if (note.songUrl != null && note.songUrl!.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                          color: const Color(0xFF00FFCC),
                          size: 36,
                        ),
                        onPressed: () {
                          ref.read(ritunePlaybackProvider.notifier).playUrl(
                                note.songUrl!,
                                note.id,
                                isLocal: note.isLocalSong,
                              );
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Quick reply input field (Sends DM to this user)
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    decoration: InputDecoration(
                      hintText: 'Reply to ${note.authorName}...',
                      hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendReply(),
                  ),
                ),
                const SizedBox(width: 8),
                if (_isSending)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFCC)),
                  )
                else
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFF00FFCC),
                      foregroundColor: Colors.black,
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    onPressed: _sendReply,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
