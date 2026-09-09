import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcx/core/models/user_profile.dart';

/// Validation logic for User Profile Edits (R4)
class ProfileValidator {
  static String? validateDisplayName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'Display name cannot be empty';
    }
    final trimmed = name.trim();
    if (trimmed.length < 2) {
      return 'Display name must be at least 2 characters';
    }
    if (trimmed.length > 50) {
      return 'Display name must not exceed 50 characters';
    }
    return null;
  }

  static String? validateBio(String? bio) {
    if (bio == null) return null;
    if (bio.length > 160) {
      return 'Bio must not exceed 160 characters';
    }
    return null;
  }

  static String? validateNickname(String? nickname) {
    if (nickname == null) return null;
    if (nickname.length > 30) {
      return 'Nickname must not exceed 30 characters';
    }
    return null;
  }
}

/// Helper manager for Supabase Storage Profile Avatar Upload & Refresh (R4)
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

/// Profile Avatar Refresh Listener Stream Controller (R4)
class ProfileAvatarRefreshNotifier extends ChangeNotifier {
  UserProfile _currentProfile;

  ProfileAvatarRefreshNotifier(this._currentProfile);

  UserProfile get currentProfile => _currentProfile;

  void updateProfile({
    String? displayName,
    String? bio,
    String? nickname,
    String? avatarUrl,
  }) {
    _currentProfile = _currentProfile.copyWith(
      displayName: displayName ?? _currentProfile.displayName,
      bio: bio ?? _currentProfile.bio,
      avatarUrl: avatarUrl ?? _currentProfile.avatarUrl,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }
}

/// Circular Profile Avatar Widget Component (R4)
class TestCircularProfileAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final double radius;

  const TestCircularProfileAvatar({
    super.key,
    required this.avatarUrl,
    required this.displayName,
    this.radius = 40,
  });

  String get _initials {
    final parts = displayName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      key: const ValueKey('circular_avatar_clip'),
      child: Container(
        width: radius * 2,
        height: radius * 2,
        color: Colors.purpleAccent,
        child: avatarUrl != null && avatarUrl!.isNotEmpty
            ? Image.network(
                avatarUrl!,
                key: const ValueKey('avatar_network_image'),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    _initials,
                    key: const ValueKey('avatar_initials_fallback'),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: radius * 0.8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )
            : Center(
                child: Text(
                  _initials,
                  key: const ValueKey('avatar_initials_fallback'),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: radius * 0.8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}

void main() {
  group('Profile Edits & Avatars (R4) - Display Name, Bio, Nickname Edits', () {
    test('Validates display name rules (non-empty, min 2 chars, max 50 chars)', () {
      expect(ProfileValidator.validateDisplayName(''), equals('Display name cannot be empty'));
      expect(ProfileValidator.validateDisplayName('   '), equals('Display name cannot be empty'));
      expect(ProfileValidator.validateDisplayName('A'), equals('Display name must be at least 2 characters'));

      final longName = 'A' * 51;
      expect(ProfileValidator.validateDisplayName(longName), equals('Display name must not exceed 50 characters'));

      expect(ProfileValidator.validateDisplayName('CalcX Dev'), isNull);
    });

    test('Validates bio and nickname character limits', () {
      final longBio = 'B' * 161;
      expect(ProfileValidator.validateBio(longBio), equals('Bio must not exceed 160 characters'));
      expect(ProfileValidator.validateBio('Software engineer building social tools'), isNull);

      final longNick = 'N' * 31;
      expect(ProfileValidator.validateNickname(longNick), equals('Nickname must not exceed 30 characters'));
      expect(ProfileValidator.validateNickname('CyberPilot'), isNull);
    });

    test('Updates user profile fields correctly via copyWith and toMap serialization', () {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 'usr_100',
        username: 'cyberpunk',
        displayName: 'Old Name',
        createdAt: now,
      );

      final updated = profile.copyWith(
        displayName: 'New Display Name',
        nickname: 'CyberPilot',
        bio: 'Avid gamer & dev',
        avatarUrl: 'https://supabase.co/storage/v1/object/public/avatars/usr_100_123.png',
        updatedAt: now,
      );

      expect(updated.displayName, equals('New Display Name'));
      expect(updated.nickname, equals('CyberPilot'));
      expect(updated.bio, equals('Avid gamer & dev'));
      expect(updated.avatarUrl, contains('usr_100'));

      final map = updated.toMap();
      expect(map['display_name'], equals('New Display Name'));
      expect(map['nickname'], equals('CyberPilot'));
      expect(map['bio'], equals('Avid gamer & dev'));
      expect(map['avatar_url'], equals(updated.avatarUrl));

      final restored = UserProfile.fromMap(map);
      expect(restored.nickname, equals('CyberPilot'));
      expect(restored.effectiveName, equals('CyberPilot'));
    });

    test('Computes effectiveName fallback correctly (nickname > displayName > username)', () {
      const p1 = UserProfile(id: '1', username: 'john_doe', displayName: 'John Doe', nickname: 'JD');
      expect(p1.effectiveName, equals('JD'));

      const p2 = UserProfile(id: '2', username: 'john_doe', displayName: 'John Doe');
      expect(p2.effectiveName, equals('John Doe'));

      const p3 = UserProfile(id: '3', username: 'john_doe', displayName: '');
      expect(p3.effectiveName, equals('john_doe'));
    });
  });

  group('Profile Edits & Avatars (R4) - Circular Avatar Upload & Supabase Storage', () {
    test('Generates storage path with userId, timestamp, and allowed image extension', () {
      const userId = 'usr_test_123';
      const filename = 'my_photo.png';

      final path = AvatarStorageManager.generateStoragePath(userId: userId, filename: filename);
      expect(path, startsWith('avatars/usr_test_123_'));
      expect(path, endsWith('.png'));
    });

    test('Determines correct MIME content types for uploaded avatar images', () {
      expect(AvatarStorageManager.getContentType('avatar.png'), equals('image/png'));
      expect(AvatarStorageManager.getContentType('photo.jpg'), equals('image/jpeg'));
      expect(AvatarStorageManager.getContentType('photo.jpeg'), equals('image/jpeg'));
      expect(AvatarStorageManager.getContentType('graphic.webp'), equals('image/webp'));
    });

    test('Throws ArgumentError when attempting upload with disallowed file extensions', () {
      expect(
        () => AvatarStorageManager.generateStoragePath(userId: 'u1', filename: 'script.exe'),
        throwsArgumentError,
      );
      expect(
        () => AvatarStorageManager.generateStoragePath(userId: 'u1', filename: 'document.pdf'),
        throwsArgumentError,
      );
    });

    test('Builds valid public Supabase storage avatar URL', () {
      const baseUrl = 'https://xyz.supabase.co';
      const path = 'avatars/usr_1_12345.png';
      final publicUrl = AvatarStorageManager.getPublicUrl(supabaseUrl: baseUrl, path: path);

      expect(publicUrl, equals('https://xyz.supabase.co/storage/v1/object/public/avatars/usr_1_12345.png'));
    });

    test('ProfileAvatarRefreshNotifier triggers realtime listeners on avatar upload', () {
      final initialProfile = UserProfile(
        id: 'usr_1',
        username: 'alex',
        displayName: 'Alex Smith',
      );

      final notifier = ProfileAvatarRefreshNotifier(initialProfile);
      bool notified = false;
      notifier.addListener(() {
        notified = true;
      });

      const newAvatarUrl = 'https://xyz.supabase.co/storage/v1/object/public/avatars/usr_1_9999.png';
      notifier.updateProfile(avatarUrl: newAvatarUrl);

      expect(notified, isTrue);
      expect(notifier.currentProfile.avatarUrl, equals(newAvatarUrl));
    });
  });

  group('Profile Edits & Avatars (R4) - Circular Profile Avatar Widget Driver', () {
    testWidgets('Renders circular profile avatar with initial fallback when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestCircularProfileAvatar(
              avatarUrl: null,
              displayName: 'John Doe',
              radius: 40,
            ),
          ),
        ),
      );

      // Verify circular clip present
      expect(find.byKey(const ValueKey('circular_avatar_clip')), findsOneWidget);

      // Verify fallback initials rendered
      expect(find.byKey(const ValueKey('avatar_initials_fallback')), findsOneWidget);
      expect(find.text('JD'), findsOneWidget);
    });

    testWidgets('Renders circular profile avatar image when avatarUrl is provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestCircularProfileAvatar(
              avatarUrl: 'https://example.com/avatar.png',
              displayName: 'Alice Wonderland',
              radius: 50,
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('circular_avatar_clip')), findsOneWidget);
      expect(find.byKey(const ValueKey('avatar_network_image')), findsOneWidget);
    });
  });
}
