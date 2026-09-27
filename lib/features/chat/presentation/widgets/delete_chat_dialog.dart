import 'package:flutter/material.dart';

enum DeleteChatChoice {
  lastTwoHours,
  lastDay,
  wholeChat,
  mediaOnly,
}

class DeleteChatDialog extends StatefulWidget {
  const DeleteChatDialog({
    super.key,
    required this.targetName,
    this.isRoom = false,
  });

  final String targetName;
  final bool isRoom;

  static Future<DeleteChatChoice?> show(
    BuildContext context, {
    required String targetName,
    bool isRoom = false,
  }) {
    return showModalBottomSheet<DeleteChatChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DeleteChatDialog(targetName: targetName, isRoom: isRoom),
    );
  }

  @override
  State<DeleteChatDialog> createState() => _DeleteChatDialogState();
}

class _DeleteChatDialogState extends State<DeleteChatDialog> {
  DeleteChatChoice _selected = DeleteChatChoice.lastTwoHours;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF141721) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.white54 : Colors.black54;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 20, spreadRadius: 4),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Clear Messages',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isRoom ? 'Room: ${widget.targetName}' : 'Chat with ${widget.targetName}',
                        style: TextStyle(fontSize: 13, color: subColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),
            Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
            const SizedBox(height: 12),

            // Options
            _buildOption(
              choice: DeleteChatChoice.lastTwoHours,
              icon: Icons.history_rounded,
              title: 'Last 2 Hours',
              subtitle: 'Delete messages sent or received in the past 2 hours',
              badge: 'Quick Purge',
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            _buildOption(
              choice: DeleteChatChoice.lastDay,
              icon: Icons.calendar_today_rounded,
              title: 'Last 24 Hours (1 Day)',
              subtitle: 'Delete messages from today and yesterday',
              badge: 'Daily',
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            _buildOption(
              choice: DeleteChatChoice.wholeChat,
              icon: Icons.delete_forever_rounded,
              title: 'Whole Chat',
              subtitle: 'Completely wipe the entire message history',
              badge: 'Wipe All',
              isDestructive: true,
              isDark: isDark,
            ),
            const SizedBox(height: 8),

            _buildOption(
              choice: DeleteChatChoice.mediaOnly,
              icon: Icons.photo_library_outlined,
              title: 'Delete All Media Only',
              subtitle: 'Purge photos, videos, audios & files at once while preserving texts',
              badge: 'Save Storage',
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: isDark ? Colors.white24 : Colors.black26),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_rounded, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Delete',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required DeleteChatChoice choice,
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    bool isDestructive = false,
    required bool isDark,
  }) {
    final isSelected = _selected == choice;
    final activeColor = isDestructive ? Colors.redAccent : const Color(0xFF00E676);

    return InkWell(
      onTap: () => setState(() => _selected = choice),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.02)),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isSelected ? activeColor : (isDark ? Colors.white70 : Colors.black54),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? (isDark ? Colors.white : Colors.black)
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? activeColor.withOpacity(0.18)
                              : (isDark ? Colors.white12 : Colors.black12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? activeColor : (isDark ? Colors.white60 : Colors.black54),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: isSelected ? activeColor : (isDark ? Colors.white30 : Colors.black26),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
