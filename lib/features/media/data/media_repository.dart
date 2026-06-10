import 'dart:io';

import 'package:calcx/core/services/supabase_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final mediaRepositoryProvider = Provider<MediaRepository>((ref) {
  return MediaRepository(SupabaseService.clientOrNull);
});

class MediaRepository {
  MediaRepository(this._supabase);

  final SupabaseClient? _supabase;
  static const maxUploadBytes = 50 * 1024 * 1024;
  static const _uuid = Uuid();
  final _picker = ImagePicker();

  Future<File?> pickImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    return image == null ? null : File(image.path);
  }

  Future<File?> takePhoto() async {
    final image = await _picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    return image == null ? null : File(image.path);
  }

  Future<File?> pickVideo() async {
    final video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(minutes: 5),
    );
    return video == null ? null : File(video.path);
  }

  Future<File?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    final path = result?.files.firstOrNull?.path;
    return path == null ? null : File(path);
  }

  Future<File?> generateImageThumbnail(File imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      if (image == null) return null;

      final thumbnail = img.copyResize(image, width: 200);
      final thumbnailBytes = img.encodeJpg(thumbnail, quality: 70);
      final tempDir = await getTemporaryDirectory();
      final thumbnailPath = '${tempDir.path}/thumb_${_uuid.v4()}.jpg';
      final thumbnailFile = File(thumbnailPath);
      await thumbnailFile.writeAsBytes(thumbnailBytes);

      return thumbnailFile;
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      return null;
    }
  }

  Future<Map<String, String>> uploadMedia({
    required File file,
    required String fileType,
    void Function(double progress)? onProgress,
  }) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('User must be logged in to upload media.');
    }

    final length = await file.length();
    if (length > maxUploadBytes) {
      throw StateError('File must be 50MB or smaller.');
    }
    onProgress?.call(0);

    final id = _uuid.v4();
    final extension = file.path.split('.').last.toLowerCase();
    final fileName = '$id.$extension';
    final storagePath = '$userId/$fileType/$fileName';
    final mimeType = _mimeTypeFor(fileType, extension);

    await supabase.storage
        .from('media')
        .upload(
          storagePath,
          file,
          fileOptions: FileOptions(contentType: mimeType, upsert: false),
        );
    onProgress?.call(0.75);

    final publicUrl = supabase.storage.from('media').getPublicUrl(storagePath);
    String? thumbnailUrl;

    if (fileType == 'image') {
      final thumbnail = await generateImageThumbnail(file);
      if (thumbnail != null) {
        final thumbPath = '$userId/$fileType/thumb_$fileName';
        await supabase.storage
            .from('media')
            .upload(
              thumbPath,
              thumbnail,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                upsert: false,
              ),
            );
        thumbnailUrl = supabase.storage.from('media').getPublicUrl(thumbPath);
        await thumbnail.delete();
      }
    }

    await supabase.from('media_files').insert({
      'id': id,
      'user_id': userId,
      'file_name': fileName,
      'file_type': fileType,
      'file_size': length,
      'storage_path': storagePath,
      'thumbnail_path': thumbnailUrl == null
          ? null
          : '$userId/$fileType/thumb_$fileName',
      'created_at': DateTime.now().toIso8601String(),
    });
    onProgress?.call(1);

    return {'url': publicUrl, 'thumbnail': thumbnailUrl ?? publicUrl, 'id': id};
  }

  Future<String> getSignedUrl(String path, {int expiresIn = 3600}) async {
    final supabase = _supabase;
    if (supabase == null) {
      throw StateError('Supabase is not configured.');
    }

    return supabase.storage.from('media').createSignedUrl(path, expiresIn);
  }

  Future<void> deleteMedia(String storagePath) async {
    final supabase = _supabase;
    if (supabase == null) return;

    try {
      await supabase.storage.from('media').remove([storagePath]);
    } catch (e) {
      debugPrint('Error deleting media: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getUserMedia() async {
    final supabase = _supabase;
    if (supabase == null) return [];

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return [];

    try {
      final response = await supabase
          .from('media_files')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user media: $e');
      return [];
    }
  }

  String _mimeTypeFor(String fileType, String extension) {
    return switch (fileType) {
      'image' => 'image/${extension == 'jpg' ? 'jpeg' : extension}',
      'video' => 'video/$extension',
      'audio' => 'audio/$extension',
      _ => 'application/octet-stream',
    };
  }
}
