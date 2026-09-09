import 'package:calcx/core/models/message.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/chat/presentation/chat_list_page.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ForwardRecipientPickerDialog extends ConsumerStatefulWidget {
  const ForwardRecipientPickerDialog({
    super.key,
    required this.messagesToForward,
  });

  final List<Message> messagesToForward;

  static Future<bool?> show(BuildContext context, List<Message> messages) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ForwardRecipientPickerDialog(messagesToForward: messages),
    );
  }

  @override
  ConsumerState<ForwardRecipientPickerDialog> createState() => _ForwardRecipientPickerDialogState();
}

class _ForwardRecipientPickerDialogState extends ConsumerState<ForwardRecipientPickerDialog> {
  final Set<String> _selectedUserIds = {};
  final Set<String> _selectedRoomIds = {};
  String _searchQuery = '';
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final recentChatsAsync = ref.watch(recentChatsProvider);
    final roomsStream = ref.watch(roomRepositoryProvider).watchPublicRooms();

    final totalSelected = _selectedUserIds.length + _selectedRoomIds.length;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF141414),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle & Header
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isLight ? Colors.grey[300] : Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Text(
                  'Forward ${widget.messagesToForward.length} Message${widget.messagesToForward.length > 1 ? "s" : ""}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isLight ? Colors.black87 : Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context, false),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              style: TextStyle(fontSize: 14, color: isLight ? Colors.black87 : Colors.white),
              decoration: InputDecoration(
                hintText: 'Search friends or rooms...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
                filled: true,
                fillColor: isLight ? const Color(0xFFF0F0F2) : const Color(0xFF222224),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // Scrollable List of Friends and Rooms
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Friends Section
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Direct Messages',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.grey[600] : Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                recentChatsAsync.when(
                  data: (chats) {
                    final filteredChats = chats.where((c) {
                      final profile = c['partner_profile'] as Map<String, dynamic>?;
                      final name = (profile?['display_name'] ?? profile?['username'] ?? 'User').toString().toLowerCase();
                      return _searchQuery.isEmpty || name.contains(_searchQuery);
                    }).toList();

                    if (filteredChats.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('No matching chats', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      );
                    }

                    return Column(
                      children: filteredChats.map((c) {
                        final partnerId = c['partner_id'] as String;
                        final profile = c['partner_profile'] as Map<String, dynamic>?;
                        final name = profile?['display_name'] as String? ?? profile?['username'] as String? ?? 'User';
                        final isSelected = _selectedUserIds.contains(partnerId);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedUserIds.add(partnerId);
                              } else {
                                _selectedUserIds.remove(partnerId);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            radius: 16,
                            backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                            backgroundImage: profile?['avatar_url'] != null ? NetworkImage(profile!['avatar_url']) : null,
                            child: profile?['avatar_url'] == null
                                ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text(name, style: TextStyle(fontSize: 14, color: isLight ? Colors.black87 : Colors.white)),
                          activeColor: Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(strokeWidth: 2))),
                  error: (e, s) => const SizedBox.shrink(),
                ),

                const SizedBox(height: 16),

                // Rooms Section
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'Rooms',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isLight ? Colors.grey[600] : Colors.grey[400],
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                StreamBuilder<List<Map<String, dynamic>>>(
                  stream: roomsStream,
                  builder: (context, snapshot) {
                    final rooms = snapshot.data ?? [];
                    final filteredRooms = rooms.where((r) {
                      final name = (r['name'] ?? '').toString().toLowerCase();
                      return _searchQuery.isEmpty || name.contains(_searchQuery);
                    }).toList();

                    if (filteredRooms.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text('No matching rooms', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      );
                    }

                    return Column(
                      children: filteredRooms.map((r) {
                        final roomId = r['id'] as String;
                        final name = r['name'] as String? ?? 'Room';
                        final isSelected = _selectedRoomIds.contains(roomId);

                        return CheckboxListTile(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedRoomIds.add(roomId);
                              } else {
                                _selectedRoomIds.remove(roomId);
                              }
                            });
                          },
                          secondary: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.purple.withOpacity(0.15),
                            child: const Icon(Icons.meeting_room_rounded, size: 16, color: Colors.purple),
                          ),
                          title: Text(name, style: TextStyle(fontSize: 14, color: isLight ? Colors.black87 : Colors.white)),
                          activeColor: Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),

          // Send Action Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: isLight ? const Color(0xFFE0E0E0) : const Color(0xFF2C2C2C), width: 0.5)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: totalSelected == 0 || _isSubmitting
                    ? null
                    : () async {
                        setState(() => _isSubmitting = true);
                        try {
                          await ref.read(chatRepositoryProvider).forwardMessages(
                                messages: widget.messagesToForward,
                                targetReceiverIds: _selectedUserIds.toList(),
                                targetRoomIds: _selectedRoomIds.toList(),
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Forwarded ${widget.messagesToForward.length} message${widget.messagesToForward.length > 1 ? "s" : ""} to $totalSelected recipient${totalSelected > 1 ? "s" : ""}',
                                ),
                              ),
                            );
                            Navigator.pop(context, true);
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to forward messages: $e')),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
                icon: _isSubmitting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(
                  _isSubmitting
                      ? 'Forwarding...'
                      : totalSelected > 0
                          ? 'Send to $totalSelected chat${totalSelected > 1 ? "s" : ""}'
                          : 'Select Recipients',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
