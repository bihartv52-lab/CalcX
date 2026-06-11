import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/friends/presentation/user_search_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final friendsListProvider = FutureProvider<List<UserProfile>>((ref) async {
  final repository = ref.watch(friendsRepositoryProvider);
  return repository.getFriends();
});

final pendingRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(friendsRepositoryProvider);
  return repository.getPendingRequests();
});

class FriendsPage extends ConsumerWidget {
  const FriendsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final requestsAsync = ref.watch(pendingRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UserSearchPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(friendsListProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Friend Requests Section
            requestsAsync.when(
              data: (requests) {
                if (requests.isEmpty) {
                  return const SliverToBoxAdapter(child: SizedBox.shrink());
                }
                return SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'Friend Requests',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ...requests.map((request) {
                        final sender = UserProfile.fromMap(request['profiles']);
                        return _FriendRequestTile(
                          request: request,
                          sender: sender,
                        );
                      }),
                      const Divider(height: 32),
                    ],
                  ),
                );
              },
              loading: () => const SliverToBoxAdapter(
                child: LinearProgressIndicator(),
              ),
              error: (error, stack) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text('Error loading requests: $error'),
                ),
              ),
            ),

            // Friends List Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'My Friends',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),

            friendsAsync.when(
              data: (friends) {
                if (friends.isEmpty) {
                  return const SliverFillRemaining(
                    child: Center(
                      child: Text('No friends yet. Start searching!'),
                    ),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final friend = friends[index];
                      return _FriendTile(friend: friend);
                    },
                    childCount: friends.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => SliverFillRemaining(
                child: Center(
                  child: Text('Error loading friends: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FriendRequestTile extends ConsumerWidget {
  const _FriendRequestTile({
    required this.request,
    required this.sender,
  });

  final Map<String, dynamic> request;
  final UserProfile sender;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            sender.avatarUrl != null ? NetworkImage(sender.avatarUrl!) : null,
        child: sender.avatarUrl == null
            ? Text(sender.displayName.isNotEmpty
                ? sender.displayName[0].toUpperCase()
                : '?')
            : null,
      ),
      title: Text(sender.displayName),
      subtitle: Text('@${sender.username}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.check, color: Colors.green),
            onPressed: () async {
              try {
                final repository = ref.read(friendsRepositoryProvider);
                await repository.acceptFriendRequest(request['id']);
                ref.invalidate(pendingRequestsProvider);
                ref.invalidate(friendsListProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request accepted!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: () async {
              try {
                final repository = ref.read(friendsRepositoryProvider);
                await repository.rejectFriendRequest(request['id']);
                ref.invalidate(pendingRequestsProvider);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request rejected')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

class _FriendTile extends ConsumerWidget {
  const _FriendTile({required this.friend});

  final UserProfile friend;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Stack(
        children: [
          CircleAvatar(
            backgroundImage: friend.avatarUrl != null
                ? NetworkImage(friend.avatarUrl!)
                : null,
            child: friend.avatarUrl == null
                ? Text(friend.displayName.isNotEmpty
                    ? friend.displayName[0].toUpperCase()
                    : '?')
                : null,
          ),
          if (friend.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(friend.displayName),
      subtitle: Text('@${friend.username} • ${friend.getPresenceText()}'),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'message',
            child: Row(
              children: [
                Icon(Icons.message),
                SizedBox(width: 8),
                Text('Message'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'call',
            child: Row(
              children: [
                Icon(Icons.call),
                SizedBox(width: 8),
                Text('Call'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.person_remove, color: Colors.red),
                SizedBox(width: 8),
                Text('Remove Friend', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        onSelected: (value) async {
          switch (value) {
            case 'message':
              // Navigate to chat
              context.push('/chat/${friend.id}');
              break;
            case 'call':
              // Initiate audio call directly
              try {
                final callRepo = ref.read(callRepositoryProvider);
                final newCall = await callRepo.initiateCall(
                  receiverId: friend.id,
                  callType: 'audio',
                );
                if (context.mounted) {
                  ref.read(isCallScreenShowingProvider.notifier).state = true;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ActiveCallPage(call: newCall),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error starting call: $e')),
                  );
                }
              }
              break;
            case 'remove':
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove Friend'),
                  content: Text(
                      'Are you sure you want to remove ${friend.displayName} from your friends?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                try {
                  final repository = ref.read(friendsRepositoryProvider);
                  await repository.removeFriend(friend.id);
                  ref.invalidate(friendsListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Friend removed')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                }
              }
              break;
          }
        },
      ),
      onTap: () {
        // Navigate to chat with friend
        context.push('/chat/${friend.id}');
      },
    );
  }
}
