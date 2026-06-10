import 'package:calcx/app/app_env.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final livekitTokenServiceProvider = Provider<LiveKitTokenService>((ref) {
  return LiveKitTokenService(ref.watch(appEnvProvider));
});

class LiveKitTokenService {
  const LiveKitTokenService(this._env);

  final AppEnv _env;

  /// Get LiveKit token for joining a room
  Future<String> getToken({
    required String roomName,
    required String participantName,
  }) async {
    final client = SupabaseService.clientOrNull;
    if (client == null) {
      throw StateError('Supabase is not configured.');
    }

    try {
      final response = await client.functions.invoke(
        _env.liveKitTokenFunction,
        body: {'room_name': roomName, 'participant_name': participantName},
      );

      final data = response.data;
      if (data is Map && data['token'] is String) {
        return data['token'] as String;
      }

      throw StateError('LiveKit token function did not return a token.');
    } catch (e) {
      debugPrint('Error getting LiveKit token: $e');
      rethrow;
    }
  }

  /// Legacy method for backward compatibility
  Future<String> createToken({
    required String roomName,
    required String identity,
  }) async {
    return getToken(roomName: roomName, participantName: identity);
  }
}
