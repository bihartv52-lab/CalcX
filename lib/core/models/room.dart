class Room {
  const Room({
    required this.id,
    required this.name,
    this.description,
    required this.roomType,
    required this.hostId,
    this.isPublic = false,
    this.inviteCode,
    this.maxParticipants = 50,
    this.currentMediaUrl,
    this.mediaPosition = 0,
    this.mediaPlaying = false,
    required this.createdAt,
    this.updatedAt,
    this.participantCount = 0,
  });

  factory Room.fromMap(Map<String, dynamic> map) {
    final visibility = map['visibility'] as String? ?? 'public';
    final playbackState = map['playback_state'] as Map<String, dynamic>?;

    return Room(
      id: map['id'] as String,
      name: map['name'] as String,
      description: map['description'] as String?,
      roomType: map['room_type'] as String? ?? 'party',
      hostId: map['host_id'] as String,
      isPublic: visibility == 'public',
      inviteCode: map['invite_code'] as String?,
      maxParticipants: map['max_participants'] as int? ?? 50,
      currentMediaUrl: map['media_url'] as String?,
      mediaPosition: playbackState?['position_ms'] as int? ?? 0,
      mediaPlaying: playbackState?['is_playing'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      participantCount: map['participant_count'] as int? ?? 0,
    );
  }

  final String id;
  final String name;
  final String? description;
  final String roomType; // party, watch, music, study
  final String hostId;
  final bool isPublic;
  final String? inviteCode;
  final int maxParticipants;
  final String? currentMediaUrl;
  final int mediaPosition;
  final bool mediaPlaying;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int participantCount;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'room_type': roomType,
      'host_id': hostId,
      'visibility': isPublic ? 'public' : 'private',
      'invite_code': inviteCode,
      'max_participants': maxParticipants,
      'media_url': currentMediaUrl,
      'playback_state': {
        'position_ms': mediaPosition,
        'is_playing': mediaPlaying,
        'source_url': currentMediaUrl,
        'host_id': hostId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isFull => participantCount >= maxParticipants;

  Room copyWith({
    String? id,
    String? name,
    String? description,
    String? roomType,
    String? hostId,
    bool? isPublic,
    String? inviteCode,
    int? maxParticipants,
    String? currentMediaUrl,
    int? mediaPosition,
    bool? mediaPlaying,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? participantCount,
  }) {
    return Room(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      roomType: roomType ?? this.roomType,
      hostId: hostId ?? this.hostId,
      isPublic: isPublic ?? this.isPublic,
      inviteCode: inviteCode ?? this.inviteCode,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentMediaUrl: currentMediaUrl ?? this.currentMediaUrl,
      mediaPosition: mediaPosition ?? this.mediaPosition,
      mediaPlaying: mediaPlaying ?? this.mediaPlaying,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participantCount: participantCount ?? this.participantCount,
    );
  }
}
