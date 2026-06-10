import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:calcx/core/services/secure_storage_service.dart';
import 'package:path_provider/path_provider.dart';

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
  Future<void> setGlobalWallpaper(File originalFile) async {
    try {
      final savedFile = await _saveFileLocally(originalFile, 'global_wallpaper.png');
      state = state.copyWith(
        globalWallpaperPath: savedFile.path,
        themeName: 'gallery',
      );
      await _saveSettings();
    } catch (_) {}
  }

  /// Saves a wallpaper file locally and sets it for a specific chat
  Future<void> setChatWallpaper(String chatId, File originalFile) async {
    try {
      final savedFile = await _saveFileLocally(originalFile, 'chat_$chatId.png');
      final updatedChats = Map<String, String>.from(state.chatWallpapers);
      updatedChats[chatId] = savedFile.path;
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

  /// Helper to copy files to application document directory
  Future<File> _saveFileLocally(File file, String fileName) async {
    final appDir = await getApplicationDocumentsDirectory();
    final wallpaperDir = Directory('${appDir.path}/wallpapers');
    if (!await wallpaperDir.exists()) {
      await wallpaperDir.create(recursive: true);
    }
    return await file.copy('${wallpaperDir.path}/$fileName');
  }

  /// Local Backup of Theme Configuration
  Future<String> exportBackup() async {
    final appDir = await getApplicationDocumentsDirectory();
    final data = {
      'settings': state.toMap(),
      'backup_date': DateTime.now().toIso8601String(),
    };
    final backupFile = File('${appDir.path}/theme_backup.json');
    await backupFile.writeAsString(json.encode(data));
    return backupFile.path;
  }

  /// Restore from Backup File
  Future<void> importBackup(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content);
        if (data['settings'] != null) {
          state = ThemeSettings.fromMap(data['settings']);
          await _saveSettings();
        }
      }
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }
}
