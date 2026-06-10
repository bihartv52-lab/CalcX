class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.roomId,
    required this.content,
    this.messageType = 'text',
    this.mediaUrl,
    this.mediaThumbnail,
    this.replyTo,
    this.edited = false,
    this.editedAt,
    this.deleted = false,
    required this.createdAt,
    this.senderProfile,
  });

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String?,
      roomId: map['room_id'] as String?,
      content: map['content'] as String? ?? '',
      messageType: map['message_type'] as String? ?? 'text',
      mediaUrl: map['media_url'] as String?,
      mediaThumbnail: map['media_thumbnail'] as String?,
      replyTo: map['reply_to'] as String?,
      edited: map['edited'] as bool? ?? false,
      editedAt: map['edited_at'] != null
          ? DateTime.parse(map['edited_at'] as String)
          : null,
      deleted: map['deleted'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      senderProfile: map['profiles'] != null
          ? Map<String, dynamic>.from(map['profiles'])
          : null,
    );
  }

  final String id;
  final String senderId;
  final String? receiverId;
  final String? roomId;
  final String content;
  final String messageType; // text, image, video, audio, voice, file
  final String? mediaUrl;
  final String? mediaThumbnail;
  final String? replyTo;
  final bool edited;
  final DateTime? editedAt;
  final bool deleted;
  final DateTime createdAt;
  final Map<String, dynamic>? senderProfile;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'room_id': roomId,
      'content': content,
      'message_type': messageType,
      'media_url': mediaUrl,
      'media_thumbnail': mediaThumbnail,
      'reply_to': replyTo,
      'edited': edited,
      'edited_at': editedAt?.toIso8601String(),
      'deleted': deleted,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isMedia =>
      messageType == 'image' ||
      messageType == 'video' ||
      messageType == 'audio' ||
      messageType == 'voice';

  Message copyWith({
    String? id,
    String? senderId,
    String? receiverId,
    String? roomId,
    String? content,
    String? messageType,
    String? mediaUrl,
    String? mediaThumbnail,
    String? replyTo,
    bool? edited,
    DateTime? editedAt,
    bool? deleted,
    DateTime? createdAt,
    Map<String, dynamic>? senderProfile,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      roomId: roomId ?? this.roomId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaThumbnail: mediaThumbnail ?? this.mediaThumbnail,
      replyTo: replyTo ?? this.replyTo,
      edited: edited ?? this.edited,
      editedAt: editedAt ?? this.editedAt,
      deleted: deleted ?? this.deleted,
      createdAt: createdAt ?? this.createdAt,
      senderProfile: senderProfile ?? this.senderProfile,
    );
  }
}
