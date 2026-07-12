import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

ImageProvider getWallpaperImageProvider(String path) {
  if (path.startsWith('data:image/')) {
    final bytes = base64Decode(path.split(',')[1]);
    return MemoryImage(bytes);
  }
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return NetworkImage(path);
  }
  return FileImage(File(path));
}

Future<String> saveWallpaperLocally(XFile file, String fileName) async {
  final appDir = await getApplicationDocumentsDirectory();
  final wallpaperDir = Directory('${appDir.path}/wallpapers');
  if (!await wallpaperDir.exists()) {
    await wallpaperDir.create(recursive: true);
  }
  final newFile = File('${wallpaperDir.path}/$fileName');
  final bytes = await file.readAsBytes();
  await newFile.writeAsBytes(bytes);
  return newFile.path;
}

Future<String> exportThemeBackup(Map<String, dynamic> data) async {
  final appDir = await getApplicationDocumentsDirectory();
  final backupFile = File('${appDir.path}/theme_backup.json');
  await backupFile.writeAsString(json.encode(data));
  return backupFile.path;
}

Future<Map<String, dynamic>?> importThemeBackup(String path) async {
  var resolvedPath = path;
  if (resolvedPath.isEmpty) {
    final appDir = await getApplicationDocumentsDirectory();
    resolvedPath = '${appDir.path}/theme_backup.json';
  }
  final file = File(resolvedPath);
  if (await file.exists()) {
    final content = await file.readAsString();
    return json.decode(content) as Map<String, dynamic>;
  }
  throw Exception('No backup file found at default location.');
}

Future<bool> saveBytesToDownloads(Uint8List bytes, String fileName) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (await dir.exists()) {
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return true;
      }
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      dir = await getDownloadsDirectory();
      if (dir != null && await dir.exists()) {
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        return true;
      }
    }
  } catch (_) {}
  return false;
}

Future<void> shareFile(Uint8List bytes, String fileName) async {
  try {
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(bytes);
    await Share.shareXFiles(
      [XFile(tempFile.path)],
      text: 'Save CalcX File',
    );
  } catch (_) {}
}

Future<String> getTempDirectoryPath() async {
  final tempDir = await getTemporaryDirectory();
  return tempDir.path;
}
