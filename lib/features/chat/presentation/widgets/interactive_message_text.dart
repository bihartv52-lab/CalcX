import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const Map<String, String> animatedEmojiMap = {
  '❤️': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Red%20Heart.webp',
  '👍': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Thumbs%20Up.webp',
  '😂': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20With%20Tears%20Of%20Joy.webp',
  '😮': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20With%20Open%20Mouth.webp',
  '😢': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Crying%20Face.webp',
  '🙏': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Folded%20Hands.webp',
  '🔥': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Animals%20and%20Nature/Fire.webp',
  '👏': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Clapping%20Hands.webp',
  '💀': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Skull.webp',
  '🤔': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Thinking%20Face.webp',
  '😎': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Smiling%20Face%20With%20Sunglasses.webp',
  '👀': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/People/Eyes.webp',
  '💯': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Hundred%20Points.webp',
  '🚀': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Travel%20and%20Places/Rocket.webp',
  '😭': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Loudly%20Crying%20Face.webp',
  '🤮': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20Vomiting.webp',
  '❌': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Cross%20Mark.webp',
  '✅': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Check%20Mark%20Button.webp',
  '💡': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Objects/Light%20Bulb.webp',
  '😉': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Winking%20Face.webp',
  '🌟': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Animals%20and%20Nature/Glowing%20Star.webp',
  '👑': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Objects/Crown.webp',
  '💔': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Broken%20Heart.webp',
  '😡': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Angry%20Face.webp',
  '😘': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Face%20Blowing%20A%20Kiss.webp',
  '💋': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Kiss%20Mark.webp',
  '😚': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Kissing%20Face%20With%20Closed%20Eyes.webp',
  '😗': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Smileys/Kissing%20Face.webp',
  '💖': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Sparkling%20Heart.webp',
  '💕': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Two%20Hearts.webp',
  '💓': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Beating%20Heart.webp',
  '💗': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Growing%20Heart.webp',
  '💘': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Heart%20With%20Arrow.webp',
  '💝': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Heart%20With%20Ribbon.webp',
  '💞': 'https://cdn.jsdelivr.net/gh/Tarikul-Islam-Anik/Telegram-Animated-Emojis@main/Symbols/Revolving%20Hearts.webp',
};

final RegExp emojiRegex = RegExp(
  r'(' +
      [
        '❤️', '👍', '😂', '😮', '😢', '🙏', '🔥', '👏', '💀', '🤔', '😎', '👀',
        '💯', '🚀', '😭', '🤮', '❌', '✅', '💡', '😉', '🌟', '👑', '💔', '😡',
        '😘', '💋', '😚', '😗', '💖', '💕', '💓', '💗', '💘', '💝', '💞'
      ].map((e) => RegExp.escape(e)).join('|') +
      r')',
);

// URL pattern matching http://, https://, and www. links
final RegExp urlPattern = RegExp(
  r'(https?:\/\/[^\s]+|www\.[^\s]+)',
  caseSensitive: false,
);

/// Renders message text with:
/// 1. Clickable links with external browser opening and hover effects
/// 2. Animated emoji rendering
/// 3. Search query match highlighting
class InteractiveMessageText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double emojiSize;
  final String? searchQuery;
  final bool isMe;

  const InteractiveMessageText({
    super.key,
    required this.text,
    required this.style,
    this.emojiSize = 18,
    this.searchQuery,
    this.isMe = false,
  });

  @override
  State<InteractiveMessageText> createState() => _InteractiveMessageTextState();
}

class _InteractiveMessageTextState extends State<InteractiveMessageText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  void _clearRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  Future<void> _openUrl(String rawUrl) async {
    String url = rawUrl;
    if (url.startsWith('www.')) {
      url = 'https://$url';
    }
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch URL: $url ($e)');
      }
    }
  }

  List<InlineSpan> _parseChunkWithUrls(String chunk, BuildContext context) {
    final List<InlineSpan> spans = [];
    final matches = urlPattern.allMatches(chunk).toList();

    if (matches.isEmpty) {
      return _parseChunkWithHighlight(chunk);
    }

    final isLight = Theme.of(context).brightness == Brightness.light;
    final linkColor = widget.isMe
        ? Colors.white.withValues(alpha: 0.95)
        : (isLight ? const Color(0xFF0095F6) : const Color(0xFF3897F0));

    int lastIndex = 0;
    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.addAll(_parseChunkWithHighlight(chunk.substring(lastIndex, match.start)));
      }

      final urlText = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _openUrl(urlText);
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: urlText,
          style: widget.style.copyWith(
            color: linkColor,
            decoration: TextDecoration.underline,
            decorationColor: linkColor.withOpacity(0.6),
            fontWeight: FontWeight.w600,
          ),
          recognizer: recognizer,
          mouseCursor: SystemMouseCursors.click,
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < chunk.length) {
      spans.addAll(_parseChunkWithHighlight(chunk.substring(lastIndex)));
    }

    return spans;
  }

  List<InlineSpan> _parseChunkWithHighlight(String chunk) {
    final query = widget.searchQuery;
    if (query == null || query.isEmpty) {
      return [TextSpan(text: chunk, style: widget.style)];
    }

    final List<InlineSpan> resultSpans = [];
    final lowerChunk = chunk.toLowerCase();
    final lowerQuery = query.toLowerCase();

    int index = 0;
    while (true) {
      final matchIdx = lowerChunk.indexOf(lowerQuery, index);
      if (matchIdx == -1) {
        resultSpans.add(TextSpan(
          text: chunk.substring(index),
          style: widget.style,
        ));
        break;
      }

      if (matchIdx > index) {
        resultSpans.add(TextSpan(
          text: chunk.substring(index, matchIdx),
          style: widget.style,
        ));
      }

      resultSpans.add(TextSpan(
        text: chunk.substring(matchIdx, matchIdx + query.length),
        style: widget.style.copyWith(
          backgroundColor: Colors.yellow.withOpacity(0.35),
          fontWeight: FontWeight.bold,
        ),
      ));

      index = matchIdx + query.length;
    }

    return resultSpans;
  }

  @override
  Widget build(BuildContext context) {
    _clearRecognizers();

    final text = widget.text;
    if (text.isEmpty) return const SizedBox.shrink();

    final trimmed = text.trim();
    final matches = emojiRegex.allMatches(trimmed).toList();

    int totalEmojiLen = 0;
    for (final match in matches) {
      totalEmojiLen += match.group(0)!.length;
    }

    final spaceCount = trimmed.split('').where((char) => RegExp(r'\s').hasMatch(char)).length;
    final isJumbo = matches.isNotEmpty &&
        matches.length <= 3 &&
        (totalEmojiLen + spaceCount >= trimmed.length);

    if (isJumbo) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Wrap(
          spacing: 4,
          children: matches.map((match) {
            final emoji = match.group(0)!;
            final url = animatedEmojiMap[emoji];
            if (url != null) {
              return Image.network(
                url,
                width: widget.emojiSize * 2.0,
                height: widget.emojiSize * 2.0,
                errorBuilder: (context, error, stackTrace) => Text(
                  emoji,
                  style: widget.style.copyWith(fontSize: widget.emojiSize * 1.8),
                ),
              );
            }
            return Text(
              emoji,
              style: widget.style.copyWith(fontSize: widget.emojiSize * 1.8),
            );
          }).toList(),
        ),
      );
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.addAll(_parseChunkWithUrls(text.substring(lastIndex, match.start), context));
      }

      final emoji = match.group(0)!;
      final url = animatedEmojiMap[emoji];

      if (url != null) {
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1.0),
            child: Image.network(
              url,
              width: widget.emojiSize,
              height: widget.emojiSize,
              errorBuilder: (context, error, stackTrace) => Text(
                emoji,
                style: widget.style.copyWith(fontSize: widget.emojiSize * 0.95),
              ),
            ),
          ),
        ));
      } else {
        spans.add(TextSpan(text: emoji, style: widget.style));
      }

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.addAll(_parseChunkWithUrls(text.substring(lastIndex), context));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      style: widget.style,
    );
  }
}
