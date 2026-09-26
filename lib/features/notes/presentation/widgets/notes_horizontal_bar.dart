import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/features/notes/data/notes_repository.dart';
import 'package:calcx/features/notes/domain/user_note.dart';
import 'package:calcx/features/notes/presentation/widgets/create_note_bottom_sheet.dart';
import 'package:calcx/features/notes/presentation/widgets/view_note_dialog.dart';
import 'package:calcx/features/profile/data/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NotesHorizontalBar extends ConsumerWidget {
  const NotesHorizontalBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeNotesAsync = ref.watch(activeNotesProvider);
    final myNoteAsync = ref.watch(myNoteProvider);
    final myProfileAsync = ref.watch(myProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myNote = myNoteAsync.maybeWhen(
      data: (note) => note,
      orElse: () => null,
    );

    final allNotes = activeNotesAsync.maybeWhen(
      data: (list) => list,
      orElse: () => <UserNote>[],
    );

    // Filter out my note from friends list if present
    final myId = myProfileAsync.maybeWhen(
      data: (p) => p?.id,
      orElse: () => null,
    );

    final friendsNotes = allNotes.where((n) => n.userId != myId).toList();

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: 1 + friendsNotes.length,
        itemBuilder: (context, index) {
          if (index == 0) {
            // First item: My Note
            return _MyNoteItem(
              myNote: myNote,
              myProfileAsync: myProfileAsync,
              isDark: isDark,
              onTap: () {
                CreateNoteBottomSheet.show(context, existingNote: myNote);
              },
            );
          }

          // Friends Notes
          final note = friendsNotes[index - 1];
          return _FriendNoteItem(
            note: note,
            isDark: isDark,
            onTap: () {
              ViewNoteDialog.show(context, note);
            },
          );
        },
      ),
    );
  }
}

class _MyNoteItem extends StatelessWidget {
  const _MyNoteItem({
    required this.myNote,
    required this.myProfileAsync,
    required this.isDark,
    required this.onTap,
  });

  final UserNote? myNote;
  final AsyncValue<UserProfile?> myProfileAsync;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final avatarUrl = myProfileAsync.maybeWhen(
      data: (p) => p?.avatarUrl,
      orElse: () => null,
    );

    final hasNote = myNote != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Thought bubble above avatar
              SizedBox(
                height: 28,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222636) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasNote && myNote!.hasMusic) ...[
                        const Icon(Icons.music_note_rounded, size: 10, color: Color(0xFF00FFCC)),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          hasNote ? myNote!.content : 'Note...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: hasNote ? FontWeight.w600 : FontWeight.normal,
                            color: hasNote
                                ? (isDark ? Colors.white : Colors.black87)
                                : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Avatar with plus badge
              Stack(
                alignment: Alignment.center,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark ? const Color(0xFF25293A) : const Color(0xFFE2E8F0),
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                        ? CachedNetworkImageProvider(avatarUrl)
                        : null,
                    child: avatarUrl == null || avatarUrl.isEmpty
                        ? const Icon(Icons.person_rounded, size: 28, color: Colors.grey)
                        : null,
                  ),
                  if (!hasNote)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00FFCC),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_rounded, size: 14, color: Colors.black),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              const Text(
                'Your note',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendNoteItem extends StatelessWidget {
  const _FriendNoteItem({
    required this.note,
    required this.isDark,
    required this.onTap,
  });

  final UserNote note;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isCloseFriend = note.audience == 'close_friends';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(40),
        child: SizedBox(
          width: 80,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Floating Thought Bubble above avatar
              SizedBox(
                height: 28,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF222636) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(14),
                    border: isCloseFriend
                        ? Border.all(color: const Color(0xFF10B981), width: 1)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (note.hasMusic) ...[
                        const Icon(Icons.music_note_rounded, size: 10, color: Color(0xFF00FFCC)),
                        const SizedBox(width: 2),
                      ],
                      Flexible(
                        child: Text(
                          note.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Avatar with Close Friends green ring if applicable
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: isCloseFriend
                      ? Border.all(color: const Color(0xFF10B981), width: 2)
                      : Border.all(color: const Color(0xFF00FFCC).withOpacity(0.3), width: 1.5),
                ),
                child: CircleAvatar(
                  radius: 26,
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
              ),
              const SizedBox(height: 6),

              Text(
                note.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
