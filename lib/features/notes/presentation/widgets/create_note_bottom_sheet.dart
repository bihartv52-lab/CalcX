import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/features/notes/data/notes_repository.dart';
import 'package:calcx/features/notes/domain/user_note.dart';
import 'package:calcx/features/notes/presentation/widgets/music_picker_bottom_sheet.dart';
import 'package:calcx/features/notes/services/ritune_service.dart';
import 'package:calcx/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CreateNoteBottomSheet extends ConsumerStatefulWidget {
  const CreateNoteBottomSheet({super.key, this.existingNote});

  final UserNote? existingNote;

  static Future<void> show(BuildContext context, {UserNote? existingNote}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CreateNoteBottomSheet(existingNote: existingNote),
    );
  }

  @override
  ConsumerState<CreateNoteBottomSheet> createState() => _CreateNoteBottomSheetState();
}

class _CreateNoteBottomSheetState extends ConsumerState<CreateNoteBottomSheet> {
  final TextEditingController _thoughtController = TextEditingController();
  RiTuneTrack? _selectedTrack;
  String _audience = 'mutual'; // 'mutual', 'close_friends', 'everyone'
  bool _isPosting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingNote != null) {
      _thoughtController.text = widget.existingNote!.content;
      _audience = widget.existingNote!.audience;
      if (widget.existingNote!.hasMusic) {
        _selectedTrack = RiTuneTrack(
          id: 'existing',
          title: widget.existingNote!.songTitle ?? '',
          artist: widget.existingNote!.songArtist ?? '',
          artwork: widget.existingNote!.songArtwork ?? '',
          streamUrl: widget.existingNote!.songUrl ?? '',
          isLocal: widget.existingNote!.isLocalSong,
        );
      }
    }
  }

  @override
  void dispose() {
    _thoughtController.dispose();
    super.dispose();
  }

  Future<void> _pickMusic() async {
    final track = await MusicPickerBottomSheet.show(context);
    if (track != null && mounted) {
      setState(() {
        _selectedTrack = track;
      });
    }
  }

  Future<void> _shareNote() async {
    final text = _thoughtController.text.trim();
    if (text.isEmpty && _selectedTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a thought or select a song.')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      await ref.read(notesRepositoryProvider).postNote(
            content: text.isNotEmpty ? text : '🎵 Listening to ${_selectedTrack?.title}',
            songTitle: _selectedTrack?.title,
            songArtist: _selectedTrack?.artist,
            songArtwork: _selectedTrack?.artwork,
            songUrl: _selectedTrack?.streamUrl,
            isLocalSong: _selectedTrack?.isLocal ?? false,
            localFilePath: _selectedTrack?.localPath,
            audience: _audience,
          );

      ref.invalidate(activeNotesProvider);
      ref.invalidate(myNoteProvider);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note shared successfully! ✨'),
            backgroundColor: Color(0xFF00FFCC),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  Future<void> _deleteNote() async {
    setState(() => _isPosting = true);
    try {
      await ref.read(notesRepositoryProvider).deleteNote();
      ref.invalidate(activeNotesProvider);
      ref.invalidate(myNoteProvider);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPosting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myProfileAsync = ref.watch(myProfileProvider);
    final playbackState = ref.watch(ritunePlaybackProvider);

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag indicator
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Title and Share button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingNote != null ? 'Edit Note' : 'New Note',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (_isPosting)
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00FFCC)),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00FFCC),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      ),
                      onPressed: _shareNote,
                      child: const Text('Share', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Instagram Avatar with Floating Thought Bubble Preview
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // User Avatar
                  myProfileAsync.maybeWhen(
                    data: (profile) {
                      final avatarUrl = profile?.avatarUrl;
                      return CircleAvatar(
                        radius: 44,
                        backgroundColor: isDark ? const Color(0xFF25293A) : const Color(0xFFE2E8F0),
                        backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                            ? CachedNetworkImageProvider(avatarUrl)
                            : null,
                        child: avatarUrl == null || avatarUrl.isEmpty
                            ? const Icon(Icons.person_rounded, size: 44, color: Colors.grey)
                            : null,
                      );
                    },
                    orElse: () => const CircleAvatar(
                      radius: 44,
                      child: Icon(Icons.person_rounded, size: 44),
                    ),
                  ),

                  // Floating Thought Bubble over avatar
                  Positioned(
                    top: -30,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 240),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF25293A) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_selectedTrack != null) ...[
                            const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFF00FFCC)),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              _thoughtController.text.isNotEmpty
                                  ? _thoughtController.text
                                  : 'Share a thought...',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _thoughtController.text.isNotEmpty
                                    ? (isDark ? Colors.white : Colors.black87)
                                    : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Text input field for the thought (60 characters limit)
              TextField(
                controller: _thoughtController,
                maxLength: 60,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Share what\'s on your mind...',
                  counterText: '${_thoughtController.text.length}/60',
                  hintStyle: const TextStyle(color: Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Attached Music Pill / Card or "Add Music" Button
              if (_selectedTrack != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF00FFCC).withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: _selectedTrack!.artwork,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 40,
                            height: 40,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedTrack!.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            Text(
                              _selectedTrack!.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          playbackState.playingTrackId == _selectedTrack!.id && playbackState.isPlaying
                              ? Icons.pause_circle_rounded
                              : Icons.play_circle_rounded,
                          color: const Color(0xFF00FFCC),
                          size: 28,
                        ),
                        onPressed: () {
                          ref.read(ritunePlaybackProvider.notifier).togglePlay(_selectedTrack!);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                        onPressed: () {
                          ref.read(ritunePlaybackProvider.notifier).stop();
                          setState(() {
                            _selectedTrack = null;
                          });
                        },
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF00FFCC),
                    side: BorderSide(color: const Color(0xFF00FFCC).withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  icon: const Icon(Icons.music_note_rounded),
                  label: const Text('Add Music (RiTune & Local Songs)', style: TextStyle(fontWeight: FontWeight.w600)),
                  onPressed: _pickMusic,
                ),
              const SizedBox(height: 20),

              // Audience / Privacy Selector ("Who can see this?")
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.visibility_rounded, size: 18, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Who can see your note?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _AudienceOption(
                      title: 'Mutual Friends',
                      subtitle: 'Followers you follow back & mutual chats',
                      icon: Icons.people_alt_rounded,
                      value: 'mutual',
                      groupValue: _audience,
                      onChanged: (val) => setState(() => _audience = val!),
                    ),
                    const Divider(height: 16),
                    _AudienceOption(
                      title: 'Close Friends',
                      subtitle: 'Only people in your Close Friends circle',
                      icon: Icons.star_rounded,
                      iconColor: const Color(0xFF10B981),
                      value: 'close_friends',
                      groupValue: _audience,
                      onChanged: (val) => setState(() => _audience = val!),
                    ),
                    const Divider(height: 16),
                    _AudienceOption(
                      title: 'Everyone',
                      subtitle: 'Anyone you have chatted with',
                      icon: Icons.public_rounded,
                      value: 'everyone',
                      groupValue: _audience,
                      onChanged: (val) => setState(() => _audience = val!),
                    ),
                  ],
                ),
              ),

              // Delete Note option if editing
              if (widget.existingNote != null) ...[
                const SizedBox(height: 16),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: const Text('Delete Active Note'),
                  onPressed: _deleteNote,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AudienceOption extends StatelessWidget {
  const _AudienceOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.iconColor,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = value == groupValue;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? (selected ? const Color(0xFF00FFCC) : Colors.grey)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                      color: selected ? const Color(0xFF00FFCC) : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: const Color(0xFF00FFCC),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
