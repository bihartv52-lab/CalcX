import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/features/notes/data/notes_repository.dart';
import 'package:calcx/features/notes/domain/user_note.dart';
import 'package:calcx/features/notes/presentation/widgets/close_friends_picker_sheet.dart';
import 'package:calcx/features/notes/presentation/widgets/friend_mention_picker_sheet.dart';
import 'package:calcx/features/notes/presentation/widgets/music_picker_bottom_sheet.dart';
import 'package:calcx/features/notes/presentation/widgets/song_hook_trimmer_sheet.dart';
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
  UserProfile? _mentionedFriend;
  List<String> _selectedFriendIds = [];
  String _audience = 'everyone'; // Default to everyone so notes are visible to all contacts
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
          snippetStartSeconds: widget.existingNote!.songSnippetStart,
          snippetDurationSeconds: widget.existingNote!.songSnippetDuration,
        );
      }
      if (widget.existingNote!.mentionedUserId != null) {
        _mentionedFriend = UserProfile(
          id: widget.existingNote!.mentionedUserId!,
          username: widget.existingNote!.mentionedUsername ?? '',
          displayName: widget.existingNote!.mentionedDisplayName ??
              widget.existingNote!.mentionedUsername ??
              'Friend',
          avatarUrl: widget.existingNote!.mentionedAvatarUrl,
        );
      }
      _selectedFriendIds = List<String>.from(widget.existingNote!.allowedUserIds);
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

  Future<void> _pickMention() async {
    final friend = await FriendMentionPickerSheet.show(context);
    if (friend != null && mounted) {
      setState(() {
        _mentionedFriend = friend;
      });
    }
  }

  Future<void> _pickSelectedFriends() async {
    final chosen = await CloseFriendsPickerSheet.showSelector(
      context,
      initialSelectedIds: _selectedFriendIds,
    );
    if (chosen != null && mounted) {
      setState(() {
        _selectedFriendIds = chosen;
        if (chosen.isNotEmpty) {
          _audience = 'selected_friends';
        }
      });
    }
  }

  Future<void> _manageCloseFriends() async {
    await CloseFriendsPickerSheet.showManager(context);
  }

  Future<void> _shareNote() async {
    final text = _thoughtController.text.trim();
    if (text.isEmpty && _selectedTrack == null && _mentionedFriend == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a thought, add music, or mention a friend.')),
      );
      return;
    }

    setState(() => _isPosting = true);

    try {
      await ref.read(notesRepositoryProvider).postNote(
            content: text.isNotEmpty
                ? text
                : (_selectedTrack != null
                    ? '🎵 Listening to ${_selectedTrack?.title}'
                    : '👋 Hanging out with @${_mentionedFriend?.username}'),
            songTitle: _selectedTrack?.title,
            songArtist: _selectedTrack?.artist,
            songArtwork: _selectedTrack?.artwork,
            songUrl: _selectedTrack?.streamUrl,
            isLocalSong: _selectedTrack?.isLocal ?? false,
            localFilePath: _selectedTrack?.localPath,
            audioBytes: _selectedTrack?.audioBytes,
            fileName: _selectedTrack?.fileName,
            audience: _audience,
            songSnippetStart: _selectedTrack?.snippetStartSeconds ?? 0,
            songSnippetDuration: _selectedTrack?.snippetDurationSeconds ?? 30,
            mentionedUserId: _mentionedFriend?.id,
            mentionedUsername: _mentionedFriend?.username,
            mentionedDisplayName: _mentionedFriend?.displayName,
            mentionedAvatarUrl: _mentionedFriend?.avatarUrl,
            allowedUserIds: _selectedFriendIds,
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

  String _formatSnippetTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
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
                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                    )
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        foregroundColor: Colors.black87,
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
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withOpacity(0.35),
                          width: 1,
                        ),
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
                            const Icon(Icons.music_note_rounded, size: 14, color: Color(0xFFD4AF37)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: _selectedTrack!.artwork,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 44,
                                height: 44,
                                color: Colors.grey[800],
                                child: const Icon(Icons.music_note_rounded, color: Color(0xFFD4AF37)),
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
                              color: const Color(0xFFD4AF37),
                              size: 30,
                            ),
                            onPressed: () {
                              ref.read(ritunePlaybackProvider.notifier).togglePlay(
                                    _selectedTrack!,
                                    startSeconds: _selectedTrack!.snippetStartSeconds,
                                    durationSeconds: _selectedTrack!.snippetDurationSeconds,
                                  );
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
                      const SizedBox(height: 6),
                      // Hook Trimmer interactive pill
                      InkWell(
                        onTap: () async {
                          final trimmed = await SongHookTrimmerSheet.show(context, _selectedTrack!);
                          if (trimmed != null && mounted) {
                            setState(() {
                              _selectedTrack = trimmed;
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD4AF37).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                (_selectedTrack!.snippetDurationSeconds <= 0 || _selectedTrack!.snippetDurationSeconds >= _selectedTrack!.durationSeconds)
                                    ? Icons.all_inclusive_rounded
                                    : Icons.content_cut_rounded,
                                size: 13,
                                color: const Color(0xFFD4AF37),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                (_selectedTrack!.snippetDurationSeconds <= 0 || _selectedTrack!.snippetDurationSeconds >= _selectedTrack!.durationSeconds)
                                    ? 'Full Track 🎵 (Entire Song)'
                                    : 'Hook / Chorus: ${_formatSnippetTime(_selectedTrack!.snippetStartSeconds)} - ${_formatSnippetTime(_selectedTrack!.snippetStartSeconds + _selectedTrack!.snippetDurationSeconds)} (${_selectedTrack!.snippetDurationSeconds}s)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFD4AF37),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Icon(Icons.tune_rounded, size: 13, color: Color(0xFFD4AF37)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFD4AF37),
                          side: BorderSide(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        icon: const Icon(Icons.music_note_rounded, size: 20),
                        label: const Text('Add Music', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        onPressed: _pickMusic,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFE5C07B),
                          side: BorderSide(color: const Color(0xFFE5C07B).withOpacity(0.5)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                        ),
                        icon: const Icon(Icons.alternate_email_rounded, size: 20),
                        label: Text(
                          _mentionedFriend != null ? '@${_mentionedFriend!.username}' : 'Tag Friend',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        onPressed: _pickMention,
                      ),
                    ),
                  ],
                ),

              // Mentioned Friend Banner (if selected with music or thought)
              if (_mentionedFriend != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF00B0FF).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: const Color(0xFF00B0FF).withValues(alpha: 0.2),
                        backgroundImage: _mentionedFriend!.avatarUrl != null && _mentionedFriend!.avatarUrl!.isNotEmpty
                            ? CachedNetworkImageProvider(_mentionedFriend!.avatarUrl!)
                            : null,
                        child: _mentionedFriend!.avatarUrl == null || _mentionedFriend!.avatarUrl!.isEmpty
                            ? const Icon(Icons.person, size: 14, color: Color(0xFF00B0FF))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tagged @${_mentionedFriend!.username} in this note',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF00B0FF)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () => setState(() => _mentionedFriend = null),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.close_rounded, size: 16, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                      subtitle: 'Followers you follow back & mutual friends',
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
                      trailingAction: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF10B981),
                        ),
                        onPressed: _manageCloseFriends,
                        child: const Text('Edit List', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                      onChanged: (val) => setState(() => _audience = val!),
                    ),
                    const Divider(height: 16),
                    _AudienceOption(
                      title: 'Selected Friends Only',
                      subtitle: _selectedFriendIds.isEmpty
                          ? 'Choose specific friends for this note'
                          : '${_selectedFriendIds.length} friends selected',
                      icon: Icons.tune_rounded,
                      iconColor: const Color(0xFF00B0FF),
                      value: 'selected_friends',
                      groupValue: _audience,
                      trailingAction: TextButton(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          foregroundColor: const Color(0xFF00B0FF),
                        ),
                        onPressed: _pickSelectedFriends,
                        child: Text(
                          _selectedFriendIds.isEmpty ? 'Choose' : '${_selectedFriendIds.length} Selected',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      onChanged: (val) {
                        setState(() => _audience = val!);
                        if (_selectedFriendIds.isEmpty) {
                          _pickSelectedFriends();
                        }
                      },
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
    this.trailingAction,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color? iconColor;
  final String value;
  final String groupValue;
  final ValueChanged<String?> onChanged;
  final Widget? trailingAction;

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
            Icon(icon, size: 20, color: iconColor ?? (selected ? const Color(0xFFD4AF37) : Colors.grey)),
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
                      color: selected ? const Color(0xFFD4AF37) : null,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
            if (trailingAction != null) trailingAction!,
            Radio<String>(
              value: value,
              groupValue: groupValue,
              activeColor: const Color(0xFFD4AF37),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}
