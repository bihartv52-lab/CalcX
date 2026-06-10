import 'dart:async';
import 'package:calcx/core/models/user_profile.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class UserSearchPage extends ConsumerStatefulWidget {
  const UserSearchPage({super.key});

  @override
  ConsumerState<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends ConsumerState<UserSearchPage> {
  final _searchController = TextEditingController();
  List<UserProfile> _searchResults = [];
  bool _isSearching = false;
  Timer? _debounce;
  final Set<String> _sentRequests = {};
  
  List<UserProfile> _friends = [];
  List<Map<String, dynamic>> _receivedRequests = [];
  List<Map<String, dynamic>> _sentRequestsDb = [];
  bool _isLoadingRelations = true;

  @override
  void initState() {
    super.initState();
    _loadRelations();
  }

  Future<void> _loadRelations() async {
    try {
      final repository = ref.read(friendsRepositoryProvider);
      final friends = await repository.getFriends();
      final received = await repository.getPendingRequests();
      final sent = await repository.getSentRequests();
      if (mounted) {
        setState(() {
          _friends = friends;
          _receivedRequests = received;
          _sentRequestsDb = sent;
          _isLoadingRelations = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingRelations = false);
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _searchUsers(query);
    });
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) return;

    setState(() => _isSearching = true);

    try {
      final repository = ref.read(friendsRepositoryProvider);
      final results = await repository.searchUsers(query.trim());
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearching = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  Future<void> _sendFriendRequest(String friendId) async {
    if (_sentRequests.contains(friendId)) return;

    try {
      final repository = ref.read(friendsRepositoryProvider);
      await repository.sendFriendRequest(friendId);
      setState(() => _sentRequests.add(friendId));
      await _loadRelations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Friend request sent!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _acceptFriendRequest(String requestId) async {
    try {
      final repository = ref.read(friendsRepositoryProvider);
      await repository.acceptFriendRequest(requestId);
      await _loadRelations();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request accepted!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = SupabaseService.clientOrNull?.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by username...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _isSearching = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                setState(() {}); // rebuild to show/hide clear button
                _onSearchChanged(value);
              },
            ),
          ),
          if (_isSearching || _isLoadingRelations)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            )
          else if (_searchResults.isEmpty && _searchController.text.trim().isNotEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.person_search, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No users found',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try a different username',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchResults.isEmpty)
            const Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.search_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Search for users',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Type a username to find people',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final user = _searchResults[index];
                  final isMe = user.id == myId;
                  final isAlreadyFriend = _friends.any((f) => f.id == user.id);
                  
                  // Check if a request has been sent in db or this session
                  final requestSent = _sentRequests.contains(user.id) || 
                      _sentRequestsDb.any((r) => r['receiver_id'] == user.id);
                  
                  // Check if a request has been received from this user
                  final receivedRequest = _receivedRequests.firstWhere(
                    (r) => r['sender_id'] == user.id,
                    orElse: () => <String, dynamic>{},
                  );
                  final hasReceivedRequest = receivedRequest.isNotEmpty;

                  Widget trailingWidget;
                  if (isMe) {
                    trailingWidget = const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text('(You)', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)),
                    );
                  } else if (isAlreadyFriend) {
                    trailingWidget = Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Friend', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.blue),
                          onPressed: () {
                            // Close search and go to chat
                            Navigator.pop(context);
                            // We use the route scheme `/chat/:id`
                            context.push('/chat/${user.id}');
                          },
                        ),
                      ],
                    );
                  } else if (hasReceivedRequest) {
                    trailingWidget = ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                      onPressed: () => _acceptFriendRequest(receivedRequest['id']),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept'),
                    );
                  } else if (requestSent) {
                    trailingWidget = const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, color: Colors.orange, size: 16),
                          SizedBox(width: 4),
                          Text('Requested', style: TextStyle(color: Colors.orange)),
                        ],
                      ),
                    );
                  } else {
                    trailingWidget = IconButton(
                      icon: const Icon(Icons.person_add_rounded),
                      color: Theme.of(context).colorScheme.primary,
                      tooltip: 'Send friend request',
                      onPressed: () => _sendFriendRequest(user.id),
                    );
                  }

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: user.avatarUrl != null
                          ? NetworkImage(user.avatarUrl!)
                          : null,
                      child: user.avatarUrl == null
                          ? Text(
                              (user.displayName.isNotEmpty
                                      ? user.displayName
                                      : user.username)[0]
                                  .toUpperCase(),
                            )
                          : null,
                    ),
                    title: Text(
                      user.displayName.isNotEmpty
                          ? user.displayName
                          : user.username,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('@${user.username}'),
                    trailing: trailingWidget,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
