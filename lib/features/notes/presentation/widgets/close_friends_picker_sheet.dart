import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/friends/presentation/friends_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CloseFriendsPickerSheet extends ConsumerStatefulWidget {
  const CloseFriendsPickerSheet({
    super.key,
    this.isSelectionMode = false,
    this.initialSelectedIds = const [],
    this.title = 'Close Friends',
  });

  final bool isSelectionMode;
  final List<String> initialSelectedIds;
  final String title;

  /// Open as Close Friends Manager
  static Future<void> showManager(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CloseFriendsPickerSheet(isSelectionMode: false),
    );
  }

  /// Open as Selected Friends Audience Picker
  static Future<List<String>?> showSelector(
    BuildContext context, {
    required List<String> initialSelectedIds,
  }) {
    return showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CloseFriendsPickerSheet(
        isSelectionMode: true,
        initialSelectedIds: initialSelectedIds,
        title: 'Selected Friends Audience',
      ),
    );
  }

  @override
  ConsumerState<CloseFriendsPickerSheet> createState() => _CloseFriendsPickerSheetState();
}

class _CloseFriendsPickerSheetState extends ConsumerState<CloseFriendsPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = widget.initialSelectedIds.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);
    final closeFriendIdsAsync = ref.watch(closeFriendIdsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final closeFriendsSet = closeFriendIdsAsync.value ?? <String>{};

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141721) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 20, spreadRadius: 5),
        ],
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.star_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        widget.isSelectionMode
                            ? '${_selectedIds.length} friends selected'
                            : '${closeFriendsSet.length} friends in Close Friends',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (widget.isSelectionMode)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(_selectedIds.toList());
                    },
                    child: const Text('Done', style: TextStyle(fontWeight: FontWeight.bold)),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: isDark ? const Color(0xFF1E2230) : const Color(0xFFF1F3F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Friends List
          Expanded(
            child: friendsAsync.when(
              data: (friends) {
                final filtered = friends.where((f) {
                  if (_searchQuery.isEmpty) return true;
                  final matchName = f.displayName.toLowerCase().contains(_searchQuery);
                  final matchUsername = f.username.toLowerCase().contains(_searchQuery);
                  return matchName || matchUsername;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline_rounded, size: 48, color: Colors.grey[600]),
                          const SizedBox(height: 12),
                          Text(
                            friends.isEmpty
                                ? 'No friends found yet.\nAdd friends to manage audience!'
                                : 'No matching friends found.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final friend = filtered[index];
                    final avatarUrl = friend.avatarUrl;
                    final displayName = friend.displayName.isNotEmpty
                        ? friend.displayName
                        : friend.username;

                    final isClose = closeFriendsSet.contains(friend.id);
                    final isSelected = _selectedIds.contains(friend.id);

                    return Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1A1E2B) : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(14),
                        border: (widget.isSelectionMode ? isSelected : isClose)
                            ? Border.all(color: const Color(0xFF10B981), width: 1.2)
                            : null,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: isDark ? const Color(0xFF25293A) : const Color(0xFFE2E8F0),
                          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                              ? CachedNetworkImageProvider(avatarUrl)
                              : null,
                          child: avatarUrl == null || avatarUrl.isEmpty
                              ? Text(
                                  displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                            if (!widget.isSelectionMode && isClose) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.star_rounded, size: 16, color: Color(0xFF10B981)),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          '@${friend.username}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: widget.isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                activeColor: const Color(0xFF10B981),
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedIds.add(friend.id);
                                    } else {
                                      _selectedIds.remove(friend.id);
                                    }
                                  });
                                },
                              )
                            : IconButton(
                                icon: Icon(
                                  isClose ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                  color: isClose ? const Color(0xFF10B981) : Colors.grey,
                                  size: 26,
                                ),
                                onPressed: () {
                                  ref
                                      .read(closeFriendIdsProvider.notifier)
                                      .toggle(friend.id, !isClose);
                                },
                              ),
                        onTap: () {
                          if (widget.isSelectionMode) {
                            setState(() {
                              if (isSelected) {
                                _selectedIds.remove(friend.id);
                              } else {
                                _selectedIds.add(friend.id);
                              }
                            });
                          } else {
                            ref
                                .read(closeFriendIdsProvider.notifier)
                                .toggle(friend.id, !isClose);
                          }
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(color: Color(0xFF10B981)),
              ),
              error: (err, _) => Center(
                child: Text('Error loading friends: $err', style: const TextStyle(color: Colors.redAccent)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
