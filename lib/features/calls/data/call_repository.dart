import 'dart:convert';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final callRepositoryProvider = Provider<CallRepository>((ref) {
  return CallRepository(SupabaseService.clientOrNull);
});

class CallRepository {
  CallRepository(this._supabase);

  final SupabaseClient? _supabase;
  SupabaseClient? get supabase => _supabase;
  static const _uuid = Uuid();

  Future<Call> initiateCall({
    required String receiverId,
    required String callType,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) {
      throw StateError('User must be logged in to make calls.');
    }

    final roomName = 'call_${_uuid.v4()}';
    final callData = {
      'caller_id': myId,
      'receiver_id': receiverId,
      'call_type': callType,
      'status': 'ringing',
      'room_name': roomName,
      'started_at': DateTime.now().toIso8601String(),
    };

    final response = await supabase
        .from('calls')
        .insert(callData)
        .select()
        .single();

    await supabase.from('notifications').insert({
      'user_id': receiverId,
      'type': 'call',
      'title': 'CalcX',
      'body': 'You have a pending calculation.',
      'data': {
        'call_id': response['id'],
        'call_type': callType,
        'room_name': roomName,
        'caller_id': myId,
      },
      'created_at': DateTime.now().toIso8601String(),
    });

    return Call.fromMap(response);
  }

  Future<void> acceptCall(String callId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    await supabase.from('calls').update({'status': 'ongoing'}).eq('id', callId);
  }

  Future<void> rejectCall(String callId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final call = await getCallById(callId);
      await supabase
          .from('calls')
          .update({
            'status': 'rejected',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId);

      if (call != null) {
        await _recordCallMessage(
          callerId: call.callerId,
          receiverId: call.receiverId,
          callType: call.callType,
          status: 'rejected',
          callId: callId,
        );
      }
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }
  }

  Future<void> rejectCallWithBusy(String callId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final call = await getCallById(callId);
      await supabase
          .from('calls')
          .update({
            'status': 'busy',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId);

      if (call != null) {
        await _recordCallMessage(
          callerId: call.callerId,
          receiverId: call.receiverId,
          callType: call.callType,
          status: 'busy',
          callId: callId,
        );
      }
    } catch (e) {
      debugPrint('Error rejecting call with busy: $e');
    }
  }

  Future<void> endCall(String callId, {DateTime? startTime}) async {
    final supabase = _supabase;
    if (supabase == null) return;

    final endTime = DateTime.now();
    final duration = startTime == null
        ? null
        : endTime.difference(startTime).inSeconds;

    try {
      final call = await getCallById(callId);
      await supabase
          .from('calls')
          .update({
            'status': 'ended',
            'ended_at': endTime.toIso8601String(),
            'duration': duration,
          })
          .eq('id', callId);

      if (call != null) {
        await _recordCallMessage(
          callerId: call.callerId,
          receiverId: call.receiverId,
          callType: call.callType,
          status: 'ended',
          duration: duration,
          callId: callId,
        );
      }
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  Future<void> markAsMissed(String callId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      final call = await getCallById(callId);
      await supabase
          .from('calls')
          .update({
            'status': 'missed',
            'ended_at': DateTime.now().toIso8601String(),
          })
          .eq('id', callId);

      if (call != null) {
        await _recordCallMessage(
          callerId: call.callerId,
          receiverId: call.receiverId,
          callType: call.callType,
          status: 'missed',
          callId: callId,
        );
      }
    } catch (e) {
      debugPrint('Error marking call as missed: $e');
    }
  }

  Future<void> _recordCallMessage({
    required String callerId,
    required String receiverId,
    required String callType,
    required String status,
    int? duration,
    required String callId,
  }) async {
    final supabase = _supabase;
    if (supabase == null) return;
    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      // Prevent duplicate call messages
      final existing = await supabase
          .from('messages')
          .select('id')
          .eq('message_type', 'call')
          .like('media_url', '%$callId%')
          .maybeSingle();
      if (existing != null) return;

      final isAudio = callType == 'audio';
      final typeLabel = isAudio ? 'Voice Call' : 'Video Call';

      final payload = jsonEncode({
        'call_id': callId,
        'call_type': callType,
        'status': status,
        'duration': duration ?? 0,
        'caller_id': callerId,
        'receiver_id': receiverId,
      });

      // Sender must be auth.uid() according to RLS INSERT policy
      final targetReceiver = myId == callerId ? receiverId : callerId;

      await supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': targetReceiver,
        'content': typeLabel,
        'message_type': 'call',
        'media_url': payload,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording in-chat call message: $e');
    }
  }

  Stream<List<Call>> watchIncomingCalls() {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return const Stream.empty();

    return supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', myId)
        .map(
          (data) => data
              .where((json) => json['status'] == 'ringing')
              .map(Call.fromMap)
              .toList(),
        );
  }

  Stream<Call?> watchCall(String callId) {
    final supabase = _supabase;
    if (supabase == null) return const Stream.empty();

    return supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((data) => data.isNotEmpty ? Call.fromMap(data.first) : null);
  }

  Future<Call?> getCallById(String callId) async {
    final supabase = _supabase;
    if (supabase == null) return null;

    try {
      final response = await supabase
          .from('calls')
          .select()
          .eq('id', callId)
          .single();

      return Call.fromMap(response);
    } catch (e) {
      debugPrint('Error getting call: $e');
      return null;
    }
  }

  Future<List<Call>> getCallHistory() async {
    final supabase = _supabase;
    if (supabase == null) return [];

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return [];

    try {
      final response = await supabase
          .from('calls')
          .select(
            '*, caller_profile:profiles!calls_caller_id_fkey(*), receiver_profile:profiles!calls_receiver_id_fkey(*)',
          )
          .or('caller_id.eq.$myId,receiver_id.eq.$myId')
          .order('started_at', ascending: false)
          .limit(100);

      return response.map((json) {
        final call = Call.fromMap(json);
        return call.copyWith(
          callerProfile: json['caller_profile'],
          receiverProfile: json['receiver_profile'],
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting call history: $e');
      return [];
    }
  }

  Future<void> deleteCall(String callId) async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      await supabase.from('calls').delete().eq('id', callId);
    } catch (e) {
      debugPrint('Error deleting call: $e');
    }
  }

  Future<void> clearAllCallHistory() async {
    final supabase = _supabase;
    if (supabase == null) return;

    final myId = supabase.auth.currentUser?.id;
    if (myId == null) return;

    try {
      await supabase
          .from('calls')
          .delete()
          .or('caller_id.eq.$myId,receiver_id.eq.$myId');
    } catch (e) {
      debugPrint('Error clearing call history: $e');
    }
  }

  Future<bool> isUserInCall(String userId) async {
    final supabase = _supabase;
    if (supabase == null) return false;

    try {
      final response = await supabase
          .from('calls')
          .select()
          .or('caller_id.eq.$userId,receiver_id.eq.$userId')
          .eq('status', 'ongoing')
          .maybeSingle();

      return response != null;
    } catch (e) {
      return false;
    }
  }
}

final incomingCallsProvider = StreamProvider<List<Call>>((ref) {
  final repository = ref.watch(callRepositoryProvider);
  return repository.watchIncomingCalls();
});
