class UserProfile {
  const UserProfile({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.status = 'offline',
    this.lastSeen,
    this.createdAt,
    this.updatedAt,
    this.credits = 100,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'] as String,
      username: map['username'] as String? ?? '',
      displayName: map['display_name'] as String? ?? '',
      avatarUrl: map['avatar_url'] as String?,
      bio: map['bio'] as String?,
      status: map['status'] as String? ?? 'offline',
      lastSeen: map['last_seen'] != null
          ? DateTime.parse(map['last_seen'] as String)
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : null,
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      credits: map['credits'] as int? ?? 100,
    );
  }

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String status; // online, offline, away, busy
  final DateTime? lastSeen;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int credits;

  bool get isOnline => status == 'online';
  bool get isAway => status == 'away';
  bool get isBusy => status == 'busy';
  bool get isOffline => status == 'offline';

  String getPresenceText() {
    if (isOnline) {
      return 'Online';
    }
    if (lastSeen == null) {
      return 'Offline';
    }
    final now = DateTime.now();
    final lastSeenLocal = lastSeen!.toLocal();
    final difference = now.difference(lastSeenLocal);
    
    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Last seen just now';
    } else if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return 'Last seen $mins ${mins == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      final hrs = difference.inHours;
      return 'Last seen $hrs ${hrs == 1 ? 'hour' : 'hours'} ago';
    } else {
      final days = difference.inDays;
      return 'Last seen $days ${days == 1 ? 'day' : 'days'} ago';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'bio': bio,
      'status': status,
      'last_seen': lastSeen?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'credits': credits,
    };
  }

  UserProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? status,
    DateTime? lastSeen,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? credits,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      status: status ?? this.status,
      lastSeen: lastSeen ?? this.lastSeen,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      credits: credits ?? this.credits,
    );
  }
}
