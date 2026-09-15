import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ChatEmojiPicker extends StatefulWidget {
  final ValueChanged<String> onEmojiSelected;
  final VoidCallback onBackspace;
  final bool isLight;

  const ChatEmojiPicker({
    super.key,
    required this.onEmojiSelected,
    required this.onBackspace,
    this.isLight = false,
  });

  @override
  State<ChatEmojiPicker> createState() => _ChatEmojiPickerState();
}

class _ChatEmojiPickerState extends State<ChatEmojiPicker> {
  int _selectedCategoryIndex = 0;

  static const List<Map<String, dynamic>> _categories = [
    {
      'icon': '😀',
      'name': 'Smileys',
      'emojis': [
        '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂', '🙂', '🙃',
        '😉', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗', '😚', '😋',
        '😛', '😜', '🤪', '😝', '🤑', '🤗', '🤭', '🤫', '🤔', '🤐',
        '🤨', '😐', '😑', '😶', '😏', '😒', '🙄', '😬', '🤥', '😌',
        '😔', '😪', '🤤', '😴', '😷', '🤒', '🤕', '🤢', '🤮', '🤧',
        '🥵', '🥶', '🥴', '😵', '🤯', '🤠', '🥳', '🥸', '😎', '🤓',
        '🧐', '😕', '😟', '🙁', '😮', '😯', '😲', '😳', '🥺', '😦',
        '😧', '😨', '😰', '😥', '😢', '😭', '😱', '😖', '😣', '😞',
        '😓', '😩', '😫', '🥱', '😤', '😡', '😠', '🤬', '💀', '☠️',
      ],
    },
    {
      'icon': '👍',
      'name': 'Gestures',
      'emojis': [
        '👍', '👎', '👏', '🙌', '👐', '🤲', '🤝', '👊', '✊', '🤛',
        '🤜', '🤞', '✌️', '🤟', '🤘', '👌', '🤌', '🤏', '👈', '👉',
        '👆', '👇', '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '🤙', '💪',
        '🖕', '✍️', '🙏', '💅', '🤳', '💃', '🕺', '🏃', '🚶', '👀',
        '👁️', '👅', '👄', '💋', '🧠', '🫀', '🫁', '🩸', '🦠', '🫂',
      ],
    },
    {
      'icon': '❤️',
      'name': 'Hearts',
      'emojis': [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍', '🤎', '💔',
        '❣️', '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟', '💌',
        '🔥', '✨', '💫', '💥', '💢', '💯', '💤', '💨', '⚡', '🌟',
      ],
    },
    {
      'icon': '🎉',
      'name': 'Fun & Celebration',
      'emojis': [
        '🎉', '🎊', '🎈', '🎁', '🎂', '🍰', '🧁', '🥂', '🍻', '🍺',
        '🍷', '🍸', '🍹', '🍾', '🍕', '🍔', '🍟', '🌭', '🍿', '🍩',
        '🍦', '🍧', '🍨', '🍫', '🍬', '🍭', '☕', '🧃', '🥤', '🎮',
        '🕹️', '🎲', '🧩', '🎯', '🎳', '🎧', '🎸', '🎹', '🎬', '🏆',
      ],
    },
    {
      'icon': '🐱',
      'name': 'Animals & Nature',
      'emojis': [
        '🐱', '🐶', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼', '🐨', '🐯',
        '🦁', '🐮', '🐷', '🐸', '🐵', '🐔', '🐧', '🐦', '🦆', '🦅',
        '🦉', '🦇', '🐺', '🐗', '🐴', '🦄', '🐝', '🐛', '🦋', '🐌',
        '🌸', '🌹', '🌺', '🌻', '🌼', '🌷', '🌱', '🪴', '🌲', '🍀',
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final currentList = _categories[_selectedCategoryIndex]['emojis'] as List<String>;
    final isLight = widget.isLight;
    final bgColor = isLight ? const Color(0xFFF7F7F9) : const Color(0xFF141416);
    final borderColor = isLight ? const Color(0xFFE5E5EA) : const Color(0xFF28282B);

    return Container(
      height: 270,
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          top: BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Header tabs and Backspace button
          Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: borderColor, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    itemBuilder: (context, idx) {
                      final isSelected = idx == _selectedCategoryIndex;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _selectedCategoryIndex = idx);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isLight ? Colors.black12 : Colors.white12)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              _categories[idx]['icon'] as String,
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                // Backspace button
                IconButton(
                  icon: Icon(
                    Icons.backspace_outlined,
                    size: 20,
                    color: isLight ? Colors.black87 : Colors.white70,
                  ),
                  tooltip: 'Backspace',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    widget.onBackspace();
                  },
                ),
              ],
            ),
          ),

          // Emoji Grid View
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
              ),
              itemCount: currentList.length,
              itemBuilder: (context, index) {
                final emoji = currentList[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onEmojiSelected(emoji);
                  },
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
