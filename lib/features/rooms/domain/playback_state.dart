class PlaybackStateSnapshot {
  const PlaybackStateSnapshot({
    required this.position,
    required this.isPlaying,
    required this.updatedAt,
    this.sourceUrl,
    this.hostId,
    this.playbackSpeed = 1.0,
    this.sourceType,
    this.trackTitle,
    this.trackArtist,
    this.trackThumbnail,
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
      trackTitle: map['track_title'] as String?,
      trackArtist: map['track_artist'] as String?,
      trackThumbnail: map['track_thumbnail'] as String?,
    );
  }

  final Duration position;
  final bool isPlaying;
  final DateTime updatedAt;
  final String? sourceUrl;
  final String? hostId;
  final double playbackSpeed;
  final String? sourceType;
  final String? trackTitle;
  final String? trackArtist;
  final String? trackThumbnail;

  Duration get estimatedLivePosition {
    if (!isPlaying) {
      return position;
    }
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
      'track_title': trackTitle,
      'track_artist': trackArtist,
      'track_thumbnail': trackThumbnail,
    };
  }

  bool isSyncDriftExceeded(Duration localPosition, {int thresholdMs = 500}) {
    final target = estimatedLivePosition;
    final diff = (localPosition - target).inMilliseconds.abs();
    return diff > thresholdMs;
  }
}

/// Helper model for Supabase Realtime Broadcast Playback Synchronization (R2)
class BroadcastSyncEvent {
  final String action; // 'play', 'pause', 'seek'
  final int positionMs;
  final DateTime timestamp;
  final String hostId;
  final String? sourceUrl;

  const BroadcastSyncEvent({
    required this.action,
    required this.positionMs,
    required this.timestamp,
    required this.hostId,
    this.sourceUrl,
  });

  factory BroadcastSyncEvent.fromMap(Map<String, dynamic> map) {
    return BroadcastSyncEvent(
      action: map['action'] as String? ?? 'pause',
      positionMs: map['positionMs'] as int? ?? 0,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now().toUtc(),
      hostId: map['hostId'] as String? ?? '',
      sourceUrl: map['sourceUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'action': action,
      'positionMs': positionMs,
      'timestamp': timestamp.toUtc().toIso8601String(),
      'hostId': hostId,
      'sourceUrl': sourceUrl,
    };
  }

  int calculateLatencyMs(DateTime receivedAt) {
    return receivedAt.difference(timestamp.toUtc()).inMilliseconds;
  }
}

/// Synchronized Watch Party Engine to verify broadcast sync state
class WatchPartySyncEngine {
  PlaybackStateSnapshot _currentState = PlaybackStateSnapshot(
    position: Duration.zero,
    isPlaying: false,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  );

  PlaybackStateSnapshot get currentState => _currentState;

  void handleBroadcastEvent(BroadcastSyncEvent event, {DateTime? receivedAt}) {
    final now = receivedAt ?? DateTime.now().toUtc();
    final latency = event.calculateLatencyMs(now);

    final adjustedPosition = event.action == 'play'
        ? Duration(milliseconds: event.positionMs + (latency > 0 ? latency : 0))
        : Duration(milliseconds: event.positionMs);

    _currentState = PlaybackStateSnapshot(
      position: adjustedPosition,
      isPlaying: event.action == 'play',
      updatedAt: now,
      sourceUrl: event.sourceUrl ?? _currentState.sourceUrl,
      hostId: event.hostId,
    );
  }

  bool isSyncDriftExceeded(Duration localPosition, Duration targetPosition, {int thresholdMs = 500}) {
    final diff = (localPosition - targetPosition).inMilliseconds.abs();
    return diff > thresholdMs;
  }
}

