import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/rooms/domain/playback_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RoomRepository();
});

class RoomRepository {
  SupabaseClient? get supabase => SupabaseService.clientOrNull;

  SupabaseClient get _client {
    final client = SupabaseService.clientOrNull;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }
    return client;
  }

  Stream<List<Map<String, dynamic>>> watchPublicRooms() {
    return _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('visibility', 'public')
        .order('created_at');
  }

  Stream<List<Map<String, dynamic>>> watchRoomsByType(String roomType) {
    return _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('room_type', roomType)
        .order('created_at')
        .map((list) => list.where((room) => room['visibility'] == 'public').toList());
  }

  Future<String> createRoom({
    required String name,
    required bool isPrivate,
    String? mediaUrl,
    String roomType = 'party',
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be logged in to create a room.');
    }

    final rows = await _client
        .from('rooms')
        .insert({
          'name': name,
          'host_id': userId,
          'room_type': roomType,
          'visibility': isPrivate ? 'private' : 'public',
          'media_url': mediaUrl,
          'playback_state': {
            'position_ms': 0,
            'is_playing': false,
            'source_url': mediaUrl,
            'host_id': userId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        })
        .select('id')
        .single();

    final roomId = rows['id'] as String;
    await _client.from('room_participants').insert({
      'room_id': roomId,
      'user_id': userId,
      'role': 'host',
    });
    return roomId;
  }

  Future<void> updatePlayback({
    required String roomId,
    required PlaybackStateSnapshot state,
  }) async {
    await _client
        .from('rooms')
        .update({'playback_state': state.toMap()})
        .eq('id', roomId);
  }

  Future<Map<String, dynamic>> getRoomDetails(String roomId) async {
    final response = await _client
        .from('rooms')
        .select()
        .eq('id', roomId)
        .single();
    return response;
  }

  Future<void> joinRoom(String roomId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be logged in to join a room.');
    }

    try {
      await _client.from('room_participants').insert({
        'room_id': roomId,
        'user_id': userId,
        'role': 'member',
      });
    } on PostgrestException catch (e) {
      // If user is already in the room, treat it as success
      if (e.code == '23505' || e.message.contains('duplicate key') || e.message.contains('23505')) {
        return;
      }
      rethrow;
    } catch (e) {
      if (e.toString().contains('23505') || e.toString().contains('duplicate key')) {
        return;
      }
      rethrow;
    }
  }

  Future<void> leaveRoom(String roomId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('You must be logged in.');
    }

    await _client
        .from('room_participants')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  Stream<List<Map<String, dynamic>>> watchRoomParticipants(String roomId) {
    return _client
        .from('room_participants')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('joined_at');
  }

  Stream<Map<String, dynamic>> watchRoom(String roomId) {
    return _client
        .from('rooms')
        .stream(primaryKey: ['id'])
        .eq('id', roomId)
        .map((data) => data.isNotEmpty ? data.first : <String, dynamic>{});
  }

  Future<int> getParticipantCount(String roomId) async {
    try {
      final response = await _client
          .from('room_participants')
          .select('id')
          .eq('room_id', roomId);
      return (response as List).length;
    } catch (e) {
      return 0;
    }
  }

  Future<bool> isUserInRoom(String roomId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return false;
    final result = await _client
        .from('room_participants')
        .select()
        .eq('room_id', roomId)
        .eq('user_id', userId)
        .maybeSingle();
    return result != null;
  }

  Future<List<Map<String, dynamic>>> getRoomParticipantsWithProfiles(
    String roomId,
  ) async {
    final response = await _client
        .from('room_participants')
        .select('*, profiles(*)')
        .eq('room_id', roomId)
        .order('joined_at');
    return List<Map<String, dynamic>>.from(response);
  }
}
