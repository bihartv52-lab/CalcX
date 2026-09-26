import 'package:flutter/foundation.dart';

@immutable
class UserNote {
  const UserNote({
    required this.id,
    required this.userId,
    required this.content,
    this.songTitle,
    this.songArtist,
    this.songArtwork,
    this.songUrl,
    this.isLocalSong = false,
    this.audience = 'mutual',
    required this.createdAt,
    required this.expiresAt,
    this.username = '',
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String userId;
  final String content;
  final String? songTitle;
  final String? songArtist;
  final String? songArtwork;
  final String? songUrl;
  final bool isLocalSong;
  final String audience; // 'mutual', 'close_friends', 'everyone'
  final DateTime createdAt;
  final DateTime expiresAt;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  bool get hasMusic => songTitle != null && songTitle!.isNotEmpty;
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  String get authorName => (displayName != null && displayName!.isNotEmpty)
      ? displayName!
      : (username.isNotEmpty ? username : 'User');

  factory UserNote.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? profileMap}) {
    final profile = profileMap ?? (map['profiles'] is Map ? map['profiles'] as Map<String, dynamic> : null);

    return UserNote(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      songTitle: map['song_title']?.toString(),
      songArtist: map['song_artist']?.toString(),
      songArtwork: map['song_artwork']?.toString(),
      songUrl: map['song_url']?.toString(),
      isLocalSong: map['is_local_song'] == true,
      audience: map['audience']?.toString() ?? 'mutual',
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: map['expires_at'] != null
          ? DateTime.tryParse(map['expires_at'].toString()) ??
              DateTime.now().add(const Duration(hours: 24))
          : DateTime.now().add(const Duration(hours: 24)),
      username: profile?['username']?.toString() ?? '',
      displayName: profile?['display_name']?.toString(),
      avatarUrl: profile?['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'content': content,
      'song_title': songTitle,
      'song_artist': songArtist,
      'song_artwork': songArtwork,
      'song_url': songUrl,
      'is_local_song': isLocalSong,
      'audience': audience,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
