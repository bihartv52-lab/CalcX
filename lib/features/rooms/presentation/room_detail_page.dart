import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:calcx/features/rooms/presentation/room_chat_page.dart';
import 'package:calcx/features/rooms/presentation/room_voice_call_page.dart';
import 'package:calcx/features/rooms/presentation/room_watch_party_page.dart';
import 'package:calcx/features/rooms/presentation/room_game_zone_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/friends/presentation/friends_page.dart';

class RoomDetailPage extends ConsumerStatefulWidget {
  const RoomDetailPage({super.key, required this.roomId});

  final String roomId;

  @override
  ConsumerState<RoomDetailPage> createState() => _RoomDetailPageState();
}

class _RoomDetailPageState extends ConsumerState<RoomDetailPage> {
  bool _isJoined = false;
  bool _isLoading = false;
  late Future<Map<String, dynamic>> _roomDetailsFuture;

  @override
  void initState() {
    super.initState();
    _checkIfJoined();
    _refreshRoomDetails();
  }

  void _refreshRoomDetails() {
    setState(() {
      _roomDetailsFuture = ref.read(roomRepositoryProvider).getRoomDetails(widget.roomId);
    });
  }

  Future<void> _checkIfJoined() async {
    try {
      final joined = await ref.read(roomRepositoryProvider).isUserInRoom(widget.roomId);
      if (mounted) setState(() => _isJoined = joined);
    } catch (_) {
      setState(() => _isJoined = false);
    }
  }

  Future<void> _joinRoom() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(roomRepositoryProvider).joinRoom(widget.roomId);
      _isJoined = true;
      _refreshRoomDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined room successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Could not join room. Please try again.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _leaveRoom() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await ref.read(roomRepositoryProvider).leaveRoom(widget.roomId);
      _isJoined = false;
      _refreshRoomDetails();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left room')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Could not leave room. Please try again.')),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Room'),
        actions: [
          if (_isJoined) ...[
            FutureBuilder<Map<String, dynamic>>(
              future: _roomDetailsFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final room = snapshot.data!;
                  final roomName = room['name'] as String;
                  return IconButton(
                    icon: const Icon(Icons.share_rounded),
                    tooltip: 'Share Room',
                    onPressed: () {
                      _showShareRoomSheet(context, widget.roomId, roomName);
                    },
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            IconButton(
              icon: const Icon(Icons.exit_to_app_rounded),
              tooltip: 'Leave Room',
              onPressed: _isLoading ? null : _leaveRoom,
            ),
          ],
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _roomDetailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red.withValues(alpha: 0.7),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading room',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final room = snapshot.data!;
          final roomName = room['name'] as String;
          final visibility = room['visibility'] as String?;
          final isPrivate = visibility == 'private';
          final roomType = room['room_type'] as String? ?? 'party';

          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              // Room Header
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isPrivate ? Icons.lock_rounded : Icons.public_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                roomName,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isPrivate ? 'Private Room' : 'Public Room',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.66),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (!_isJoined)
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _isLoading ? null : _joinRoom,
                          icon: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.login_rounded),
                          label: Text(_isLoading ? 'Joining...' : 'Join Room'),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Room Features
              if (_isJoined) ...[
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Room Features',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (roomType == 'game') ...[
                        _FeatureTile(
                          icon: Icons.sports_esports_rounded,
                          title: 'Game Zone',
                          subtitle: 'Play Ludo, Skribbl, and XO with friends',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RoomGameZonePage(
                                  roomId: widget.roomId,
                                  roomName: roomName,
                                ),
                              ),
                            );
                          },
                        ),
                      ] else ...[

                        _FeatureTile(
                          icon: Icons.movie_rounded,
                          title: 'Watch Party',
                          subtitle: 'Watch videos together',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RoomWatchPartyPage(
                                  roomId: widget.roomId,
                                  roomName: roomName,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                      const Divider(height: 24),
                      _FeatureTile(
                        icon: Icons.chat_rounded,
                        title: 'Room Chat',
                        subtitle: 'Chat with room members',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomChatPage(
                                  roomId: widget.roomId,
                                  roomName: roomName,
                                ),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _FeatureTile(
                        icon: Icons.call_rounded,
                        title: 'Voice Call',
                        subtitle: 'Start a voice call with everyone',
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomVoiceCallPage(
                                roomId: widget.roomId,
                                roomName: roomName,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Participants
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Participants',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<List<Map<String, dynamic>>>(
                        future: ref.read(roomRepositoryProvider).getRoomParticipantsWithProfiles(widget.roomId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          final participants = snapshot.data ?? [];

                          if (participants.isEmpty) {
                            return Text(
                              'No participants yet',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            );
                          }

                          return Column(
                            children: participants.map((participant) {
                              final profile = participant['profiles'] as Map<String, dynamic>?;
                              final username = profile?['username'] as String? ?? 'Unknown';
                              final displayName = profile?['display_name'] as String? ?? username;
                              final role = participant['role'] as String? ?? 'member';
                              
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      child: Text(displayName[0].toUpperCase()),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            displayName,
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                          Text(
                                            '@$username • ${role == 'host' ? 'Host' : 'Member'}',
                                            style: TextStyle(
                                              color: Colors.white.withValues(alpha: 0.6),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (role == 'host')
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 20,
                                      ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showShareRoomSheet(BuildContext context, String roomId, String roomName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F0F19),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final friendsAsync = ref.watch(friendsListProvider);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Share "$roomName"',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  const Text('Select a friend to send this room invite', style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: friendsAsync.when(
                      data: (friends) {
                        if (friends.isEmpty) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('No friends found to share with.', style: TextStyle(color: Colors.grey)),
                            ),
                          );
                        }
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          itemBuilder: (context, index) {
                            final friend = friends[index];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                                child: friend.avatarUrl == null ? Text(friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?') : null,
                              ),
                              title: Text(friend.displayName, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('@${friend.username}', style: const TextStyle(color: Colors.white30, fontSize: 11)),
                              trailing: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: () async {
                                  try {
                                    final chatRepo = ref.read(chatRepositoryProvider);
                                    await chatRepo.sendMediaMessage(
                                      receiverId: friend.id,
                                      messageType: 'share_room',
                                      mediaUrl: roomId,
                                      content: roomName,
                                    );
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Room invite shared with ${friend.displayName}! 👥'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: const Text('Could not share. Please try again.')),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Send', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            );
                          },
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
