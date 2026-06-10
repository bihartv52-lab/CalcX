import 'dart:async';
import 'dart:math';
import 'package:calcx/core/models/message.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/services/livekit_token_service.dart';
import 'package:calcx/features/calls/data/livekit_call_service.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/chat/presentation/chat_page.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:calcx/core/models/user_profile.dart';

class RoomSideChatPanel extends ConsumerStatefulWidget {
  const RoomSideChatPanel({
    super.key,
    required this.roomId,
    required this.roomName,
    required this.roomType,
    required this.sidePanelType,
    required this.onPanelTypeChanged,
  });

  final String roomId;
  final String roomName;
  final String roomType; // 'party' or 'game'
  final String sidePanelType; // 'none', 'chat', 'vc', 'call', 'moderation'
  final ValueChanged<String> onPanelTypeChanged;

  @override
  ConsumerState<RoomSideChatPanel> createState() => _RoomSideChatPanelState();
}

class _RoomSideChatPanelState extends ConsumerState<RoomSideChatPanel> {
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();
  final Map<String, String> _profileNames = {};

  bool _isInVcOrCall = false;
  bool _isVcConnecting = false;
  bool _isSpeakerOn = true;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    _handlePanelTypeChange(widget.sidePanelType);
  }

  @override
  void didUpdateWidget(covariant RoomSideChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sidePanelType != widget.sidePanelType) {
      _handlePanelTypeChange(widget.sidePanelType);
    }
  }

  @override
  void dispose() {
    _chatController.dispose();
    _chatScrollController.dispose();
    if (_isInVcOrCall) {
      _stopVcOrCall();
    }
    super.dispose();
  }

  void _handlePanelTypeChange(String newType) {
    if (newType == 'vc') {
      _startVcOrCall(true);
    } else if (newType == 'call') {
      _startVcOrCall(false);
    } else {
      _stopVcOrCall();
    }
  }

  Future<void> _startVcOrCall(bool video) async {
    await _stopVcOrCall();
    if (!mounted) return;
    setState(() {
      _isVcConnecting = true;
    });

    try {
      final myId = ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
      if (myId == null) throw StateError('Not logged in');

      final tokenService = ref.read(livekitTokenServiceProvider);
      final callService = ref.read(liveKitCallServiceProvider);

      final roomName = 'room_call_${widget.roomId}';
      final token = await tokenService.getToken(
        roomName: roomName,
        participantName: myId,
      );

      await callService.joinRoom(
        roomName: roomName,
        token: token,
        video: video,
      );

      try {
        await Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
      } catch (e) {
        debugPrint('Error setting initial speakerphone: $e');
      }

      callService.room?.addListener(_onRoomUpdate);

      if (mounted) {
        setState(() {
          _isInVcOrCall = true;
          _isVcConnecting = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVcConnecting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
      }
    }
  }

  Future<void> _stopVcOrCall() async {
    if (!_isInVcOrCall) return;
    try {
      ref.read(liveKitCallServiceProvider).room?.removeListener(_onRoomUpdate);
      await ref.read(liveKitCallServiceProvider).leaveRoom();
    } catch (e) {
      debugPrint('Error leaving call: $e');
    }
    if (mounted) {
      setState(() {
        _isInVcOrCall = false;
        _isVcConnecting = false;
      });
    }
  }

  void _toggleMute() async {
    await ref.read(liveKitCallServiceProvider).toggleMicrophone();
    if (mounted) {
      setState(() => _isMuted = !_isMuted);
    }
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _getParticipantName(String userId) async {
    if (_profileNames.containsKey(userId)) {
      return _profileNames[userId]!;
    }
    try {
      final repo = ref.read(friendsRepositoryProvider);
      final profile = await repo.getUserById(userId);
      if (profile != null) {
        final name = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
        if (mounted) {
          setState(() {
            _profileNames[userId] = name;
          });
        }
        return name;
      }
    } catch (_) {}
    return userId.substring(0, min(8, userId.length));
  }

  void _sendChatMessage() async {
    final content = _chatController.text.trim();
    if (content.isEmpty) return;
    try {
      await ref.read(chatRepositoryProvider).sendMessage(
            receiverId: null,
            content: content,
            roomId: widget.roomId,
          );
      _chatController.clear();
    } catch (_) {}
  }

  Future<void> _kickUser(String targetUserId) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;

      await client
          .from('room_participants')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('user_id', targetUserId);

      await client.from('messages').insert({
        'sender_id': client.auth.currentUser!.id,
        'room_id': widget.roomId,
        'content': targetUserId,
        'message_type': 'kick',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User kicked successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error kicking user: $e');
    }
  }

  Future<void> _sendMuteSignal(String targetUserId) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;

      await client.from('messages').insert({
        'sender_id': client.auth.currentUser!.id,
        'room_id': widget.roomId,
        'content': targetUserId,
        'message_type': 'mute',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent mute request to user.')),
        );
      }
    } catch (e) {
      debugPrint('Error sending mute request: $e');
    }
  }

  void _showInviteDialog() {
    final searchController = TextEditingController();
    List<UserProfile> searchResults = [];
    bool isSearching = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('Invite User', style: TextStyle(color: Colors.white)),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: searchController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Username or Display Name',
                    labelStyle: const TextStyle(color: Colors.white70),
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onChanged: (val) async {
                    if (val.trim().isEmpty) {
                      setDialogState(() {
                        searchResults = [];
                      });
                      return;
                    }
                    setDialogState(() => isSearching = true);
                    try {
                      final results = await ref.read(friendsRepositoryProvider).searchUsers(val.trim());
                      setDialogState(() {
                        searchResults = results;
                        isSearching = false;
                      });
                    } catch (_) {
                      setDialogState(() => isSearching = false);
                    }
                  },
                ),
                const SizedBox(height: 12),
                if (isSearching)
                  const Center(child: CircularProgressIndicator())
                else if (searchResults.isEmpty && searchController.text.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No users found', style: TextStyle(color: Colors.grey)),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (context, index) {
                        final user = searchResults[index];
                        return ListTile(
                          title: Text(user.displayName.isNotEmpty ? user.displayName : user.username,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text('@${user.username}', style: const TextStyle(color: Colors.grey)),
                          trailing: IconButton(
                            icon: const Icon(Icons.send_rounded, color: Colors.blueAccent),
                            onPressed: () async {
                              final client = SupabaseService.clientOrNull;
                              if (client == null) return;
                              try {
                                final myId = client.auth.currentUser?.id;
                                if (myId == null) return;
                                final myProfile = await client.from('profiles').select('username').eq('id', myId).single();
                                final myUsername = myProfile['username'] as String? ?? 'Someone';

                                await client.from('notifications').insert({
                                  'user_id': user.id,
                                  'type': 'room_invite',
                                  'title': 'Room Invitation 🍿🎮',
                                  'body': '$myUsername has invited you to join: ${widget.roomName}',
                                  'data': {
                                    'room_id': widget.roomId,
                                    'room_name': widget.roomName,
                                    'room_type': widget.roomType,
                                    'host_username': myUsername,
                                  },
                                });

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Invite sent to @${user.username}')),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error sending invite: $e')),
                                  );
                                }
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.sidePanelType == 'chat') {
      final messagesStream = ref.watch(chatRepositoryProvider).watchRoomMessages(widget.roomId);
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mini Chat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                      tooltip: 'Invite Friends',
                      onPressed: _showInviteDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      onPressed: () => widget.onPanelTypeChanged('none'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_chatScrollController.hasClients) {
                    _chatScrollController.jumpTo(_chatScrollController.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _chatScrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg.senderId == ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Column(
                        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String>(
                            future: _getParticipantName(msg.senderId),
                            builder: (context, snap) {
                              return Text(
                                snap.data ?? '...',
                                style: TextStyle(fontSize: 9, color: isMe ? Theme.of(context).colorScheme.primary : Colors.grey),
                              );
                            },
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: isMe ? Theme.of(context).colorScheme.primary.withOpacity(0.18) : Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: EmojiTextParser(
                              text: msg.content,
                              style: const TextStyle(fontSize: 12, color: Colors.white),
                              emojiSize: 18,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              color: Colors.black38,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _chatController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        hintStyle: const TextStyle(color: Colors.white54),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded, size: 16, color: Colors.blueAccent),
                    onPressed: _sendChatMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    } else if (widget.sidePanelType == 'vc') {
      if (_isVcConnecting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!_isInVcOrCall) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_rounded, size: 40, color: Colors.white54),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _startVcOrCall(true),
                child: const Text('Join Video Party'),
              ),
            ],
          ),
        );
      }
      final callService = ref.watch(liveKitCallServiceProvider);
      final room = callService.room;
      final remotes = room?.remoteParticipants.values.toList() ?? [];
      final localTrack = room?.localParticipant?.videoTrackPublications.firstOrNull?.track;

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Video Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                IconButton(
                  icon: const Icon(Icons.call_end_rounded, color: Colors.red, size: 16),
                  onPressed: _stopVcOrCall,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (localTrack != null)
                  Container(
                    height: 110,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: VideoTrackRenderer(localTrack as VideoTrack, fit: VideoViewFit.cover),
                    ),
                  ),
                ...remotes.map((p) {
                  final videoTrack = p.videoTrackPublications.firstOrNull?.track;
                  return Container(
                    height: 110,
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: videoTrack != null
                          ? VideoTrackRenderer(videoTrack as VideoTrack, fit: VideoViewFit.cover)
                          : FutureBuilder<String>(
                              future: _getParticipantName(p.identity),
                              builder: (context, snap) {
                                return Center(
                                  child: Text(
                                    snap.data ?? '...',
                                    style: const TextStyle(fontSize: 12, color: Colors.white),
                                  ),
                                );
                              },
                            ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    } else if (widget.sidePanelType == 'call') {
      if (_isVcConnecting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (!_isInVcOrCall) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call_rounded, size: 40, color: Colors.white54),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => _startVcOrCall(false),
                child: const Text('Join Voice Party'),
              ),
            ],
          ),
        );
      }
      final callService = ref.watch(liveKitCallServiceProvider);
      final room = callService.room;
      final remotes = room?.remoteParticipants.values.toList() ?? [];

      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Voice Party', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded, size: 16, color: Colors.white70),
                      onPressed: () async {
                        setState(() {
                          _isSpeakerOn = !_isSpeakerOn;
                        });
                        try {
                          await Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
                        } catch (e) {
                          debugPrint('Error toggling speakerphone: $e');
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.call_end_rounded, color: Colors.red, size: 16),
                      onPressed: _stopVcOrCall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(4),
              children: [
                ListTile(
                  dense: true,
                  leading: const CircleAvatar(
                    radius: 12,
                    child: Icon(Icons.person, size: 12),
                  ),
                  title: const Text('You', style: TextStyle(fontSize: 12, color: Colors.white)),
                  trailing: IconButton(
                    icon: Icon(_isMuted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 16),
                    color: _isMuted ? Colors.red : Colors.green,
                    onPressed: _toggleMute,
                  ),
                ),
                ...remotes.map((p) {
                  return FutureBuilder<String>(
                    future: _getParticipantName(p.identity),
                    builder: (context, snap) {
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          child: Text(p.identity.isNotEmpty ? p.identity[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 10)),
                        ),
                        title: Text(snap.data ?? '...', style: const TextStyle(fontSize: 12, color: Colors.white)),
                        trailing: Icon(
                          p.isMicrophoneEnabled() ? Icons.mic_rounded : Icons.mic_off_rounded,
                          size: 16,
                          color: p.isMicrophoneEnabled() ? Colors.green : Colors.red,
                        ),
                      );
                    },
                  );
                }),
              ],
            ),
          ),
        ],
      );
    } else if (widget.sidePanelType == 'moderation') {
      final participantsStream = ref.watch(roomRepositoryProvider).watchRoomParticipants(widget.roomId);
      final myId = ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
      
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: Colors.black45,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.person_add_rounded, size: 16, color: Colors.white),
                      tooltip: 'Invite Friends',
                      onPressed: _showInviteDialog,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      onPressed: () => widget.onPanelTypeChanged('none'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: participantsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final participants = snapshot.data ?? [];
                
                // Try to determine the host
                String? hostId;
                for (final p in participants) {
                  if (p['role'] == 'host') {
                    hostId = p['user_id'] as String?;
                  }
                }
                final isHost = myId != null && hostId != null && myId == hostId;

                return ListView.builder(
                  padding: const EdgeInsets.all(4),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final p = participants[index];
                    final userId = p['user_id'] as String;
                    final isUserMe = userId == myId;
                    final isUserHost = userId == hostId;

                    return FutureBuilder<String>(
                      future: _getParticipantName(userId),
                      builder: (context, nameSnap) {
                        final displayName = nameSnap.data ?? userId.substring(0, min(8, userId.length));
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            radius: 12,
                            child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U', style: const TextStyle(fontSize: 10)),
                          ),
                          title: Text(
                            displayName + (isUserMe ? ' (You)' : '') + (isUserHost ? ' [Host]' : ''),
                            style: const TextStyle(fontSize: 12, color: Colors.white),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isHost && !isUserHost && !isUserMe) ...[
                                IconButton(
                                  icon: const Icon(Icons.mic_off_rounded, color: Colors.amberAccent, size: 16),
                                  tooltip: 'Mute Participant',
                                  onPressed: () => _sendMuteSignal(userId),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 16),
                                  tooltip: 'Kick Participant',
                                  onPressed: () => _kickUser(userId),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
