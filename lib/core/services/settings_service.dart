import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calcx/core/services/secure_storage_service.dart';

final biometricEnabledProvider =
    NotifierProvider<BiometricSettingNotifier, bool>(
  BiometricSettingNotifier.new,
);

class BiometricSettingNotifier extends Notifier<bool> {
  static const _key = 'calcx.settings.biometric_enabled';

  @override
  bool build() {
    _loadSetting();
    return false; // Default: fingerprint OFF
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _loadSetting() async {
    final value = await _storage.read(key: _key);
    state = value == 'true';
  }

  Future<void> toggle() async {
    state = !state;
    await _storage.write(key: _key, value: state.toString());
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(key: _key, value: enabled.toString());
  }
}

final blurInBackgroundProvider =
    NotifierProvider<BlurSettingNotifier, bool>(
  BlurSettingNotifier.new,
);

class BlurSettingNotifier extends Notifier<bool> {
  static const _key = 'calcx.settings.blur_in_background';

  @override
  bool build() {
    _loadSetting();
    return true; // Default: blur ON
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _loadSetting() async {
    final value = await _storage.read(key: _key);
    state = value != 'false'; // Default to true
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(key: _key, value: enabled.toString());
  }
}

final reduceMotionProvider =
    NotifierProvider<ReduceMotionSettingNotifier, bool>(
  ReduceMotionSettingNotifier.new,
);

class ReduceMotionSettingNotifier extends Notifier<bool> {
  static const _key = 'calcx.settings.reduce_motion';

  @override
  bool build() {
    _loadSetting();
    return false; // Default: reduce motion OFF
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _loadSetting() async {
    final value = await _storage.read(key: _key);
    state = value == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await _storage.write(key: _key, value: enabled.toString());
  }
}

final themeNameProvider = NotifierProvider<ThemeSettingNotifier, String>(
  ThemeSettingNotifier.new,
);

class ThemeSettingNotifier extends Notifier<String> {
  static const _key = 'calcx.settings.theme_name';

  @override
  String build() {
    _loadSetting();
    return 'sunset'; // Default: sunset
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _loadSetting() async {
    final value = await _storage.read(key: _key);
    if (value != null) {
      state = value;
    }
  }

  Future<void> setTheme(String themeName) async {
    state = themeName;
    await _storage.write(key: _key, value: themeName);
  }
}
