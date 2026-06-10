import 'package:calcx/core/models/user_profile.dart';

class FriendRequest {
  const FriendRequest({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.status,
    required this.createdAt,
    this.updatedAt,
    this.senderProfile,
    this.receiverProfile,
  });

  factory FriendRequest.fromMap(Map<String, dynamic> map) {
    return FriendRequest(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String,
      status: map['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'] as String)
          : null,
      senderProfile: map['profiles'] != null
          ? UserProfile.fromMap(map['profiles'])
          : null,
      receiverProfile: map['receiver_profile'] != null
          ? UserProfile.fromMap(map['receiver_profile'])
          : null,
    );
  }

  final String id;
  final String senderId;
  final String receiverId;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;
  final DateTime? updatedAt;
  final UserProfile? senderProfile;
  final UserProfile? receiverProfile;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isRejected => status == 'rejected';
}
