import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

final permissionServiceProvider = Provider((ref) => PermissionService());

class PermissionService {
  /// Request camera permission
  Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  /// Request microphone permission
  Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  /// Request storage permission
  Future<bool> requestStorage() async {
    if (await Permission.storage.isPermanentlyDenied) {
      await openAppSettings();
      return false;
    }
    final status = await Permission.storage.request();
    return status.isGranted;
  }

  /// Request photos permission (Android 13+)
  Future<bool> requestPhotos() async {
    final status = await Permission.photos.request();
    return status.isGranted;
  }

  /// Request notification permission
  Future<bool> requestNotification() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// Request Bluetooth permissions (for audio routing on Android 12+)
  Future<bool> requestBluetooth() async {
    final results = await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ].request();
    return (results[Permission.bluetooth]?.isGranted ?? false) &&
        (results[Permission.bluetoothConnect]?.isGranted ?? false);
  }

  /// Request all media permissions at once
  Future<Map<String, bool>> requestAllMedia() async {
    final results = await [
      Permission.camera,
      Permission.microphone,
      Permission.photos,
      Permission.storage,
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ].request();

    return {
      'camera': results[Permission.camera]?.isGranted ?? false,
      'microphone': results[Permission.microphone]?.isGranted ?? false,
      'photos': results[Permission.photos]?.isGranted ?? false,
      'storage': results[Permission.storage]?.isGranted ?? false,
      'bluetoothConnect': results[Permission.bluetoothConnect]?.isGranted ?? false,
    };
  }

  /// Check if permission is granted
  Future<bool> isGranted(Permission permission) async {
    return await permission.isGranted;
  }

  /// Open app settings
  Future<void> openSettings() async {
    await openAppSettings();
  }
}
