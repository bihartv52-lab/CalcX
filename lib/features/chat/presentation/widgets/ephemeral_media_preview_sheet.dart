import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EphemeralMediaPreviewSheet extends StatefulWidget {
  final XFile file;
  final bool isVideo;

  const EphemeralMediaPreviewSheet({
    super.key,
    required this.file,
    required this.isVideo,
  });

  static Future<String?> show(BuildContext context, {required XFile file, required bool isVideo}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => EphemeralMediaPreviewSheet(file: file, isVideo: isVideo),
    );
  }

  @override
  State<EphemeralMediaPreviewSheet> createState() => _EphemeralMediaPreviewSheetState();
}

class _EphemeralMediaPreviewSheetState extends State<EphemeralMediaPreviewSheet> {
  String _selectedMode = 'normal'; // 'normal', 'view_once', 'view_twice'

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final bgColor = isLight ? Colors.white : const Color(0xFF1E1E1E);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.isVideo ? 'Send Video' : 'Send Photo',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Preview thumbnail
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Center(
              child: widget.isVideo
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam_rounded, size: 48, color: Colors.blueAccent),
                        SizedBox(height: 8),
                        Text('Video ready to send', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    )
                  : (kIsWeb
                      ? Image.network(widget.file.path, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image_rounded, size: 48))
                      : Image.file(File(widget.file.path), fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image_rounded, size: 48))),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Viewing Options',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildModeOption(
                  id: 'normal',
                  icon: Icons.all_inclusive_rounded,
                  label: 'Keep in Chat',
                  subtitle: 'Standard',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeOption(
                  id: 'view_once',
                  badge: '1',
                  label: 'View Once',
                  subtitle: '1-time view',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeOption(
                  id: 'view_twice',
                  badge: '2',
                  label: 'View Twice',
                  subtitle: '2-times view',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _selectedMode == 'normal'
                  ? Colors.grey.withOpacity(0.12)
                  : const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _selectedMode == 'normal'
                    ? Colors.transparent
                    : const Color(0xFF10B981).withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _selectedMode == 'normal' ? Icons.info_outline_rounded : Icons.shield_rounded,
                  size: 16,
                  color: _selectedMode == 'normal' ? Colors.grey : const Color(0xFF10B981),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedMode == 'normal'
                        ? 'Standard media saved in chat history.'
                        : (_selectedMode == 'view_once'
                            ? 'Recipient can view once. Screenshot and downloading blocked.'
                            : 'Recipient can view twice. Screenshot and downloading blocked.'),
                    style: TextStyle(
                      fontSize: 11,
                      color: _selectedMode == 'normal' ? Colors.grey : const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3897F0),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _selectedMode == 'normal'
                  ? 'Send Media'
                  : (_selectedMode == 'view_once' ? 'Send View Once (1x)' : 'Send View Twice (2x)'),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onPressed: () => Navigator.pop(context, _selectedMode),
          ),
        ],
      ),
    );
  }

  Widget _buildModeOption({
    required String id,
    IconData? icon,
    String? badge,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selectedMode == id;
    final color = isSelected ? const Color(0xFF3897F0) : Colors.grey;

    return InkWell(
      onTap: () => setState(() => _selectedMode = id),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3897F0).withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFF3897F0) : Colors.grey.withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          children: [
            if (badge != null)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.8),
                ),
                child: Center(
                  child: Text(
                    badge,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else if (icon != null)
              Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFF3897F0) : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
