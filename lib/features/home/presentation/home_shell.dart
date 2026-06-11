import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/widgets/neon_scaffold.dart';
import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:calcx/features/calls/presentation/calls_page.dart';
import 'package:calcx/features/chat/presentation/chat_list_page.dart';
import 'package:calcx/features/friends/presentation/user_search_page.dart';
import 'package:calcx/features/rooms/presentation/rooms_page.dart';
import 'package:calcx/features/settings/presentation/settings_page.dart';
import 'package:calcx/features/friends/presentation/friends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calcx/core/services/supabase_service.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    _checkAppUpdate();
  }

  Future<void> _checkAuth() async {
    final signedIn = await ref.read(authRepositoryProvider).isSignedIn();
    if (!signedIn && mounted) {
      context.go(AppRoutes.auth);
    }
  }

  Future<void> _checkAppUpdate() async {
    final client = SupabaseService.clientOrNull;
    if (client == null) return;
    try {
      final response = await client
          .from('app_config')
          .select('value')
          .eq('key', 'version_config')
          .maybeSingle();

      if (response != null && mounted) {
        final config = response['value'] as Map<String, dynamic>;
        final latestCode = config['latest_version_code'] as int? ?? 1;
        final downloadUrl = config['download_url'] as String? ?? '';
        
        // Local version code is 1 (build code version 1)
        const localVersionCode = 1;
        
        if (latestCode > localVersionCode && downloadUrl.isNotEmpty) {
          _showUpdatePopup(downloadUrl);
        }
      }
    } catch (e) {
      debugPrint('Error checking app update: $e');
    }
  }

  void _showUpdatePopup(String downloadUrl) {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Prevent backing out
        child: AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: Colors.blueAccent),
              SizedBox(width: 12),
              Text('Update Available 🚀', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version of CalcX is available. Update now to access the latest real-time games, features, and fixes!',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              SizedBox(height: 8),
              Text(
                'Download the new APK directly from our official website.',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final uri = Uri.parse(downloadUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: const Text('Download APK Now', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  static const _pages = [
    ChatListPage(),
    RoomsPage(),
    CallsPage(),
    SettingsPage(),
  ];

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSearchPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pendingRequestsAsync = ref.watch(pendingRequestsProvider);
    final pendingCount = pendingRequestsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => 0,
    );

    final destinations = [
      NavigationDestination(
        icon: Badge(
          isLabelVisible: pendingCount > 0,
          label: Text(pendingCount.toString()),
          child: const Icon(Icons.chat_bubble_outline_rounded),
        ),
        selectedIcon: Badge(
          isLabelVisible: pendingCount > 0,
          label: Text(pendingCount.toString()),
          child: const Icon(Icons.chat_bubble_rounded),
        ),
        label: 'Chats',
      ),
      const NavigationDestination(
        icon: Icon(Icons.theaters_outlined),
        selectedIcon: Icon(Icons.theaters_rounded),
        label: 'Rooms',
      ),
      const NavigationDestination(
        icon: Icon(Icons.call_outlined),
        selectedIcon: Icon(Icons.call_rounded),
        label: 'Calls',
      ),
      const NavigationDestination(
        icon: Icon(Icons.tune_rounded),
        selectedIcon: Icon(Icons.tune_rounded),
        label: 'Settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 840;

        return NeonScaffold(
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: _index,
                  destinations: destinations,
                  onDestinationSelected: (value) => setState(() => _index = value),
                ),
          floatingActionButton: wide
              ? null
              : FloatingActionButton.small(
                  tooltip: 'Search users',
                  onPressed: () => _openSearch(context),
                  child: const Icon(Icons.person_search_rounded),
                ),
          child: Row(
            children: [
              if (wide)
                _SideRail(
                  index: _index,
                  onChanged: (value) => setState(() => _index = value),
                  pendingCount: pendingCount,
                ),
              Expanded(
                child: Column(
                  children: [
                    if (wide) const _TopBar(),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        child: _pages[_index],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar();

  void _showCallSelector(BuildContext context, WidgetRef ref, String callType) async {
    try {
      final repository = ref.read(friendsRepositoryProvider);
      final friends = await repository.getFriends();

      if (!context.mounted) return;

      if (friends.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have no friends to call. Add some first!')),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Start $callType Call'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundImage: friend.avatarUrl != null ? NetworkImage(friend.avatarUrl!) : null,
                    child: friend.avatarUrl == null
                        ? Text(friend.displayName.isNotEmpty ? friend.displayName[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(friend.displayName.isNotEmpty ? friend.displayName : friend.username),
                  subtitle: Text('@${friend.username}'),
                  onTap: () async {
                    Navigator.pop(context); // Close dialog
                    try {
                      final newCall = await ref.read(callRepositoryProvider).initiateCall(
                        receiverId: friend.id,
                        callType: callType,
                      );
                      if (context.mounted) {
                        ref.read(isCallScreenShowingProvider.notifier).state = true;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ActiveCallPage(call: newCall),
                          ),
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
                );
              },
            ),
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 84,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E).withValues(alpha: 0.55),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 22,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'CalcX',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Audio call',
            onPressed: () => _showCallSelector(context, ref, 'audio'),
            icon: const Icon(Icons.phone_in_talk_rounded),
          ),
          IconButton(
            tooltip: 'Video call',
            onPressed: () => _showCallSelector(context, ref, 'video'),
            icon: const Icon(Icons.videocam_rounded),
          ),
          IconButton(
            tooltip: 'Search users',
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const UserSearchPage(),
                ),
              );
            },
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({
    required this.index,
    required this.onChanged,
    required this.pendingCount,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final items = const [
      Icons.chat_bubble_rounded,
      Icons.theaters_rounded,
      Icons.call_rounded,
      Icons.tune_rounded,
    ];

    return Container(
      width: 96,
      decoration: BoxDecoration(
        color: const Color(0xFF0E0E0E).withValues(alpha: 0.58),
        border: Border(
          right: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 28),
          Text(
            'CX',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 48),
          for (var i = 0; i < items.length; i++)
            Badge(
              isLabelVisible: i == 0 && pendingCount > 0,
              label: Text(pendingCount.toString()),
              child: _RailButton(
                selected: index == i,
                icon: items[i],
                onTap: () => onChanged(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.selected,
    required this.icon,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 74,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: selected ? 5 : 0,
            height: 36,
            decoration: BoxDecoration(
              color: primary,
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(999),
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.65),
                  blurRadius: 16,
                ),
              ],
            ),
          ),
          Center(
            child: IconButton(
              onPressed: onTap,
              color: selected ? primary : Colors.white.withValues(alpha: 0.60),
              icon: Icon(icon),
            ),
          ),
        ],
      ),
    );
  }
}
