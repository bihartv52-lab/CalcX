import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

Future<String> saveWallpaperLocally(XFile file, String fileName) async {
  final bytes = await file.readAsBytes();
  final base64String = base64Encode(bytes);
  return 'data:image/png;base64,$base64String';
}

Future<String> exportThemeBackup(Map<String, dynamic> data) async {
  final jsonString = json.encode(data);
  final blob = html.Blob([jsonString], 'application/json');
  final url = html.Url.createObjectUrlFromBlob(blob);
  
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'theme_backup.json')
    ..click();
  
  html.Url.revokeObjectUrl(url);
  return 'Browser Download Folder';
}

Future<Map<String, dynamic>?> importThemeBackup(String path) async {
  final uploadInput = html.FileUploadInputElement()..accept = '.json';
  uploadInput.click();
  
  await uploadInput.onChange.first;
  final file = uploadInput.files?.first;
  if (file == null) return null;
  
  final reader = html.FileReader();
  reader.readAsText(file);
  await reader.onLoad.first;
  
  final content = reader.result as String;
  return json.decode(content) as Map<String, dynamic>;
}

Future<bool> saveBytesToDownloads(Uint8List bytes, String fileName) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return true;
}

Future<void> shareFile(Uint8List bytes, String fileName) async {
  await saveBytesToDownloads(bytes, fileName);
}

Future<String> getTempDirectoryPath() async {
  return '';
}
