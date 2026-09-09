import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:calcx/features/friends/presentation/friends_page.dart';
import 'package:calcx/features/friends/presentation/user_search_page.dart';
import 'package:calcx/core/widgets/quick_panic_calculator_button.dart';

final recentChatsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final repository = ref.watch(chatRepositoryProvider);
  return repository.getRecentChats();
});

class ChatListPage extends ConsumerStatefulWidget {
  const ChatListPage({super.key});

  @override
  ConsumerState<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends ConsumerState<ChatListPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseService.clientOrNull != null;
    final chatsAsync = ref.watch(recentChatsProvider);
    final pendingRequestsAsync = ref.watch(pendingRequestsProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    final pendingCount = pendingRequestsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return Scaffold(
      backgroundColor: Colors.transparent, // NeonScaffold provides background
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(recentChatsProvider);
          ref.invalidate(pendingRequestsProvider);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 110),
          children: [
            _Header(
              title: 'Messages',
              actionIcon: Icons.people_outline_rounded,
              pendingCount: pendingCount,
              onActionPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendsPage()),
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Modern, clean Instagram-style search input
            TextField(
              decoration: InputDecoration(
                hintText: 'Search chats or usernames...',
                prefixIcon: const Icon(Icons.search_rounded, size: 22, color: Colors.grey),
                filled: true,
                fillColor: isLight ? const Color(0xFFF1F1F4) : const Color(0xFF1C1C1E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                suffixIcon: IconButton(
                  icon: Icon(
                    Icons.person_search_rounded,
                    color: isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0),
                  ),
                  tooltip: 'Find new friends',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserSearchPage(initialQuery: _searchQuery.trim()),
                      ),
                    );
                  },
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 16),
            
            if (_searchQuery.trim().isNotEmpty) ...[
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserSearchPage(initialQuery: _searchQuery.trim()),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: (isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0)).withOpacity(0.12),
                        child: Icon(
                          Icons.person_search_rounded,
                          color: isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Search all users for "${_searchQuery.trim()}"',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Tap to find anyone by username & start chat',
                              style: TextStyle(
                                fontSize: 12,
                                color: isLight ? Colors.black54 : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            
            const _ActiveFriendsBar(),
            const SizedBox(height: 8),
            
            if (!configured)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'Supabase not configured',
                        style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Check your .env file has SUPABASE_URL and SUPABASE_ANON_KEY',
                        style: TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              chatsAsync.when(
                data: (chats) {
                  if (chats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 56,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No messages yet',
                              style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Start a conversation with anyone by username!',
                              style: TextStyle(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const UserSearchPage(),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.person_search_rounded),
                              label: const Text('Search Users'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final filteredChats = chats.where((chat) {
                    final partnerProfile = chat['partner_profile'] as Map<String, dynamic>?;
                    if (partnerProfile == null) return false;
                    final displayName = (partnerProfile['display_name'] as String? ?? '').toLowerCase();
                    final username = (partnerProfile['username'] as String? ?? '').toLowerCase();
                    final q = _searchQuery.toLowerCase();
                    return displayName.contains(q) || username.contains(q);
                  }).toList();

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredChats.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      final lastMessage = chat['last_message'];
                      final partnerId = chat['partner_id'] as String;
                      final unreadCount = chat['unread_count'] as int;

                      final partnerProfile = chat['partner_profile'] as Map<String, dynamic>?;
                      final displayName = partnerProfile?['display_name'] as String? ?? 'Unknown';
                      final username = partnerProfile?['username'] as String? ?? '';
                      final avatarUrl = partnerProfile?['avatar_url'] as String?;
                      final content = lastMessage['content'] as String? ?? '';
                      final createdAt = DateTime.parse(lastMessage['created_at'] as String);
                      final messageType = lastMessage['message_type'] as String? ?? 'text';
                      final status = partnerProfile?['status'] as String? ?? 'offline';

                      String previewText = content;
                      if (messageType == 'image') {
                        previewText = '📷 Photo';
                      } else if (messageType == 'video') {
                        previewText = '🎥 Video';
                      } else if (messageType == 'audio') {
                        previewText = '🎵 Audio';
                      } else if (messageType == 'voice') {
                        previewText = '🎤 Voice message';
                      } else if (messageType == 'file') {
                        previewText = '📎 File';
                      }

                      return _ChatPreview(
                        name: displayName,
                        username: username,
                        avatarUrl: avatarUrl,
                        partnerId: partnerId,
                        message: previewText,
                        time: _formatTime(createdAt),
                        unread: unreadCount,
                        online: status == 'online',
                        onTap: () => context.push('/chat/$partnerId'),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (error, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'Error loading chats',
                          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          error.toString(),
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays == 0) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return DateFormat('EEEE').format(dateTime);
    } else {
      return DateFormat('MMM dd').format(dateTime);
    }
  }
}

class _ChatPreview extends ConsumerWidget {
  const _ChatPreview({
    required this.name,
    required this.username,
    this.avatarUrl,
    required this.partnerId,
    required this.message,
    required this.time,
    this.unread = 0,
    this.online = false,
    this.onTap,
  });

  final String name;
  final String username;
  final String? avatarUrl;
  final String partnerId;
  final String message;
  final String time;
  final int unread;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isLight = Theme.of(context).brightness == Brightness.light;
    final isTypingAsync = ref.watch(typingIndicatorProvider(partnerId));
    final isTyping = isTypingAsync.value ?? false;

    final primaryAccent = isLight ? const Color(0xFF0095F6) : const Color(0xFF3797F0);
    final unreadColor = isLight ? Colors.black87 : Colors.white;
    final readColor = isLight ? Colors.black54 : Colors.grey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            // Circular Avatar with cutout online status dot
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: colors.primary,
                          ),
                        )
                      : null,
                ),
                if (online)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isLight ? const Color(0xFFF6F5FA) : const Color(0xFF050505),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            
            // Name & message preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: unread > 0 ? FontWeight.bold : FontWeight.w500,
                      fontSize: 15,
                      color: unread > 0 ? unreadColor : (isLight ? Colors.black87 : Colors.white.withOpacity(0.9)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          isTyping ? 'typing...' : message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isTyping 
                                ? primaryAccent 
                                : (unread > 0 ? unreadColor : readColor),
                            fontWeight: (isTyping || unread > 0) ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '• $time',
                        style: TextStyle(
                          fontSize: 12,
                          color: unread > 0 ? unreadColor.withOpacity(0.8) : readColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Instagram-style unread blue dot
            if (unread > 0) ...[
              const SizedBox(width: 12),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: primaryAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.actionIcon,
    this.onActionPressed,
    this.pendingCount = 0,
  });

  final String title;
  final IconData actionIcon;
  final VoidCallback? onActionPressed;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 24,
                  letterSpacing: -0.5,
                  color: isLight ? Colors.black87 : Colors.white,
                ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const QuickPanicCalculatorButton(),
              const SizedBox(width: 4),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: onActionPressed,
                    icon: Icon(actionIcon, size: 24, color: isLight ? Colors.black87 : Colors.white),
                    style: IconButton.styleFrom(
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
              if (pendingCount > 0)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      pendingCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActiveFriendsBar extends ConsumerWidget {
  const _ActiveFriendsBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friendsAsync = ref.watch(friendsListProvider);
    final isLight = Theme.of(context).brightness == Brightness.light;

    return friendsAsync.when(
      data: (friends) {
        final activeFriends = friends.where((f) => f.isOnline).toList();
        if (activeFriends.isEmpty) return const SizedBox.shrink();
        
        return Container(
          height: 88,
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Active Now',
                style: TextStyle(
                  fontSize: 12, 
                  fontWeight: FontWeight.bold, 
                  color: isLight ? Colors.black54 : Colors.grey,
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: activeFriends.length,
                  itemBuilder: (context, index) {
                    final friend = activeFriends[index];
                    return GestureDetector(
                      onTap: () => context.push('/chat/${friend.id}'),
                      child: Container(
                        margin: const EdgeInsets.only(right: 14),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundImage: friend.avatarUrl != null
                                      ? NetworkImage(friend.avatarUrl!)
                                      : null,
                                  child: friend.avatarUrl == null
                                      ? Text(friend.displayName.isNotEmpty
                                          ? friend.displayName[0].toUpperCase()
                                          : '?')
                                      : null,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isLight ? const Color(0xFFF6F5FA) : const Color(0xFF050505),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              width: 48,
                              child: Text(
                                friend.displayName.split(' ')[0],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isLight ? Colors.black87 : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
