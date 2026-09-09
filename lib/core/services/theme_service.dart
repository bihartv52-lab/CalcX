import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calcx/app/app_theme.dart';
import 'package:calcx/core/services/secure_storage_service.dart';
import 'package:calcx/core/utils/platform_file_helper.dart' as pf;
import 'package:image_picker/image_picker.dart';

class ThemeSettings {
  final String themeName; // 'cyberpunk', 'emerald', 'sunset', 'crimson', 'light', 'amoled', 'material_you', 'gallery'
  final String? globalWallpaperPath;
  final Map<String, String> chatWallpapers; // chatId -> wallpaperPath
  final double wallpaperOpacity;
  final double wallpaperBlur;
  final double wallpaperDim;
  final int? seedColorValue; // Color seed extracted

  ThemeSettings({
    this.themeName = 'sunset',
    this.globalWallpaperPath,
    this.chatWallpapers = const {},
    this.wallpaperOpacity = 0.8,
    this.wallpaperBlur = 0.0,
    this.wallpaperDim = 0.3,
    this.seedColorValue,
  });

  ThemeSettings copyWith({
    String? themeName,
    String? globalWallpaperPath,
    Map<String, String>? chatWallpapers,
    double? wallpaperOpacity,
    double? wallpaperBlur,
    double? wallpaperDim,
    int? seedColorValue,
  }) {
    return ThemeSettings(
      themeName: themeName ?? this.themeName,
      globalWallpaperPath: globalWallpaperPath ?? this.globalWallpaperPath,
      chatWallpapers: chatWallpapers ?? this.chatWallpapers,
      wallpaperOpacity: wallpaperOpacity ?? this.wallpaperOpacity,
      wallpaperBlur: wallpaperBlur ?? this.wallpaperBlur,
      wallpaperDim: wallpaperDim ?? this.wallpaperDim,
      seedColorValue: seedColorValue ?? this.seedColorValue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themeName': themeName,
      'globalWallpaperPath': globalWallpaperPath,
      'chatWallpapers': chatWallpapers,
      'wallpaperOpacity': wallpaperOpacity,
      'wallpaperBlur': wallpaperBlur,
      'wallpaperDim': wallpaperDim,
      'seedColorValue': seedColorValue,
    };
  }

  factory ThemeSettings.fromMap(Map<String, dynamic> map) {
    return ThemeSettings(
      themeName: map['themeName'] ?? 'sunset',
      globalWallpaperPath: map['globalWallpaperPath'],
      chatWallpapers: Map<String, String>.from(map['chatWallpapers'] ?? {}),
      wallpaperOpacity: (map['wallpaperOpacity'] as num?)?.toDouble() ?? 0.8,
      wallpaperBlur: (map['wallpaperBlur'] as num?)?.toDouble() ?? 0.0,
      wallpaperDim: (map['wallpaperDim'] as num?)?.toDouble() ?? 0.3,
      seedColorValue: map['seedColorValue'] as int?,
    );
  }

  String? getChatWallpaperPreset(String chatId) {
    return chatWallpapers[chatId];
  }

  Color resolveThreadPresetColor(String? chatId, {ThemeData? themeData}) {
    final preset = chatId != null ? chatWallpapers[chatId] : null;
    return AppTheme.resolveThreadPrimaryColor(threadPreset: preset, themeData: themeData);
  }
}

final themeServiceProvider =
    NotifierProvider<ThemeServiceNotifier, ThemeSettings>(
  ThemeServiceNotifier.new,
);

class ThemeServiceNotifier extends Notifier<ThemeSettings> {
  static const _storageKey = 'calcx.settings.theme_service_data';

  @override
  ThemeSettings build() {
    _loadSettings();
    return ThemeSettings();
  }

  FlutterSecureStorage get _storage => ref.read(secureStorageProvider);

  Future<void> _loadSettings() async {
    try {
      final jsonStr = await _storage.read(key: _storageKey);
      if (jsonStr != null) {
        state = ThemeSettings.fromMap(json.decode(jsonStr));
      }
    } catch (_) {}
  }

  Future<void> _saveSettings() async {
    try {
      await _storage.write(
        key: _storageKey,
        value: json.encode(state.toMap()),
      );
    } catch (_) {}
  }

  Future<void> setThemeName(String name) async {
    state = state.copyWith(themeName: name);
    await _saveSettings();
  }

  Future<void> setWallpaperSliders({
    double? opacity,
    double? blur,
    double? dim,
  }) async {
    state = state.copyWith(
      wallpaperOpacity: opacity,
      wallpaperBlur: blur,
      wallpaperDim: dim,
    );
    await _saveSettings();
  }

  Future<void> setSeedColor(Color color) async {
    state = state.copyWith(seedColorValue: color.value);
    await _saveSettings();
  }

  /// Saves a wallpaper file locally and sets it globally
  Future<void> setGlobalWallpaper(XFile originalFile) async {
    try {
      final savedPath = await pf.saveWallpaperLocally(originalFile, 'global_wallpaper.png');
      state = state.copyWith(
        globalWallpaperPath: savedPath,
        themeName: 'gallery',
      );
      await _saveSettings();
    } catch (_) {}
  }

  /// Saves a wallpaper file locally and sets it for a specific chat
  Future<void> setChatWallpaper(String chatId, XFile originalFile) async {
    try {
      final savedPath = await pf.saveWallpaperLocally(originalFile, 'chat_$chatId.png');
      final updatedChats = Map<String, String>.from(state.chatWallpapers);
      updatedChats[chatId] = savedPath;
      state = state.copyWith(chatWallpapers: updatedChats);
      await _saveSettings();
    } catch (_) {}
  }

  /// Sets a preset wallpaper for a specific chat without copying a file
  Future<void> setChatWallpaperPreset(String chatId, String presetName) async {
    try {
      final updatedChats = Map<String, String>.from(state.chatWallpapers);
      updatedChats[chatId] = presetName;
      state = state.copyWith(chatWallpapers: updatedChats);
      await _saveSettings();
    } catch (_) {}
  }

  /// Removes chat wallpaper
  Future<void> removeChatWallpaper(String chatId) async {
    final updatedChats = Map<String, String>.from(state.chatWallpapers);
    updatedChats.remove(chatId);
    state = state.copyWith(chatWallpapers: updatedChats);
    await _saveSettings();
  }

  /// Local Backup of Theme Configuration
  Future<String> exportBackup() async {
    final data = {
      'settings': state.toMap(),
      'backup_date': DateTime.now().toIso8601String(),
    };
    return await pf.exportThemeBackup(data);
  }

  /// Restore from Backup File
  Future<void> importBackup(String path) async {
    try {
      final data = await pf.importThemeBackup(path);
      if (data != null && data['settings'] != null) {
        state = ThemeSettings.fromMap(data['settings']);
        await _saveSettings();
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }
}
