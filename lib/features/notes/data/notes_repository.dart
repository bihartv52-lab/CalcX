import 'dart:convert';
import 'dart:io';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/notes/domain/user_note.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  final supabase = SupabaseService.clientOrNull;
  return NotesRepository(supabase: supabase);
});

final activeNotesProvider = FutureProvider<List<UserNote>>((ref) async {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.fetchAllActiveNotes();
});

final myNoteProvider = FutureProvider<UserNote?>((ref) async {
  final repository = ref.watch(notesRepositoryProvider);
  return repository.fetchMyNote();
});

class NotesRepository {
  NotesRepository({required this.supabase});

  final SupabaseClient? supabase;
  static const _cacheKey = 'calcx_cached_user_notes';

  /// Fetches the currently authenticated user's active note
  Future<UserNote?> fetchMyNote() async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id;
    if (client == null || myId == null) {
      return _loadMyCachedNote();
    }

    try {
      final res = await client
          .from('user_notes')
          .select('*, profiles:user_id(username, display_name, avatar_url)')
          .eq('user_id', myId)
          .gt('expires_at', DateTime.now().toIso8601String())
          .maybeSingle();

      if (res != null) {
        final note = UserNote.fromMap(res);
        await _saveMyNoteToCache(note);
        return note;
      }
    } catch (e) {
      debugPrint('Error fetching my note: $e');
    }
    return _loadMyCachedNote();
  }

  /// Fetches all active friends & mutual notes
  Future<List<UserNote>> fetchAllActiveNotes() async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id;

    if (client == null || myId == null) {
      return _loadCachedNotes();
    }

    try {
      final now = DateTime.now().toIso8601String();

      // 1. Get friend IDs (from 'friends', 'friend_requests', and 'friendships' tables)
      final friendIds = <String>{};
      try {
        final friendsRes = await client
            .from('friends')
            .select('friend_id')
            .eq('user_id', myId);
        for (final f in (friendsRes as List<dynamic>)) {
          final fid = f['friend_id']?.toString();
          if (fid != null && fid.isNotEmpty) friendIds.add(fid);
        }
      } catch (_) {}

      try {
        final friendsReverse = await client
            .from('friends')
            .select('user_id')
            .eq('friend_id', myId);
        for (final f in (friendsReverse as List<dynamic>)) {
          final uid = f['user_id']?.toString();
          if (uid != null && uid.isNotEmpty) friendIds.add(uid);
        }
      } catch (_) {}

      try {
        final friendReqs = await client
            .from('friend_requests')
            .select('sender_id, receiver_id')
            .or('sender_id.eq.$myId,receiver_id.eq.$myId')
            .eq('status', 'accepted');
        for (final r in (friendReqs as List<dynamic>)) {
          final s = r['sender_id']?.toString();
          final rc = r['receiver_id']?.toString();
          if (s != null && s != myId) friendIds.add(s);
          if (rc != null && rc != myId) friendIds.add(rc);
        }
      } catch (_) {}

      try {
        final friendships = await client
            .from('friendships')
            .select('user_id_1, user_id_2')
            .or('user_id_1.eq.$myId,user_id_2.eq.$myId')
            .eq('status', 'accepted');
        for (final f in friendships as List<dynamic>) {
          final id1 = f['user_id_1']?.toString();
          final id2 = f['user_id_2']?.toString();
          if (id1 != null && id1 != myId) friendIds.add(id1);
          if (id2 != null && id2 != myId) friendIds.add(id2);
        }
      } catch (_) {}

      // 2. Get authors who added me to their close friends
      final closeFriendAuthorIds = <String>{};
      try {
        final closeFriendRecords = await client
            .from('close_friends')
            .select('user_id')
            .eq('friend_id', myId);
        for (final r in (closeFriendRecords as List<dynamic>)) {
          final uid = r['user_id']?.toString();
          if (uid != null) closeFriendAuthorIds.add(uid);
        }
      } catch (_) {}

      // 3. Query unexpired notes
      final notesData = await client
          .from('user_notes')
          .select('*, profiles:user_id(username, display_name, avatar_url)')
          .gt('expires_at', now)
          .order('created_at', ascending: false);

      final resultList = <UserNote>[];
      for (final raw in (notesData as List<dynamic>)) {
        final map = raw as Map<String, dynamic>;
        final authorId = map['user_id']?.toString();
        final audience = map['audience']?.toString() ?? 'everyone';

        if (authorId == null) continue;

        // Note owner always sees their own note
        if (authorId == myId) {
          resultList.add(UserNote.fromMap(map));
          continue;
        }

        // If author specifically mentioned me in the note, always allow
        final mentionedId = map['mentioned_user_id']?.toString();
        if (mentionedId == myId) {
          resultList.add(UserNote.fromMap(map));
          continue;
        }

        // Audience privacy filter:
        if (audience == 'everyone') {
          resultList.add(UserNote.fromMap(map));
        } else if (audience == 'close_friends') {
          if (closeFriendAuthorIds.contains(authorId)) {
            resultList.add(UserNote.fromMap(map));
          }
        } else if (audience == 'selected_friends') {
          final rawAllowed = map['allowed_user_ids'];
          if (rawAllowed is List && rawAllowed.map((e) => e.toString()).contains(myId)) {
            resultList.add(UserNote.fromMap(map));
          }
        } else {
          // 'mutual' / friends: visible if friends or connected
          if (friendIds.contains(authorId) || friendIds.isEmpty) {
            resultList.add(UserNote.fromMap(map));
          }
        }
      }

      await _saveNotesToCache(resultList);
      return resultList;
    } catch (e) {
      debugPrint('Error fetching notes from Supabase: $e');
      return _loadCachedNotes();
    }
  }

  /// Post or update the current user's note
  Future<UserNote> postNote({
    required String content,
    String? songTitle,
    String? songArtist,
    String? songArtwork,
    String? songUrl,
    bool isLocalSong = false,
    String? localFilePath,
    Uint8List? audioBytes,
    String? fileName,
    String audience = 'mutual',
    int songSnippetStart = 0,
    int songSnippetDuration = 30,
    String? mentionedUserId,
    String? mentionedUsername,
    String? mentionedDisplayName,
    String? mentionedAvatarUrl,
    List<String> allowedUserIds = const [],
  }) async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id ?? 'local_user';
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    String? finalSongUrl = songUrl;

    // If local song is attached, try to upload to Supabase storage bucket
    if (isLocalSong && client != null && myId != 'local_user') {
      try {
        Uint8List? bytes = audioBytes;
        String ext = 'mp3';
        if (fileName != null && fileName.contains('.')) {
          ext = fileName.split('.').last.toLowerCase();
        } else if (localFilePath != null && localFilePath.contains('.')) {
          ext = localFilePath.split('.').last.toLowerCase();
        }

        if (bytes == null && !kIsWeb && localFilePath != null) {
          final file = File(localFilePath);
          if (await file.exists()) {
            bytes = await file.readAsBytes();
          }
        }

        if (bytes != null) {
          final storagePath = 'notes/${myId}_${now.millisecondsSinceEpoch}.$ext';
          final mimeType = ext == 'wav'
              ? 'audio/wav'
              : (ext == 'm4a' || ext == 'aac' ? 'audio/aac' : 'audio/mpeg');

          await client.storage.from('media').uploadBinary(
                storagePath,
                bytes,
                fileOptions: FileOptions(contentType: mimeType, upsert: true),
              );

          finalSongUrl = client.storage.from('media').getPublicUrl(storagePath);
        }
      } catch (e) {
        debugPrint('Notice uploading local note audio: $e');
        if (finalSongUrl == null || finalSongUrl.isEmpty) {
          finalSongUrl = localFilePath;
        }
      }
    }

    final noteMap = {
      'user_id': myId,
      'content': content.trim(),
      'song_title': songTitle,
      'song_artist': songArtist,
      'song_artwork': songArtwork,
      'song_url': finalSongUrl,
      'is_local_song': isLocalSong,
      'song_snippet_start': songSnippetStart,
      'song_snippet_duration': songSnippetDuration,
      'audience': audience,
      'mentioned_user_id': mentionedUserId,
      'mentioned_username': mentionedUsername,
      'mentioned_display_name': mentionedDisplayName,
      'mentioned_avatar_url': mentionedAvatarUrl,
      'allowed_user_ids': allowedUserIds,
      'created_at': now.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };

    if (client != null && myId != 'local_user') {
      try {
        final inserted = await client
            .from('user_notes')
            .upsert(noteMap, onConflict: 'user_id')
            .select('*, profiles:user_id(username, display_name, avatar_url)')
            .single();

        final created = UserNote.fromMap(inserted);
        await _saveMyNoteToCache(created);

        // Notify mentioned friend with disguised stealth push
        if (mentionedUserId != null && mentionedUserId.isNotEmpty) {
          _notifyMentionedUser(
            client: client,
            recipientId: mentionedUserId,
            authorId: myId,
            songTitle: songTitle,
          );
        }

        return created;
      } catch (e) {
        debugPrint('Notice upserting extended note, attempting safe schema fallback: $e');
        try {
          final safeMap = Map<String, dynamic>.from(noteMap);
          safeMap.remove('song_snippet_start');
          safeMap.remove('song_snippet_duration');
          safeMap.remove('mentioned_user_id');
          safeMap.remove('mentioned_username');
          safeMap.remove('mentioned_display_name');
          safeMap.remove('mentioned_avatar_url');
          safeMap.remove('allowed_user_ids');
          if (audience == 'selected_friends') {
            safeMap['audience'] = 'mutual';
          }
          final inserted = await client
              .from('user_notes')
              .upsert(safeMap, onConflict: 'user_id')
              .select('*, profiles:user_id(username, display_name, avatar_url)')
              .single();

          final created = UserNote.fromMap({
            ...inserted,
            'song_snippet_start': songSnippetStart,
            'song_snippet_duration': songSnippetDuration,
            'mentioned_user_id': mentionedUserId,
            'mentioned_username': mentionedUsername,
            'mentioned_display_name': mentionedDisplayName,
            'mentioned_avatar_url': mentionedAvatarUrl,
            'allowed_user_ids': allowedUserIds,
            'audience': audience,
          });
          await _saveMyNoteToCache(created);

          if (mentionedUserId != null && mentionedUserId.isNotEmpty) {
            _notifyMentionedUser(
              client: client,
              recipientId: mentionedUserId,
              authorId: myId,
              songTitle: songTitle,
            );
          }

          return created;
        } catch (e2) {
          debugPrint('Error upserting note to Supabase: $e2');
        }
      }
    }

    // Local / offline fallback
    final fallbackNote = UserNote(
      id: 'local_${now.millisecondsSinceEpoch}',
      userId: myId,
      content: content.trim(),
      songTitle: songTitle,
      songArtist: songArtist,
      songArtwork: songArtwork,
      songUrl: finalSongUrl,
      isLocalSong: isLocalSong,
      songSnippetStart: songSnippetStart,
      songSnippetDuration: songSnippetDuration,
      audience: audience,
      mentionedUserId: mentionedUserId,
      mentionedUsername: mentionedUsername,
      mentionedDisplayName: mentionedDisplayName,
      mentionedAvatarUrl: mentionedAvatarUrl,
      allowedUserIds: allowedUserIds,
      createdAt: now,
      expiresAt: expiresAt,
      username: 'You',
    );
    await _saveMyNoteToCache(fallbackNote);
    return fallbackNote;
  }

  /// Sends a stealth disguised notification when someone is mentioned in a note/song
  Future<void> _notifyMentionedUser({
    required SupabaseClient client,
    required String recipientId,
    required String authorId,
    String? songTitle,
  }) async {
    try {
      final myProfile = await client
          .from('profiles')
          .select('username, display_name')
          .eq('id', authorId)
          .maybeSingle();

      final authorName = myProfile?['display_name'] ?? myProfile?['username'] ?? 'Someone';

      final notifData = {
        'user_id': recipientId,
        'type': 'note_mention',
        'title': 'CalcX',
        'body': 'Your previous calculation is pending.',
        'data': {
          'author_id': authorId,
          'author_name': authorName,
          'song_title': songTitle ?? '',
          'content': '$authorName mentioned you in a note 🎵',
        },
      };

      final insertedNotif = await client.from('notifications').insert(notifData).select().maybeSingle();

      // Trigger immediate push notification
      try {
        await client.functions.invoke('push-notifications', body: {
          'record': insertedNotif ?? notifData,
        });
      } catch (_) {}
    } catch (e) {
      debugPrint('Notice sending note mention notification: $e');
    }
  }

  /// Delete the current user's active note
  Future<void> deleteNote() async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id;

    if (client != null && myId != null) {
      try {
        await client.from('user_notes').delete().eq('user_id', myId);
      } catch (e) {
        debugPrint('Error deleting note from Supabase: $e');
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('${_cacheKey}_my_note');
  }

  /// Manage Close Friends list
  Future<List<String>> getCloseFriends() async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id;
    if (client == null || myId == null) return [];

    try {
      final res = await client
          .from('close_friends')
          .select('friend_id')
          .eq('user_id', myId);
      return (res as List<dynamic>)
          .map((r) => r['friend_id']?.toString())
          .whereType<String>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> toggleCloseFriend(String friendId, bool isCloseFriend) async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id;
    if (client == null || myId == null) return;

    try {
      if (isCloseFriend) {
        await client.from('close_friends').upsert({
          'user_id': myId,
          'friend_id': friendId,
        });
      } else {
        await client
            .from('close_friends')
            .delete()
            .eq('user_id', myId)
            .eq('friend_id', friendId);
      }
    } catch (e) {
      debugPrint('Error toggling close friend: $e');
    }
  }

  // --- Local Cache Helpers ---
  Future<void> _saveNotesToCache(List<UserNote> notes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = notes.map((n) => n.toMap()).toList();
      await prefs.setString(_cacheKey, jsonEncode(list));
    } catch (_) {}
  }

  Future<List<UserNote>> _loadCachedNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_cacheKey);
      if (str != null) {
        final decoded = jsonDecode(str) as List<dynamic>;
        return decoded
            .map((item) => UserNote.fromMap(item as Map<String, dynamic>))
            .where((n) => !n.isExpired)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _saveMyNoteToCache(UserNote note) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('${_cacheKey}_my_note', jsonEncode(note.toMap()));
    } catch (_) {}
  }

  Future<UserNote?> _loadMyCachedNote() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('${_cacheKey}_my_note');
      if (str != null) {
        final note = UserNote.fromMap(jsonDecode(str) as Map<String, dynamic>);
        if (!note.isExpired) return note;
      }
    } catch (_) {}
    return null;
  }
}
