import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/core/services/secure_storage_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Storage Bucket Manager & Path Utility for Profile Avatars
class AvatarStorageManager {
  static const String avatarBucket = 'avatars';
  static final Set<String> allowedExtensions = {'png', 'jpg', 'jpeg', 'webp'};

  static String generateStoragePath({required String userId, required String filename}) {
    final ext = filename.split('.').last.toLowerCase();
    if (!allowedExtensions.contains(ext)) {
      throw ArgumentError('Unsupported image format: .$ext. Allowed: ${allowedExtensions.join(', ')}');
    }
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'avatars/${userId}_$timestamp.$ext';
  }

  static String getContentType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'application/octet-stream';
    }
  }

  static String getPublicUrl({required String supabaseUrl, required String path}) {
    return '$supabaseUrl/storage/v1/object/public/$path';
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = SupabaseService.clientOrNull;
  final storage = ref.watch(secureStorageProvider);
  return ProfileRepository(supabaseClient: supabase, storage: storage);
});

final myProfileProvider = StreamProvider<UserProfile?>((ref) {
  final repo = ref.watch(profileRepositoryProvider);
  final authRepo = ref.watch(authRepositoryProvider);
  final currentUser = authRepo.currentUser;

  if (currentUser != null) {
    return repo.watchMyProfile(currentUser.id);
  }

  // Fallback for local user
  final controller = StreamController<UserProfile?>();
  repo.fetchLocalProfile().then((profile) {
    controller.add(profile);
  });

  // Listen to local update stream
  final sub = repo.localProfileStream.listen((profile) {
    controller.add(profile);
  });

  ref.onDispose(() {
    sub.cancel();
    controller.close();
  });

  return controller.stream;
});

class ProfileRepository {
  ProfileRepository({
    required SupabaseClient? supabaseClient,
    required FlutterSecureStorage storage,
  })  : _supabase = supabaseClient,
        _storage = storage;

  final SupabaseClient? _supabase;
  final FlutterSecureStorage _storage;

  static const String _localProfileDisplayNameKey = 'calcx.local_profile_display_name';
  static const String _localProfileBioKey = 'calcx.local_profile_bio';
  static const String _localProfileNicknameKey = 'calcx.local_profile_nickname';
  static const String _localProfileAvatarUrlKey = 'calcx.local_profile_avatar_url';

  final StreamController<UserProfile?> _localProfileController = StreamController<UserProfile?>.broadcast();
  Stream<UserProfile?> get localProfileStream => _localProfileController.stream;

  /// Fetch user profile by userId
  Future<UserProfile?> fetchProfile(String userId) async {
    final supabase = _supabase;
    if (supabase != null) {
      try {
        final response = await supabase
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();

        if (response != null) {
          return UserProfile.fromMap(response);
        }
      } catch (e) {
        debugPrint('Error fetching profile from Supabase: $e');
      }
    }
    return fetchLocalProfile();
  }

  /// Fetch local profile fallback
  Future<UserProfile> fetchLocalProfile() async {
    final username = await _storage.read(key: 'calcx.local_username') ?? 'local_user';
    final displayName = await _storage.read(key: _localProfileDisplayNameKey) ?? username;
    final bio = await _storage.read(key: _localProfileBioKey);
    final nickname = await _storage.read(key: _localProfileNicknameKey);
    final avatarUrl = await _storage.read(key: _localProfileAvatarUrlKey);

    return UserProfile(
      id: 'local_user_id',
      username: username,
      displayName: displayName,
      nickname: nickname,
      bio: bio,
      avatarUrl: avatarUrl,
      status: 'online',
    );
  }

  /// Pick an image file from gallery or camera
  Future<XFile?> pickAvatarImage({ImageSource source = ImageSource.gallery}) async {
    final picker = ImagePicker();
    return await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 90,
    );
  }

  /// Process raw image bytes into a high-quality centered square PNG/JPEG
  Uint8List processSquareAvatar(Uint8List rawBytes) {
    final image = img.decodeImage(rawBytes);
    if (image == null) return rawBytes;

    final cropSize = image.width < image.height ? image.width : image.height;
    final offsetX = (image.width - cropSize) ~/ 2;
    final offsetY = (image.height - cropSize) ~/ 2;

    final cropped = img.copyCrop(
      image,
      x: offsetX,
      y: offsetY,
      width: cropSize,
      height: cropSize,
    );

    // Resize to standard 512x512 avatar if larger
    final resized = cropSize > 512
        ? img.copyResize(cropped, width: 512, height: 512, interpolation: img.Interpolation.average)
        : cropped;

    return Uint8List.fromList(img.encodePng(resized));
  }

  /// Upload avatar to Supabase storage bucket `avatars/{userId}_{timestamp}.png`
  Future<String> uploadAvatar({
    required String userId,
    required List<int> bytes,
    required String filename,
  }) async {
    final storagePath = AvatarStorageManager.generateStoragePath(userId: userId, filename: filename);
    final contentType = AvatarStorageManager.getContentType(filename);
    final processedBytes = processSquareAvatar(Uint8List.fromList(bytes));

    final supabase = _supabase;
    if (supabase != null) {
      try {
        await supabase.storage.from(AvatarStorageManager.avatarBucket).uploadBinary(
              storagePath,
              processedBytes,
              fileOptions: FileOptions(contentType: contentType, upsert: true),
            );

        final publicUrl = supabase.storage.from(AvatarStorageManager.avatarBucket).getPublicUrl(storagePath);
        return publicUrl;
      } catch (e) {
        debugPrint('Supabase storage avatar upload error: $e');
        // If Supabase storage fails, fallback to local data URI or rethrow
        rethrow;
      }
    }

    // Local mode fallback
    final localUrl = 'data:$contentType;base64,${base64Encode(processedBytes)}';
    await _storage.write(key: _localProfileAvatarUrlKey, value: localUrl);
    return localUrl;
  }

  /// Update user profile details in Supabase and local storage
  Future<void> updateProfile({
    required String userId,
    String? displayName,
    String? bio,
    String? nickname,
    String? avatarUrl,
  }) async {
    // Validate inputs using UserProfile static validators
    if (displayName != null) {
      final err = UserProfile.validateDisplayName(displayName);
      if (err != null) throw Exception(err);
    }
    if (bio != null) {
      final err = UserProfile.validateBio(bio);
      if (err != null) throw Exception(err);
    }
    if (nickname != null) {
      final err = UserProfile.validateNickname(nickname);
      if (err != null) throw Exception(err);
    }

    final supabase = _supabase;
    if (supabase != null) {
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (displayName != null) updateData['display_name'] = displayName.trim();
      if (bio != null) updateData['bio'] = bio.trim();
      if (nickname != null) updateData['nickname'] = nickname.trim();
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      await supabase.from('profiles').update(updateData).eq('id', userId);
    }

    // Update local storage
    if (displayName != null) await _storage.write(key: _localProfileDisplayNameKey, value: displayName.trim());
    if (bio != null) await _storage.write(key: _localProfileBioKey, value: bio.trim());
    if (nickname != null) await _storage.write(key: _localProfileNicknameKey, value: nickname.trim());
    if (avatarUrl != null) await _storage.write(key: _localProfileAvatarUrlKey, value: avatarUrl);

    final updatedProfile = await fetchProfile(userId);
    if (updatedProfile != null) {
      _localProfileController.add(updatedProfile);
    }
  }

  /// Broadcast Real-time stream of user profile changes app-wide
  Stream<UserProfile?> watchMyProfile(String userId) {
    final supabase = _supabase;
    if (supabase != null) {
      try {
        return supabase
            .from('profiles')
            .stream(primaryKey: ['id'])
            .eq('id', userId)
            .map((data) {
              if (data.isNotEmpty) {
                return UserProfile.fromMap(data.first);
              }
              return null;
            });
      } catch (e) {
        debugPrint('Supabase realtime stream error for profile: $e');
      }
    }

    return localProfileStream;
  }
}
