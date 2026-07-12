import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

Future<String> saveWallpaperLocally(XFile file, String fileName) {
  throw UnsupportedError('Cannot save wallpaper on this platform.');
}

Future<String> exportThemeBackup(Map<String, dynamic> data) {
  throw UnsupportedError('Cannot export backup on this platform.');
}

Future<Map<String, dynamic>?> importThemeBackup(String path) {
  throw UnsupportedError('Cannot import backup on this platform.');
}

Future<bool> saveBytesToDownloads(Uint8List bytes, String fileName) {
  throw UnsupportedError('Cannot save bytes to downloads on this platform.');
}

Future<void> shareFile(Uint8List bytes, String fileName) {
  throw UnsupportedError('Cannot share file on this platform.');
}

Future<String> getTempDirectoryPath() {
  throw UnsupportedError('Cannot get temp directory on this platform.');
}
