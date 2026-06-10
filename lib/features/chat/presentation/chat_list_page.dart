import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:calcx/features/friends/presentation/friends_page.dart';

final recentChatsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
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

    final pendingCount = pendingRequestsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(recentChatsProvider);
        ref.invalidate(pendingRequestsProvider);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 110),
        children: [
          _Header(
            title: 'Chats',
            subtitle: configured
                ? 'Realtime messages, presence, reactions, replies, and media.'
                : 'Connect Supabase to activate realtime chat.',
            actionIcon: Icons.people_rounded,
            pendingCount: pendingCount,
            onActionPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const FriendsPage()),
              );
            },
          ),
          const SizedBox(height: 18),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: configured ? const Icon(Icons.bolt_rounded) : null,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 18),
          if (!configured)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Supabase not configured',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
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
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No chats yet',
                            style: TextStyle(fontSize: 18, color: Colors.grey),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start a conversation with your friends!',
                            style: TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
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

                return Column(
                  children: filteredChats.map((chat) {
                    final lastMessage = chat['last_message'];
                    final partnerId = chat['partner_id'] as String;
                    final unreadCount = chat['unread_count'] as int;

                    // Get partner's profile (not sender's profile)
                    final partnerProfile =
                        chat['partner_profile'] as Map<String, dynamic>?;
                    final displayName =
                        partnerProfile?['display_name'] as String? ?? 'Unknown';
                    final content = lastMessage['content'] as String? ?? '';
                    final createdAt = DateTime.parse(
                      lastMessage['created_at'] as String,
                    );
                    final messageType =
                        lastMessage['message_type'] as String? ?? 'text';
                    final status =
                        partnerProfile?['status'] as String? ?? 'offline';

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
                      partnerId: partnerId,
                      message: previewText,
                      time: _formatTime(createdAt),
                      unread: unreadCount,
                      online: status == 'online',
                      onTap: () => context.push('/chat/$partnerId'),
                    );
                  }).toList(),
                );
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading chats',
                        style: TextStyle(color: Colors.red[300]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
    required this.partnerId,
    required this.message,
    required this.time,
    this.unread = 0,
    this.online = false,
    this.onTap,
  });

  final String name;
  final String partnerId;
  final String message;
  final String time;
  final int unread;
  final bool online;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final isTypingAsync = ref.watch(typingIndicatorProvider(partnerId));
    final isTyping = isTypingAsync.value ?? false;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: onTap,
      child: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: colors.primary.withValues(alpha: 0.18),
                child: Icon(Icons.person_rounded, color: colors.primary),
              ),
              if (online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF131313),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colors.primary.withValues(alpha: 0.55),
                          blurRadius: 12,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unread > 0
                              ? FontWeight.w900
                              : FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(
                        color: unread > 0
                            ? colors.primary
                            : Colors.white.withValues(alpha: 0.58),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isTyping ? 'typing...' : message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isTyping 
                        ? colors.primary 
                        : Colors.white.withValues(alpha: 0.72),
                    fontWeight: isTyping ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
          if (unread > 0) ...[
            const SizedBox(width: 12),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.primary.withValues(alpha: 0.55),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.30),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Text(
                unread.toString(),
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.actionIcon,
    this.onActionPressed,
    this.pendingCount = 0,
  });

  final String title;
  final String subtitle;
  final IconData actionIcon;
  final VoidCallback? onActionPressed;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
              ),
            ],
          ),
        ),
        Badge(
          isLabelVisible: pendingCount > 0,
          label: Text(pendingCount.toString()),
          child: IconButton.filled(
            tooltip: title,
            onPressed: onActionPressed,
            icon: Icon(actionIcon),
          ),
        ),
      ],
    );
  }
}
