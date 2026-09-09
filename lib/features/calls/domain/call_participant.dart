import 'package:flutter/foundation.dart';

/// Audio Output Route enum for Sound Controls (R3)
enum AudioOutputRoute {
  deviceSpeaker,
  earSpeaker,
  bluetoothHeadset,
}

/// Call Participant Model for Call Sound Controls (R3)
class CallParticipant {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final bool isMuted;
  final double volume; // Range 0.0 to 1.0
  final double audioLevel; // Range 0.0 to 1.0

  const CallParticipant({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.isMuted = false,
    this.volume = 1.0,
    this.audioLevel = 0.0,
  });

  bool get isSpeaking => !isMuted && audioLevel > 0.15;

  CallParticipant copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    bool? isMuted,
    double? volume,
    double? audioLevel,
  }) {
    return CallParticipant(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isMuted: isMuted ?? this.isMuted,
      volume: volume ?? this.volume,
      audioLevel: audioLevel ?? this.audioLevel,
    );
  }
}

/// Call Sound Control Manager helper for Call Sessions (R3)
class CallSoundControlManager {
  final Map<String, CallParticipant> _participants = {};
  AudioOutputRoute _activeAudioRoute = AudioOutputRoute.deviceSpeaker;
  bool _isBluetoothAvailable = false;

  Map<String, CallParticipant> get participants => Map.unmodifiable(_participants);
  AudioOutputRoute get activeAudioRoute => _activeAudioRoute;
  bool get isBluetoothAvailable => _isBluetoothAvailable;

  void addParticipant(CallParticipant participant) {
    _participants[participant.id] = participant;
  }

  void removeParticipant(String participantId) {
    _participants.remove(participantId);
  }

  void setParticipantVolume(String participantId, double volume) {
    final participant = _participants[participantId];
    if (participant == null) return;

    final clampedVolume = volume.clamp(0.0, 1.0);
    final autoMuted = clampedVolume == 0.0;

    _participants[participantId] = participant.copyWith(
      volume: clampedVolume,
      isMuted: autoMuted ? true : (participant.isMuted && clampedVolume > 0.0 ? false : participant.isMuted),
    );
  }

  void toggleParticipantMute(String participantId) {
    final participant = _participants[participantId];
    if (participant == null) return;

    final newMute = !participant.isMuted;
    _participants[participantId] = participant.copyWith(
      isMuted: newMute,
      volume: newMute ? 0.0 : (participant.volume == 0.0 ? 0.8 : participant.volume),
    );
  }

  void selectAudioRoute(AudioOutputRoute route) {
    if (route == AudioOutputRoute.bluetoothHeadset && !_isBluetoothAvailable) {
      _activeAudioRoute = AudioOutputRoute.deviceSpeaker;
      return;
    }
    _activeAudioRoute = route;
  }

  void setBluetoothAvailable(bool available) {
    _isBluetoothAvailable = available;
    if (!available && _activeAudioRoute == AudioOutputRoute.bluetoothHeadset) {
      _activeAudioRoute = AudioOutputRoute.deviceSpeaker;
    }
  }

  void cycleAudioRoute() {
    switch (_activeAudioRoute) {
      case AudioOutputRoute.deviceSpeaker:
        selectAudioRoute(AudioOutputRoute.earSpeaker);
        break;
      case AudioOutputRoute.earSpeaker:
        selectAudioRoute(_isBluetoothAvailable ? AudioOutputRoute.bluetoothHeadset : AudioOutputRoute.deviceSpeaker);
        break;
      case AudioOutputRoute.bluetoothHeadset:
        selectAudioRoute(AudioOutputRoute.deviceSpeaker);
        break;
    }
  }
}
