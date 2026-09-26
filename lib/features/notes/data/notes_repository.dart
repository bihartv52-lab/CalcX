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

      // 1. Get friend IDs (accepted friendships)
      final friendships = await client
          .from('friendships')
          .select('user_id_1, user_id_2')
          .or('user_id_1.eq.$myId,user_id_2.eq.$myId')
          .eq('status', 'accepted');

      final friendIds = <String>{};
      for (final f in friendships as List<dynamic>) {
        final id1 = f['user_id_1']?.toString();
        final id2 = f['user_id_2']?.toString();
        if (id1 != null && id1 != myId) friendIds.add(id1);
        if (id2 != null && id2 != myId) friendIds.add(id2);
      }

      // 2. Get close friends who have added me
      final closeFriendRecords = await client
          .from('close_friends')
          .select('user_id')
          .eq('friend_id', myId);

      final closeFriendAuthorIds = (closeFriendRecords as List<dynamic>)
          .map((r) => r['user_id']?.toString())
          .whereType<String>()
          .toSet();

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
        final audience = map['audience']?.toString() ?? 'mutual';

        if (authorId == null) continue;

        // Note owner always sees their own note
        if (authorId == myId) {
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
        } else {
          // 'mutual' / friends
          if (friendIds.contains(authorId)) {
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
    String audience = 'mutual',
  }) async {
    final client = supabase;
    final myId = client?.auth.currentUser?.id ?? 'local_user';
    final now = DateTime.now();
    final expiresAt = now.add(const Duration(hours: 24));

    String? finalSongUrl = songUrl;

    // If local song is attached, try to upload to Supabase storage bucket
    if (isLocalSong && localFilePath != null && client != null && myId != 'local_user') {
      try {
        final file = File(localFilePath);
        if (await file.exists()) {
          final fileExt = localFilePath.split('.').last;
          final storagePath = 'notes/${myId}_${now.millisecondsSinceEpoch}.$fileExt';
          final bytes = await file.readAsBytes();

          await client.storage.from('media').uploadBinary(
                storagePath,
                bytes,
                fileOptions: FileOptions(contentType: 'audio/$fileExt', upsert: true),
              );

          finalSongUrl = client.storage.from('media').getPublicUrl(storagePath);
        }
      } catch (e) {
        debugPrint('Notice uploading local note audio: $e');
        // Fall back to local path if storage upload is unavailable
        finalSongUrl = localFilePath;
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
      'audience': audience,
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
        return created;
      } catch (e) {
        debugPrint('Error upserting note to Supabase: $e');
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
      audience: audience,
      createdAt: now,
      expiresAt: expiresAt,
      username: 'You',
    );
    await _saveMyNoteToCache(fallbackNote);
    return fallbackNote;
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
