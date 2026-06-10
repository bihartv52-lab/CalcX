import 'package:calcx/app/app_env.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';

final liveKitCallServiceProvider = Provider<LiveKitCallService>((ref) {
  return LiveKitCallService(ref.watch(appEnvProvider));
});

class LiveKitCallService {
  LiveKitCallService(this._env);

  final AppEnv _env;
  Room? _room;

  Room? get room => _room;

  Future<void> joinRoom({
    required String roomName,
    required String token,
    bool video = false,
  }) async {
    if (!_env.hasLiveKitConfig) {
      throw StateError('LiveKit URL is not configured.');
    }

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

    _room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    
    await _room!.connect(_env.liveKitUrl, token);
    
    final localParticipant = _room!.localParticipant;
    if (localParticipant == null) {
      await _room!.disconnect();
      _room = null;
      throw StateError('LiveKit local participant is unavailable.');
    }

    await localParticipant.setMicrophoneEnabled(true);
    await localParticipant.setCameraEnabled(
      video,
      cameraCaptureOptions: CameraCaptureOptions(
        params: VideoParametersPresets.h720_169,
      ),
    );
  }

  Future<void> leaveRoom() async {
    await _room?.disconnect();
    _room = null;
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
        cameraCaptureOptions: CameraCaptureOptions(
          params: VideoParametersPresets.h720_169,
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
}
