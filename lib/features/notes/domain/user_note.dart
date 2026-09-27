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
    this.songSnippetStart = 0,
    this.songSnippetDuration = 30,
    this.audience = 'mutual',
    this.mentionedUserId,
    this.mentionedUsername,
    this.mentionedDisplayName,
    this.mentionedAvatarUrl,
    this.allowedUserIds = const [],
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
  final int songSnippetStart;
  final int songSnippetDuration;
  final String audience; // 'mutual', 'close_friends', 'selected_friends', 'everyone'
  final String? mentionedUserId;
  final String? mentionedUsername;
  final String? mentionedDisplayName;
  final String? mentionedAvatarUrl;
  final List<String> allowedUserIds;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  bool get hasMusic => songTitle != null && songTitle!.isNotEmpty;
  bool get isFullLengthSong => songSnippetDuration <= 0 || songSnippetDuration >= 900 || (songSnippetStart == 0 && songSnippetDuration == 0);
  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get isCloseFriends => audience == 'close_friends';
  bool get isSelectedFriends => audience == 'selected_friends';
  bool get hasMention =>
      (mentionedUsername != null && mentionedUsername!.isNotEmpty) ||
      (mentionedUserId != null && mentionedUserId!.isNotEmpty);

  bool isMentioning(String? myId) =>
      myId != null && mentionedUserId != null && mentionedUserId == myId;

  String get authorName => (displayName != null && displayName!.isNotEmpty)
      ? displayName!
      : (username.isNotEmpty ? username : 'User');

  factory UserNote.fromMap(Map<String, dynamic> map, {Map<String, dynamic>? profileMap}) {
    final profile = profileMap ?? (map['profiles'] is Map ? map['profiles'] as Map<String, dynamic> : null);

    final rawAllowed = map['allowed_user_ids'];
    List<String> allowed = [];
    if (rawAllowed is List) {
      allowed = rawAllowed.map((e) => e.toString()).toList();
    }

    return UserNote(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      songTitle: map['song_title']?.toString(),
      songArtist: map['song_artist']?.toString(),
      songArtwork: map['song_artwork']?.toString(),
      songUrl: map['song_url']?.toString(),
      isLocalSong: map['is_local_song'] == true,
      songSnippetStart: (map['song_snippet_start'] as num?)?.toInt() ?? 0,
      songSnippetDuration: (map['song_snippet_duration'] as num?)?.toInt() ?? 30,
      audience: map['audience']?.toString() ?? 'mutual',
      mentionedUserId: map['mentioned_user_id']?.toString(),
      mentionedUsername: map['mentioned_username']?.toString(),
      mentionedDisplayName: map['mentioned_display_name']?.toString(),
      mentionedAvatarUrl: map['mentioned_avatar_url']?.toString(),
      allowedUserIds: allowed,
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
      'song_snippet_start': songSnippetStart,
      'song_snippet_duration': songSnippetDuration,
      'audience': audience,
      'mentioned_user_id': mentionedUserId,
      'mentioned_username': mentionedUsername,
      'mentioned_display_name': mentionedDisplayName,
      'mentioned_avatar_url': mentionedAvatarUrl,
      'allowed_user_ids': allowedUserIds,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
