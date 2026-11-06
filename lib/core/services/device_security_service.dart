import 'dart:async';
import 'dart:io' show Platform;
import 'package:calcx/core/models/user_device.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final deviceSecurityServiceProvider = Provider<DeviceSecurityService>((ref) {
  return DeviceSecurityService();
});

final currentDeviceIdProvider = FutureProvider<String>((ref) async {
  return ref.watch(deviceSecurityServiceProvider).getDeviceId();
});

final myProfileSecurityStreamProvider = StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
  final client = SupabaseService.clientOrNull;
  if (client == null) return const Stream.empty();
  final myId = client.auth.currentUser?.id;
  if (myId == null) return const Stream.empty();

  return client
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', myId)
      .map((data) => data.isNotEmpty ? data.first : null);
});

final userDevicesStreamProvider = StreamProvider.autoDispose<List<UserDevice>>((ref) {
  final service = ref.watch(deviceSecurityServiceProvider);
  return service.watchUserDevices();
});

class DeviceSecurityService {
  static const String _deviceIdPrefKey = 'calcx_device_unique_id';
  static const String _loginTimestampPrefKey = 'calcx_login_timestamp';
  
  static String? _cachedDeviceId;
  RealtimeChannel? _deviceSessionChannel;

  /// Get or create a unique stable device UUID
  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) return _cachedDeviceId!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_deviceIdPrefKey);
    if (id == null || id.isEmpty) {
      id = const Uuid().v4();
      await prefs.setString(_deviceIdPrefKey, id);
    }
    _cachedDeviceId = id;
    return id;
  }

  /// Resolve human-readable device name & OS (e.g. "Samsung Galaxy S23", "Android 14")
  Future<Map<String, String>> getDeviceInfo() async {
    final plugin = DeviceInfoPlugin();
    String deviceName = 'Unknown Device';
    String deviceOs = 'Unknown OS';

    try {
      if (kIsWeb) {
        final webInfo = await plugin.webBrowserInfo;
        final browser = webInfo.browserName.name.toUpperCase();
        final platform = webInfo.platform ?? 'Web';
        deviceName = '$browser on $platform';
        deviceOs = 'Web Browser';
      } else if (Platform.isAndroid) {
        final android = await plugin.androidInfo;
        final brand = _capitalize(android.brand.isNotEmpty ? android.brand : android.manufacturer);
        final model = android.model;
        deviceName = model.startsWith(brand) ? model : '$brand $model';
        deviceOs = 'Android ${android.version.release} (API ${android.version.sdkInt})';
      } else if (Platform.isIOS) {
        final ios = await plugin.iosInfo;
        deviceName = ios.name.isNotEmpty ? ios.name : ios.utsname.machine;
        deviceOs = '${ios.systemName} ${ios.systemVersion}';
      } else if (Platform.isWindows) {
        final win = await plugin.windowsInfo;
        deviceName = win.computerName.isNotEmpty ? win.computerName : 'Windows PC';
        deviceOs = 'Windows ${win.displayVersion}';
      } else if (Platform.isMacOS) {
        final mac = await plugin.macOsInfo;
        deviceName = mac.computerName.isNotEmpty ? mac.computerName : 'Apple Mac';
        deviceOs = 'macOS ${mac.osRelease}';
      } else if (Platform.isLinux) {
        final linux = await plugin.linuxInfo;
        deviceName = linux.name.isNotEmpty ? linux.name : 'Linux PC';
        deviceOs = linux.version ?? 'Linux';
      }
    } catch (e) {
      debugPrint('Error getting device info: $e');
      deviceName = kIsWeb ? 'Web Browser' : 'Mobile Device';
      deviceOs = kIsWeb ? 'Web' : Platform.operatingSystem;
    }

    return {
      'name': deviceName,
      'os': deviceOs,
    };
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Register or heartbeat the current device upon app start / login.
  /// If it's a new device, it also creates an in-app security notification.
  Future<void> registerOrHeartbeatDevice() async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final deviceId = await getDeviceId();
      final info = await getDeviceInfo();
      final deviceName = info['name'] ?? 'Device';
      final deviceOs = info['os'] ?? 'Unknown OS';
      final now = DateTime.now();

      // Check if device already registered for this user
      final existing = await supabase
          .from('user_devices')
          .select('id, is_active_chat')
          .eq('user_id', user.id)
          .eq('device_id', deviceId)
          .maybeSingle();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_loginTimestampPrefKey, now.toIso8601String());

      if (existing == null) {
        // 1. BRAND NEW DEVICE LOGIN: Insert into user_devices
        await supabase.from('user_devices').insert({
          'user_id': user.id,
          'device_id': deviceId,
          'device_name': deviceName,
          'device_os': deviceOs,
          'is_active_chat': true, // Auto-claim chat on initial login if first
          'last_active': now.toIso8601String(),
          'created_at': now.toIso8601String(),
        });

        // 2. Also ensure profile has active chat device if none is set
        final profile = await supabase
            .from('profiles')
            .select('active_chat_device_id')
            .eq('id', user.id)
            .maybeSingle();

        if (profile?['active_chat_device_id'] == null) {
          await supabase.from('profiles').update({
            'active_chat_device_id': deviceId,
            'active_chat_device_name': deviceName,
            'active_chat_updated_at': now.toIso8601String(),
          }).eq('id', user.id);
        }

        // 3. Create In-App Security Notification for new login alert
        final formattedTime = DateFormat('hh:mm a, MMM d').format(now);
        await supabase.from('notifications').insert({
          'user_id': user.id,
          'type': 'new_login',
          'title': 'New Login Detected 🛡️',
          'body': 'Your account was accessed from $deviceName ($deviceOs) at $formattedTime. If this was not you, review active devices in Settings.',
          'data': {
            'device_id': deviceId,
            'device_name': deviceName,
            'device_os': deviceOs,
            'login_time': now.toIso8601String(),
          },
          'read': false,
          'created_at': now.toIso8601String(),
        });
      } else {
        // Existing device heartbeat update
        await supabase.from('user_devices').update({
          'device_name': deviceName,
          'device_os': deviceOs,
          'last_active': now.toIso8601String(),
        }).eq('user_id', user.id).eq('device_id', deviceId);
      }
    } catch (e) {
      debugPrint('Error registering device: $e');
    }
  }

  /// Validate whether current device session is still valid.
  /// Returns false if session was revoked remotely or user was force-logged out.
  Future<bool> checkSessionValidity() async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return true;

    final user = supabase.auth.currentUser;
    if (user == null) return false;

    try {
      final deviceId = await getDeviceId();

      // Check force_logout_at from profile
      final profile = await supabase
          .from('profiles')
          .select('force_logout_at')
          .eq('id', user.id)
          .maybeSingle();

      if (profile != null && profile['force_logout_at'] != null) {
        final forceLogoutAt = DateTime.parse(profile['force_logout_at'] as String);
        final prefs = await SharedPreferences.getInstance();
        final loginTimeStr = prefs.getString(_loginTimestampPrefKey);
        if (loginTimeStr != null) {
          final loginTime = DateTime.tryParse(loginTimeStr);
          if (loginTime != null && loginTime.isBefore(forceLogoutAt)) {
            // Logged in before force logout timestamp
            return false;
          }
        } else {
          // Legacy session without login timestamp
          return false;
        }
      }

      // Check if device is still present in user_devices
      final deviceRow = await supabase
          .from('user_devices')
          .select('id')
          .eq('user_id', user.id)
          .eq('device_id', deviceId)
          .maybeSingle();

      if (deviceRow == null) {
        // Device was remotely logged out / deleted!
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Error checking session validity: $e');
      return true; // Keep open on temporary network error
    }
  }

  /// Listen in real time for session revocation (if another device deletes this device)
  void listenToSessionRevocation(VoidCallback onRevoked) async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return;

    final user = supabase.auth.currentUser;
    if (user == null) return;

    final deviceId = await getDeviceId();

    _deviceSessionChannel?.unsubscribe();
    _deviceSessionChannel = supabase.channel('device_session_${user.id}_$deviceId');

    _deviceSessionChannel!.onPostgresChanges(
      event: PostgresChangeEvent.delete,
      schema: 'public',
      table: 'user_devices',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'device_id',
        value: deviceId,
      ),
      callback: (payload) {
        debugPrint('Device session was remotely revoked!');
        onRevoked();
      },
    ).subscribe();
  }

  void stopListeningToRevocation() {
    if (_deviceSessionChannel != null) {
      SupabaseService.clientOrNull?.removeChannel(_deviceSessionChannel!);
      _deviceSessionChannel = null;
    }
  }

  /// Watch all logged-in devices for the current user
  Stream<List<UserDevice>> watchUserDevices() {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return const Stream.empty();

    final user = supabase.auth.currentUser;
    if (user == null) return const Stream.empty();

    final controller = StreamController<List<UserDevice>>.broadcast();

    void fetchDevices() async {
      try {
        final response = await supabase
            .from('user_devices')
            .select()
            .eq('user_id', user.id)
            .order('last_active', ascending: false);

        if (!controller.isClosed) {
          final list = (response as List)
              .map((e) => UserDevice.fromMap(e as Map<String, dynamic>))
              .toList();
          controller.add(list);
        }
      } catch (e) {
        debugPrint('Error fetching user devices: $e');
      }
    }

    fetchDevices();

    final channel = supabase.channel('user_devices_${user.id}')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'user_devices',
        callback: (_) => fetchDevices(),
      ).subscribe();

    controller.onCancel = () {
      supabase.removeChannel(channel);
      controller.close();
    };

    return controller.stream;
  }

  /// Log out a specific device
  Future<void> logoutDevice(String targetDeviceId) async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    await supabase
        .from('user_devices')
        .delete()
        .eq('user_id', user.id)
        .eq('device_id', targetDeviceId);
  }

  /// Log out of all other sessions except this current device
  Future<void> logoutAllOtherDevices() async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final myDeviceId = await getDeviceId();

    await supabase
        .from('user_devices')
        .delete()
        .eq('user_id', user.id)
        .neq('device_id', myDeviceId);
  }

  /// SINGLE ACTIVE CHAT ENFORCEMENT:
  /// Switch / claim active chat device for this account.
  Future<void> switchChatToThisDevice() async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final deviceId = await getDeviceId();
    final info = await getDeviceInfo();
    final deviceName = info['name'] ?? 'This Device';
    final now = DateTime.now().toIso8601String();

    // 1. Update profiles table
    await supabase.from('profiles').update({
      'active_chat_device_id': deviceId,
      'active_chat_device_name': deviceName,
      'active_chat_updated_at': now,
    }).eq('id', user.id);

    // 2. Update user_devices table
    await supabase.from('user_devices').update({
      'is_active_chat': false,
    }).eq('user_id', user.id);

    await supabase.from('user_devices').update({
      'is_active_chat': true,
      'last_active': now,
    }).eq('user_id', user.id).eq('device_id', deviceId);
  }

  /// Check if this device is the authorized active chat device
  Future<bool> isThisDeviceActiveChat() async {
    final supabase = SupabaseService.clientOrNull;
    if (supabase == null) return true;
    final user = supabase.auth.currentUser;
    if (user == null) return true;

    final myDeviceId = await getDeviceId();

    try {
      final profile = await supabase
          .from('profiles')
          .select('active_chat_device_id')
          .eq('id', user.id)
          .maybeSingle();

      final activeId = profile?['active_chat_device_id'] as String?;
      if (activeId == null || activeId.isEmpty || activeId == myDeviceId) {
        return true;
      }
      return false;
    } catch (_) {
      return true;
    }
  }
}
