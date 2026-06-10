class PlaybackStateSnapshot {
  const PlaybackStateSnapshot({
    required this.position,
    required this.isPlaying,
    required this.updatedAt,
    this.sourceUrl,
    this.hostId,
    this.playbackSpeed = 1.0,
    this.sourceType,
  });

  factory PlaybackStateSnapshot.fromMap(Map<String, dynamic> map) {
    return PlaybackStateSnapshot(
      position: Duration(milliseconds: map['position_ms'] as int? ?? 0),
      isPlaying: map['is_playing'] as bool? ?? false,
      updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      sourceUrl: map['source_url'] as String?,
      hostId: map['host_id'] as String?,
      playbackSpeed: (map['playback_speed'] as num?)?.toDouble() ?? 1.0,
      sourceType: map['source_type'] as String?,
    );
  }

  final Duration position;
  final bool isPlaying;
  final DateTime updatedAt;
  final String? sourceUrl;
  final String? hostId;
  final double playbackSpeed;
  final String? sourceType;

  Duration get estimatedLivePosition {
    if (!isPlaying) {
      return position;
    }
    // Adjust estimated live position by playback speed
    final elapsed = DateTime.now().toUtc().difference(updatedAt);
    return position + Duration(milliseconds: (elapsed.inMilliseconds * playbackSpeed).toInt());
  }

  Map<String, dynamic> toMap() {
    return {
      'position_ms': position.inMilliseconds,
      'is_playing': isPlaying,
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'source_url': sourceUrl,
      'host_id': hostId,
      'playback_speed': playbackSpeed,
      'source_type': sourceType,
    };
  }
}
