import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UserDevice {
  const UserDevice({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceName,
    required this.deviceOs,
    this.ipAddress,
    this.isActiveChat = false,
    required this.lastActive,
    required this.createdAt,
  });

  factory UserDevice.fromMap(Map<String, dynamic> map) {
    return UserDevice(
      id: map['id'] as String? ?? '',
      userId: map['user_id'] as String? ?? '',
      deviceId: map['device_id'] as String? ?? '',
      deviceName: map['device_name'] as String? ?? 'Unknown Device',
      deviceOs: map['device_os'] as String? ?? 'Unknown OS',
      ipAddress: map['ip_address'] as String?,
      isActiveChat: map['is_active_chat'] as bool? ?? false,
      lastActive: map['last_active'] != null
          ? DateTime.parse(map['last_active'] as String)
          : DateTime.now(),
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'] as String)
          : DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String deviceId;
  final String deviceName;
  final String deviceOs;
  final String? ipAddress;
  final bool isActiveChat;
  final DateTime lastActive;
  final DateTime createdAt;

  Map<String, dynamic> toMap() {
    return {
      if (id.isNotEmpty) 'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'device_name': deviceName,
      'device_os': deviceOs,
      'ip_address': ipAddress,
      'is_active_chat': isActiveChat,
      'last_active': lastActive.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool isCurrent(String currentDeviceId) => deviceId == currentDeviceId;

  IconData get icon {
    final os = deviceOs.toLowerCase();
    final name = deviceName.toLowerCase();
    if (os.contains('android') || name.contains('android') || os.contains('ios') || name.contains('iphone')) {
      return Icons.phone_android_rounded;
    }
    if (os.contains('windows') || os.contains('mac') || os.contains('linux') || name.contains('pc') || name.contains('laptop')) {
      return Icons.laptop_mac_rounded;
    }
    if (os.contains('web') || name.contains('chrome') || name.contains('safari') || name.contains('browser')) {
      return Icons.language_rounded;
    }
    return Icons.devices_other_rounded;
  }

  String formattedLastActive({bool isCurrent = false}) {
    if (isCurrent) return 'Active now';

    final now = DateTime.now();
    final diff = now.difference(lastActive);

    if (diff.inMinutes < 2) {
      return 'Active just now';
    } else if (diff.inMinutes < 60) {
      return 'Active ${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return 'Active ${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return 'Active ${diff.inDays}d ago';
    } else {
      return 'Active ${DateFormat('MMM d, y').format(lastActive)}';
    }
  }

  UserDevice copyWith({
    String? id,
    String? userId,
    String? deviceId,
    String? deviceName,
    String? deviceOs,
    String? ipAddress,
    bool? isActiveChat,
    DateTime? lastActive,
    DateTime? createdAt,
  }) {
    return UserDevice(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      deviceId: deviceId ?? this.deviceId,
      deviceName: deviceName ?? this.deviceName,
      deviceOs: deviceOs ?? this.deviceOs,
      ipAddress: ipAddress ?? this.ipAddress,
      isActiveChat: isActiveChat ?? this.isActiveChat,
      lastActive: lastActive ?? this.lastActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
