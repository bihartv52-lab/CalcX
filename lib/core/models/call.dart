class Call {
  const Call({
    required this.id,
    required this.callerId,
    required this.receiverId,
    required this.callType,
    required this.status,
    this.roomName,
    required this.startedAt,
    this.endedAt,
    this.duration,
    this.callerProfile,
    this.receiverProfile,
  });

  factory Call.fromMap(Map<String, dynamic> map) {
    return Call(
      id: map['id'] as String,
      callerId: map['caller_id'] as String,
      receiverId: map['receiver_id'] as String,
      callType: map['call_type'] as String,
      status: map['status'] as String? ?? 'ringing',
      roomName: map['room_name'] as String?,
      startedAt: DateTime.parse(map['started_at'] as String),
      endedAt: map['ended_at'] != null
          ? DateTime.parse(map['ended_at'] as String)
          : null,
      duration: map['duration'] as int?,
      callerProfile: map['caller_profile'] != null
          ? Map<String, dynamic>.from(map['caller_profile'])
          : null,
      receiverProfile: map['receiver_profile'] != null
          ? Map<String, dynamic>.from(map['receiver_profile'])
          : null,
    );
  }

  final String id;
  final String callerId;
  final String receiverId;
  final String callType; // audio, video, screen_share
  final String status; // ringing, ongoing, ended, missed, rejected
  final String? roomName;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? duration;
  final Map<String, dynamic>? callerProfile;
  final Map<String, dynamic>? receiverProfile;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'caller_id': callerId,
      'receiver_id': receiverId,
      'call_type': callType,
      'status': status,
      'room_name': roomName,
      'started_at': startedAt.toIso8601String(),
      'ended_at': endedAt?.toIso8601String(),
      'duration': duration,
    };
  }

  bool get isRinging => status == 'ringing';
  bool get isOngoing => status == 'ongoing';
  bool get isEnded => status == 'ended';
  bool get isMissed => status == 'missed';
  bool get isRejected => status == 'rejected';

  bool get isAudio => callType == 'audio';
  bool get isVideo => callType == 'video';
  bool get isScreenShare => callType == 'screen_share';

  Call copyWith({
    String? id,
    String? callerId,
    String? receiverId,
    String? callType,
    String? status,
    String? roomName,
    DateTime? startedAt,
    DateTime? endedAt,
    int? duration,
    Map<String, dynamic>? callerProfile,
    Map<String, dynamic>? receiverProfile,
  }) {
    return Call(
      id: id ?? this.id,
      callerId: callerId ?? this.callerId,
      receiverId: receiverId ?? this.receiverId,
      callType: callType ?? this.callType,
      status: status ?? this.status,
      roomName: roomName ?? this.roomName,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      duration: duration ?? this.duration,
      callerProfile: callerProfile ?? this.callerProfile,
      receiverProfile: receiverProfile ?? this.receiverProfile,
    );
  }
}
