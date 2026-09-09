import 'dart:async';
import 'package:calcx/app/app_env.dart';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/core/services/livekit_token_service.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/data/livekit_call_service.dart';
import 'package:calcx/features/calls/domain/call_participant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

class CallSession {
  final Call call;
  final LiveKitCallService callService;
  final DateTime startTime;
  bool isMuted;
  bool isVideoOn;
  bool isScreenSharing;
  AudioOutputRoute activeAudioRoute;
  bool isBluetoothAvailable;
  Map<String, double> participantVolumes;
  Map<String, bool> participantMuted;
  List<CallParticipant> participants;

  CallSession({
    required this.call,
    required this.callService,
    required this.startTime,
    this.isMuted = false,
    bool isSpeakerOn = true,
    this.isVideoOn = false,
    this.isScreenSharing = false,
    AudioOutputRoute? activeAudioRoute,
    this.isBluetoothAvailable = false,
    this.participantVolumes = const {},
    this.participantMuted = const {},
    this.participants = const [],
  }) : activeAudioRoute = activeAudioRoute ?? (isSpeakerOn ? AudioOutputRoute.deviceSpeaker : AudioOutputRoute.earSpeaker);

  bool get isSpeakerOn => activeAudioRoute == AudioOutputRoute.deviceSpeaker;

  CallSession copyWith({
    Call? call,
    LiveKitCallService? callService,
    DateTime? startTime,
    bool? isMuted,
    bool? isSpeakerOn,
    bool? isVideoOn,
    bool? isScreenSharing,
    AudioOutputRoute? activeAudioRoute,
    bool? isBluetoothAvailable,
    Map<String, double>? participantVolumes,
    Map<String, bool>? participantMuted,
    List<CallParticipant>? participants,
  }) {
    final effectiveRoute = activeAudioRoute ?? (isSpeakerOn != null ? (isSpeakerOn ? AudioOutputRoute.deviceSpeaker : AudioOutputRoute.earSpeaker) : this.activeAudioRoute);
    return CallSession(
      call: call ?? this.call,
      callService: callService ?? this.callService,
      startTime: startTime ?? this.startTime,
      isMuted: isMuted ?? this.isMuted,
      isVideoOn: isVideoOn ?? this.isVideoOn,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      activeAudioRoute: effectiveRoute,
      isBluetoothAvailable: isBluetoothAvailable ?? this.isBluetoothAvailable,
      participantVolumes: participantVolumes ?? Map.from(this.participantVolumes),
      participantMuted: participantMuted ?? Map.from(this.participantMuted),
      participants: participants ?? List.from(this.participants),
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
    if (!kIsWeb) {
      try {
        await Hardware.instance.setSpeakerphoneOn(true);
      } catch (e) {
        debugPrint('Error setting initial speakerphone: $e');
      }
    }

    // Build initial participant list
    final otherId = call.callerId == myId ? call.receiverId : call.callerId;
    final otherProfile = call.callerId == myId ? call.receiverProfile : call.callerProfile;
    final otherName = otherProfile?['display_name'] as String? ?? otherProfile?['username'] as String? ?? 'Participant';
    final otherAvatar = otherProfile?['avatar_url'] as String?;

    final initialParticipants = [
      CallParticipant(
        id: otherId,
        displayName: otherName,
        avatarUrl: otherAvatar,
        volume: 1.0,
      ),
    ];

    state = CallSession(
      call: call,
      callService: callService,
      startTime: DateTime.now(),
      isVideoOn: call.isVideo,
      activeAudioRoute: AudioOutputRoute.deviceSpeaker,
      participants: initialParticipants,
      participantVolumes: {otherId: 1.0},
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
    final newRoute = current.isSpeakerOn ? AudioOutputRoute.earSpeaker : AudioOutputRoute.deviceSpeaker;
    await selectAudioRoute(newRoute);
  }

  Future<void> selectAudioRoute(AudioOutputRoute route) async {
    final current = state;
    if (current == null) return;

    AudioOutputRoute targetRoute = route;
    if (route == AudioOutputRoute.bluetoothHeadset && !current.isBluetoothAvailable) {
      targetRoute = AudioOutputRoute.deviceSpeaker;
    }

    await current.callService.setAudioOutputRoute(targetRoute);
    state = current.copyWith(activeAudioRoute: targetRoute);
  }

  Future<void> cycleAudioRoute() async {
    final current = state;
    if (current == null) return;

    switch (current.activeAudioRoute) {
      case AudioOutputRoute.deviceSpeaker:
        await selectAudioRoute(AudioOutputRoute.earSpeaker);
        break;
      case AudioOutputRoute.earSpeaker:
        await selectAudioRoute(
          current.isBluetoothAvailable ? AudioOutputRoute.bluetoothHeadset : AudioOutputRoute.deviceSpeaker,
        );
        break;
      case AudioOutputRoute.bluetoothHeadset:
        await selectAudioRoute(AudioOutputRoute.deviceSpeaker);
        break;
    }
  }

  void setBluetoothAvailable(bool available) {
    final current = state;
    if (current == null) return;

    AudioOutputRoute route = current.activeAudioRoute;
    if (!available && route == AudioOutputRoute.bluetoothHeadset) {
      route = AudioOutputRoute.deviceSpeaker;
      current.callService.setAudioOutputRoute(AudioOutputRoute.deviceSpeaker);
    }
    state = current.copyWith(
      isBluetoothAvailable: available,
      activeAudioRoute: route,
    );
  }

  Future<void> setParticipantVolume(String participantId, double volume) async {
    final current = state;
    if (current == null) return;

    final clampedVolume = volume.clamp(0.0, 1.0);
    final autoMuted = clampedVolume == 0.0;

    final newVolumes = Map<String, double>.from(current.participantVolumes)..[participantId] = clampedVolume;
    final newMuted = Map<String, bool>.from(current.participantMuted);
    if (autoMuted) {
      newMuted[participantId] = true;
    } else if (newMuted[participantId] == true && clampedVolume > 0.0) {
      newMuted[participantId] = false;
    }

    final updatedParticipants = current.participants.map((p) {
      if (p.id == participantId) {
        return p.copyWith(
          volume: clampedVolume,
          isMuted: autoMuted ? true : (p.isMuted && clampedVolume > 0.0 ? false : p.isMuted),
        );
      }
      return p;
    }).toList();

    state = current.copyWith(
      participantVolumes: newVolumes,
      participantMuted: newMuted,
      participants: updatedParticipants,
    );

    await current.callService.setParticipantVolume(participantId, clampedVolume);
  }

  Future<void> toggleParticipantMute(String participantId) async {
    final current = state;
    if (current == null) return;

    final isCurrentlyMuted = current.participantMuted[participantId] ?? false;
    final newMute = !isCurrentlyMuted;

    final currentVol = current.participantVolumes[participantId] ?? 1.0;
    final newVol = newMute ? 0.0 : (currentVol == 0.0 ? 0.8 : currentVol);

    await setParticipantVolume(participantId, newVol);
  }

  void addParticipant(CallParticipant participant) {
    final current = state;
    if (current == null) return;
    final exists = current.participants.any((p) => p.id == participant.id);
    if (exists) return;

    final updated = List<CallParticipant>.from(current.participants)..add(participant);
    final newVolumes = Map<String, double>.from(current.participantVolumes)..[participant.id] = participant.volume;
    final newMuted = Map<String, bool>.from(current.participantMuted)..[participant.id] = participant.isMuted;

    state = current.copyWith(
      participants: updated,
      participantVolumes: newVolumes,
      participantMuted: newMuted,
    );
  }

  void removeParticipant(String participantId) {
    final current = state;
    if (current == null) return;

    final updated = current.participants.where((p) => p.id != participantId).toList();
    final newVolumes = Map<String, double>.from(current.participantVolumes)..remove(participantId);
    final newMuted = Map<String, bool>.from(current.participantMuted)..remove(participantId);

    state = current.copyWith(
      participants: updated,
      participantVolumes: newVolumes,
      participantMuted: newMuted,
    );
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
