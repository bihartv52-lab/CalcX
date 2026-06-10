import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:calcx/features/rooms/presentation/room_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RoomsTabNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setTab(int val) => state = val;
}

final roomsTabProvider = NotifierProvider<RoomsTabNotifier, int>(RoomsTabNotifier.new);

class RoomsPage extends ConsumerWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(roomsTabProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 110),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeTab == 0 ? 'Party rooms' : 'Game Zone',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeTab == 0
                        ? 'Watch, listen, chat, and call in synced rooms.'
                        : 'Play real-time multiplayer Ludo, Skribbl, and XO with friends.',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              tooltip: activeTab == 0 ? 'Create party room' : 'Create game room',
              onPressed: () => _showCreateRoomDialog(context, ref),
              icon: const Icon(Icons.add_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<int>(
                segments: const [
                  ButtonSegment(
                    value: 0,
                    label: Text('Party Rooms 🍿'),
                    icon: Icon(Icons.movie_filter_rounded),
                  ),
                  ButtonSegment(
                    value: 1,
                    label: Text('Game Zone 🎮'),
                    icon: Icon(Icons.sports_esports_rounded),
                  ),
                ],
                selected: {activeTab},
                onSelectionChanged: (val) {
                  ref.read(roomsTabProvider.notifier).setTab(val.first);
                },
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  selectedForegroundColor: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        
        // Show real rooms from Supabase
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: ref.read(roomRepositoryProvider).watchRoomsByType(activeTab == 0 ? 'party' : 'game'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading rooms',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        snapshot.error.toString(),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.5),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            final rooms = snapshot.data ?? [];

            if (rooms.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.meeting_room_rounded,
                        size: 64,
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No rooms yet',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a room to watch, listen, and chat together!',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth > 760 ? 2 : 1;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 2 ? 1.72 : 1.5,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return _RoomCard(
                      roomId: room['id'] as String,
                      title: room['name'] as String,
                      subtitle: _getRoomTypeDescription(room['visibility'] as String?),
                      icon: _getRoomIcon(room['visibility'] as String?),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RoomDetailPage(roomId: room['id'] as String),
                          ),
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  String _getRoomTypeDescription(String? visibility) {
    if (visibility == 'private') {
      return 'Private room - Invite only';
    }
    return 'Public room - Anyone can join';
  }

  IconData _getRoomIcon(String? visibility) {
    if (visibility == 'private') {
      return Icons.lock_rounded;
    }
    return Icons.public_rounded;
  }

  void _showCreateRoomDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    bool isPrivate = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: const Text('Create Room'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Room Name',
                  hintText: 'Enter room name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Private Room'),
                subtitle: const Text('Only invited users can join'),
                value: isPrivate,
                onChanged: (value) {
                  setState(() {
                    isPrivate = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a room name')),
                  );
                  return;
                }

                try {
                  final activeTab = ref.read(roomsTabProvider);
                  final roomId = await ref.read(roomRepositoryProvider).createRoom(
                    name: name,
                    isPrivate: isPrivate,
                    roomType: activeTab == 1 ? 'game' : 'party',
                  );
                  
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoomDetailPage(roomId: roomId),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error creating room: $e')),
                    );
                  }
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoomCard extends ConsumerWidget {
  const _RoomCard({
    required this.roomId,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String roomId;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const Spacer(),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: ref.read(roomRepositoryProvider).watchRoomParticipants(roomId),
                builder: (context, snapshot) {
                  final participantCount = snapshot.data?.length ?? 0;
                  if (participantCount == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_rounded,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          participantCount.toString(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          const Spacer(),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
