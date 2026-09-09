import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A sleek copy button designed to appear when hovering over a message bubble
/// on web or desktop, giving instant tactile clipboard feedback.
class MessageHoverCopyButton extends StatefulWidget {
  final String textToCopy;
  final bool isVisible;
  final bool isMe;

  const MessageHoverCopyButton({
    super.key,
    required this.textToCopy,
    required this.isVisible,
    this.isMe = false,
  });

  @override
  State<MessageHoverCopyButton> createState() => _MessageHoverCopyButtonState();
}

class _MessageHoverCopyButtonState extends State<MessageHoverCopyButton> {
  bool _copied = false;

  Future<void> _copyText() async {
    if (widget.textToCopy.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: widget.textToCopy));
    HapticFeedback.lightImpact();

    if (mounted) {
      setState(() {
        _copied = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _copied = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return AnimatedOpacity(
      opacity: widget.isVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !widget.isVisible,
        child: Tooltip(
          message: _copied ? 'Copied!' : 'Copy message text',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _copyText,
              borderRadius: BorderRadius.circular(16),
              hoverColor: isLight ? Colors.black12 : Colors.white24,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isLight ? const Color(0xFFF0F0F0) : const Color(0xFF2C2C2E),
                  border: Border.all(
                    color: isLight ? Colors.black12 : Colors.white12,
                    width: 0.8,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(
                  _copied ? Icons.check_rounded : Icons.content_copy_rounded,
                  size: 13,
                  color: _copied
                      ? const Color(0xFF34C759)
                      : (isLight ? Colors.black87 : Colors.white70),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A wrapper widget that listens for hover events on web and desktop,
/// seamlessly revealing the [MessageHoverCopyButton] alongside the child message.
class MessageHoverWrapper extends StatefulWidget {
  final Widget child;
  final String textToCopy;
  final bool isMe;

  const MessageHoverWrapper({
    super.key,
    required this.child,
    required this.textToCopy,
    this.isMe = false,
  });

  @override
  State<MessageHoverWrapper> createState() => _MessageHoverWrapperState();
}

class _MessageHoverWrapperState extends State<MessageHoverWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.textToCopy.isEmpty) {
      return widget.child;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (widget.isMe)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: MessageHoverCopyButton(
                textToCopy: widget.textToCopy,
                isVisible: _isHovered,
                isMe: widget.isMe,
              ),
            ),
          Flexible(child: widget.child),
          if (!widget.isMe)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: MessageHoverCopyButton(
                textToCopy: widget.textToCopy,
                isVisible: _isHovered,
                isMe: widget.isMe,
              ),
            ),
        ],
      ),
    );
  }
}
