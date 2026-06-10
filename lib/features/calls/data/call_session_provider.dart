import 'dart:async';
import 'package:calcx/app/app_env.dart';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/core/services/livekit_token_service.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/data/livekit_call_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

class CallSession {
  final Call call;
  final LiveKitCallService callService;
  final DateTime startTime;
  bool isMuted;
  bool isSpeakerOn;
  bool isVideoOn;
  bool isScreenSharing;

  CallSession({
    required this.call,
    required this.callService,
    required this.startTime,
    this.isMuted = false,
    this.isSpeakerOn = true,
    this.isVideoOn = false,
    this.isScreenSharing = false,
  });

  CallSession copyWith({
    Call? call,
    LiveKitCallService? callService,
    DateTime? startTime,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isVideoOn,
    bool? isScreenSharing,
  }) {
    return CallSession(
      call: call ?? this.call,
      callService: callService ?? this.callService,
      startTime: startTime ?? this.startTime,
      isMuted: isMuted ?? this.isMuted,
      isSpeakerOn: isSpeakerOn ?? this.isSpeakerOn,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
    );
  }
}

class ActiveCallSessionNotifier extends Notifier<CallSession?> {
  StreamSubscription<Call?>? _statusSub;

  @override
  CallSession? build() {
    return null;
  }

  Future<void> startCallSession(Call call) async {
    // Clean up any existing call
    await endCurrentCall();

    final env = ref.read(appEnvProvider);
    final callService = LiveKitCallService(env);
    
    final repository = ref.read(callRepositoryProvider);
    final myId = repository.supabase?.auth.currentUser?.id;
    if (myId == null || call.roomName == null) return;
    
    final tokenService = ref.read(livekitTokenServiceProvider);
    final token = await tokenService.getToken(
      roomName: call.roomName!,
      participantName: myId,
    );

    await callService.joinRoom(
      roomName: call.roomName!,
      token: token,
      video: call.isVideo,
    );

    // Set default speakerphone
    try {
      await Hardware.instance.setSpeakerphoneOn(true);
    } catch (e) {
      debugPrint('Error setting initial speakerphone: $e');
    }

    state = CallSession(
      call: call,
      callService: callService,
      startTime: DateTime.now(),
      isVideoOn: call.isVideo,
    );

    // Watch status
    _statusSub = repository.watchCall(call.id).listen((updatedCall) {
      if (updatedCall == null) return;
      if (updatedCall.status == 'ended' ||
          updatedCall.status == 'rejected' ||
          updatedCall.status == 'missed') {
        endCurrentCall();
      }
    });
  }

  Future<void> endCurrentCall() async {
    final current = state;
    if (current == null) return;

    state = null;
    _statusSub?.cancel();
    _statusSub = null;

    try {
      final repository = ref.read(callRepositoryProvider);
      await repository.endCall(current.call.id, startTime: current.startTime);
      await current.callService.leaveRoom();
    } catch (e) {
      debugPrint('Error ending call: $e');
    }
  }

  Future<void> toggleMute() async {
    final current = state;
    if (current == null) return;
    await current.callService.toggleMicrophone();
    state = current.copyWith(isMuted: !current.isMuted);
  }

  Future<void> toggleSpeaker() async {
    final current = state;
    if (current == null) return;
    final newState = !current.isSpeakerOn;
    try {
      await Hardware.instance.setSpeakerphoneOn(newState);
      state = current.copyWith(isSpeakerOn: newState);
    } catch (e) {
      debugPrint('Error toggling speaker: $e');
    }
  }

  Future<void> toggleVideo() async {
    final current = state;
    if (current == null) return;
    await current.callService.toggleCamera();
    state = current.copyWith(isVideoOn: !current.isVideoOn);
  }

  Future<void> switchCamera() async {
    final current = state;
    if (current == null) return;
    await current.callService.switchCamera();
  }

  Future<void> toggleScreenShare() async {
    final current = state;
    if (current == null) return;
    await current.callService.toggleScreenShare();
    state = current.copyWith(isScreenSharing: !current.isScreenSharing);
  }
}

final activeCallSessionProvider = NotifierProvider<ActiveCallSessionNotifier, CallSession?>(
  ActiveCallSessionNotifier.new,
);

class CallScreenShowingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  @override
  set state(bool value) => super.state = value;
}

final isCallScreenShowingProvider = NotifierProvider<CallScreenShowingNotifier, bool>(
  CallScreenShowingNotifier.new,
);
