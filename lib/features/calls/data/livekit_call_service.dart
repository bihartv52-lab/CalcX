import 'dart:async';
import 'package:calcx/app/app_env.dart';
import 'package:calcx/features/calls/domain/call_participant.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as rtc;
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

enum CallConnectionState {
  idle,
  connecting,
  connected,
  reconnecting,
  disconnected,
}

final liveKitCallServiceProvider = Provider<LiveKitCallService>((ref) {
  return LiveKitCallService(ref.watch(appEnvProvider));
});

class LiveKitCallService {
  LiveKitCallService(this._env);

  final AppEnv _env;
  Room? _room;
  CancelListenFunc? _cancelEventListen;

  Room? get room => _room;

  CallConnectionState _connectionState = CallConnectionState.idle;
  CallConnectionState get connectionState => _connectionState;
  final ValueNotifier<CallConnectionState> connectionStateNotifier =
      ValueNotifier<CallConnectionState>(CallConnectionState.idle);

  ConnectionQuality _networkQuality = ConnectionQuality.good;
  ConnectionQuality get networkQuality => _networkQuality;
  final ValueNotifier<ConnectionQuality> networkQualityNotifier =
      ValueNotifier<ConnectionQuality>(ConnectionQuality.good);

  Future<void> joinRoom({
    required String roomName,
    required String token,
    bool video = false,
  }) async {
    if (!_env.hasLiveKitConfig) {
      throw StateError('LiveKit URL is not configured.');
    }

    if (!kIsWeb) {
      try {
        final permissions = [
          Permission.microphone,
          Permission.bluetoothConnect,
        ];
        if (video) {
          permissions.add(Permission.camera);
        }
        await permissions.request();
      } catch (e) {
        debugPrint('Error requesting permissions for room join: $e');
      }
    }

    // High-stability mobile configuration:
    // - presetSpeech (24kbps) avoids choking the connection unlike 128kbps stereo music
    // - DTX: discontinuous transmission prevents packet flood during silence
    // - RED: redundant audio recovery avoids voice cutouts on lossy cellular
    // - fastPublish: false prevents sending media before ICE negotiation finishes (crucial on cellular)
    // - Dynacast & AdaptiveStream automatically scale bandwidth to actual UI needs
    // - Simulcast enables fallback layers so video never stalls audio
    _room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        fastPublish: false,
        defaultAudioCaptureOptions: AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
          highPassFilter: true,
          typingNoiseDetection: true,
        ),
        defaultAudioPublishOptions: AudioPublishOptions(
          encoding: AudioEncoding.presetSpeech,
          dtx: true,
          red: true,
        ),
        defaultVideoPublishOptions: VideoPublishOptions(
          simulcast: true,
          videoCodec: 'VP8',
          degradationPreference: DegradationPreference.maintainFramerate,
          videoEncoding: VideoEncoding(
            maxBitrate: 800 * 1000,
            maxFramerate: 25,
          ),
        ),
        defaultCameraCaptureOptions: CameraCaptureOptions(
          params: VideoParametersPresets.h540_169,
        ),
      ),
    );

    // Listen to network & reconnection events
    _cancelEventListen?.call();
    _cancelEventListen = _room!.events.listen((event) {
      if (event is RoomReconnectingEvent) {
        debugPrint('[LiveKit] Network dropped, reconnecting...');
        _connectionState = CallConnectionState.reconnecting;
        connectionStateNotifier.value = CallConnectionState.reconnecting;
      } else if (event is RoomReconnectedEvent) {
        debugPrint('[LiveKit] Reconnected successfully!');
        _connectionState = CallConnectionState.connected;
        connectionStateNotifier.value = CallConnectionState.connected;
      } else if (event is RoomDisconnectedEvent) {
        debugPrint('[LiveKit] Disconnected: ${event.reason}');
        _connectionState = CallConnectionState.disconnected;
        connectionStateNotifier.value = CallConnectionState.disconnected;
      } else if (event is ParticipantConnectionQualityUpdatedEvent) {
        if (event.participant == _room?.localParticipant) {
          _networkQuality = event.connectionQuality;
          networkQualityNotifier.value = event.connectionQuality;
        }
      }
    });

    _connectionState = CallConnectionState.connecting;
    connectionStateNotifier.value = CallConnectionState.connecting;

    try {
      await _room!.connect(
        _env.liveKitUrl,
        token,
        connectOptions: const ConnectOptions(
          autoSubscribe: true,
          timeouts: Timeouts.defaultTimeouts,
          rtcConfiguration: RTCConfiguration(
            iceServers: [
              RTCIceServer(urls: [
                'stun:stun.l.google.com:19302',
                'stun:stun1.l.google.com:19302',
                'stun:stun2.l.google.com:19302',
              ]),
            ],
            iceCandidatePoolSize: 2,
            isDscpEnabled: true,
          ),
        ),
      );

      _connectionState = CallConnectionState.connected;
      connectionStateNotifier.value = CallConnectionState.connected;
    } catch (e) {
      _connectionState = CallConnectionState.disconnected;
      connectionStateNotifier.value = CallConnectionState.disconnected;
      rethrow;
    }
    
    final localParticipant = _room!.localParticipant;
    if (localParticipant == null) {
      await _room!.disconnect();
      _room = null;
      _connectionState = CallConnectionState.disconnected;
      connectionStateNotifier.value = CallConnectionState.disconnected;
      throw StateError('LiveKit local participant is unavailable.');
    }

    await localParticipant.setMicrophoneEnabled(true);
    await localParticipant.setCameraEnabled(
      video,
      cameraCaptureOptions: const CameraCaptureOptions(
        params: VideoParametersPresets.h540_169,
      ),
    );
  }

  Future<void> leaveRoom() async {
    _cancelEventListen?.call();
    _cancelEventListen = null;
    await _room?.disconnect();
    _room = null;
    _connectionState = CallConnectionState.disconnected;
    connectionStateNotifier.value = CallConnectionState.disconnected;
    try {
      await Hardware.instance.setSpeakerphoneOn(false);
    } catch (_) {}
  }

  Future<void> toggleMicrophone() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      final isEnabled = localParticipant.isMicrophoneEnabled();
      await localParticipant.setMicrophoneEnabled(!isEnabled);
    }
  }

  Future<void> toggleCamera() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      final isEnabled = localParticipant.isCameraEnabled();
      await localParticipant.setCameraEnabled(
        !isEnabled,
        cameraCaptureOptions: const CameraCaptureOptions(
          params: VideoParametersPresets.h540_169,
        ),
      );
    }
  }

  Future<void> switchCamera() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) return;

    final pub = localParticipant.videoTrackPublications
        .where((p) => p.source == TrackSource.camera)
        .firstOrNull;
    final track = pub?.track;
    if (track is! LocalVideoTrack) return;

    try {
      final devices = await Hardware.instance.enumerateDevices(type: 'videoinput');
      if (devices.isEmpty) return;
      if (devices.length < 2) return;

      final settings = track.mediaStreamTrack.getSettings();
      final currentDeviceId = settings['deviceId'] as String?;

      final String nextDeviceId;
      if (currentDeviceId != null) {
        final nextDevice = devices.firstWhere(
          (d) => d.deviceId != currentDeviceId,
          orElse: () => devices.first,
        );
        nextDeviceId = nextDevice.deviceId;
      } else {
        nextDeviceId = devices.length > 1 ? devices[1].deviceId : devices[0].deviceId;
      }

      await track.switchCamera(nextDeviceId);
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  Future<void> toggleScreenShare() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      final isEnabled = localParticipant.isScreenShareEnabled();
      await localParticipant.setScreenShareEnabled(!isEnabled);
    }
  }

  Future<void> setAudioOutputRoute(AudioOutputRoute route) async {
    if (kIsWeb) return;
    try {
      switch (route) {
        case AudioOutputRoute.deviceSpeaker:
          await Hardware.instance.setSpeakerphoneOn(true);
          break;
        case AudioOutputRoute.earSpeaker:
          await Hardware.instance.setSpeakerphoneOn(false);
          break;
        case AudioOutputRoute.bluetoothHeadset:
          try {
            final devices = await Hardware.instance.enumerateDevices(type: 'audiooutput');
            final btDevice = devices.firstWhere(
              (d) {
                final label = d.label.toLowerCase();
                return label.contains('bluetooth') || label.contains('headset') || label.contains('hands-free');
              },
              orElse: () => devices.isNotEmpty ? devices.first : const MediaDevice('', 'bluetooth', 'audiooutput', ''),
            );
            if (btDevice.deviceId.isNotEmpty) {
              await Hardware.instance.selectAudioOutput(btDevice);
            } else {
              await Hardware.instance.setSpeakerphoneOn(false);
            }
          } catch (_) {
            await Hardware.instance.setSpeakerphoneOn(false);
          }
          break;
      }
    } catch (e) {
      debugPrint('Error setting audio output route $route: $e');
    }
  }

  Future<void> setParticipantVolume(String participantId, double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    final room = _room;
    if (room == null) return;

    try {
      RemoteParticipant? participant;
      for (final p in room.remoteParticipants.values) {
        if (p.identity == participantId || p.sid == participantId) {
          participant = p;
          break;
        }
      }
      participant ??= room.remoteParticipants[participantId];

      // Fallback 1: Direct 1-on-1 call with exactly 1 remote participant
      if (participant == null && room.remoteParticipants.length == 1) {
        participant = room.remoteParticipants.values.first;
      }

      // Fallback 2: Substring or containment match
      if (participant == null && room.remoteParticipants.isNotEmpty) {
        for (final p in room.remoteParticipants.values) {
          if (p.identity.contains(participantId) || participantId.contains(p.identity)) {
            participant = p;
            break;
          }
        }
      }

      // If resolved participant, adjust their audio tracks
      if (participant != null) {
        for (final pub in participant.audioTrackPublications) {
          final track = pub.track;
          if (track != null) {
            if (!kIsWeb) {
              try {
                await rtc.Helper.setVolume(clamped, track.mediaStreamTrack);
              } catch (volErr) {
                debugPrint('rtc.Helper.setVolume error: $volErr');
              }
            }
            try {
              track.mediaStreamTrack.enabled = clamped > 0.0;
            } catch (_) {}
          }
        }
      } else {
        // Fallback 3: Apply volume to all remote audio tracks in the call
        for (final p in room.remoteParticipants.values) {
          for (final pub in p.audioTrackPublications) {
            final track = pub.track;
            if (track != null) {
              if (!kIsWeb) {
                try {
                  await rtc.Helper.setVolume(clamped, track.mediaStreamTrack);
                } catch (volErr) {
                  debugPrint('rtc.Helper.setVolume error: $volErr');
                }
              }
              try {
                track.mediaStreamTrack.enabled = clamped > 0.0;
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error setting track volume for $participantId: $e');
    }
  }
}

