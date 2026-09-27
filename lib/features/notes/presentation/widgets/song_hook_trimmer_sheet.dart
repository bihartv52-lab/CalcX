import 'dart:math';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/features/notes/services/ritune_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SongHookTrimmerSheet extends ConsumerStatefulWidget {
  const SongHookTrimmerSheet({
    super.key,
    required this.track,
  });

  final RiTuneTrack track;

  static Future<RiTuneTrack?> show(BuildContext context, RiTuneTrack track) {
    return showModalBottomSheet<RiTuneTrack>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SongHookTrimmerSheet(track: track),
    );
  }

  @override
  ConsumerState<SongHookTrimmerSheet> createState() => _SongHookTrimmerSheetState();
}

class _SongHookTrimmerSheetState extends ConsumerState<SongHookTrimmerSheet>
    with SingleTickerProviderStateMixin {
  late int _startSeconds;
  late int _durationSeconds;
  late AnimationController _waveAnimController;
  final List<double> _waveformHeights = [];

  bool _isFullTrack = false;

  @override
  void initState() {
    super.initState();
    _startSeconds = widget.track.snippetStartSeconds;
    final initialDur = widget.track.snippetDurationSeconds;
    if (initialDur <= 0 || initialDur >= widget.track.durationSeconds) {
      _isFullTrack = true;
      _durationSeconds = 0;
    } else {
      _durationSeconds = initialDur.clamp(10, 30);
    }
    _waveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Generate pseudo-random realistic waveform bar heights for this song
    final rand = Random(widget.track.title.hashCode);
    for (int i = 0; i < 30; i++) {
      _waveformHeights.add(0.25 + rand.nextDouble() * 0.75);
    }

    // Start playing the preview at current hook start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewSnippet();
    });
  }

  @override
  void dispose() {
    _waveAnimController.dispose();
    super.dispose();
  }

  void _previewSnippet() {
    ref.read(ritunePlaybackProvider.notifier).togglePlay(
          widget.track,
          startSeconds: _startSeconds,
          durationSeconds: _isFullTrack ? 0 : _durationSeconds,
          isFullLength: _isFullTrack,
        );
  }

  String _formatTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playbackState = ref.watch(ritunePlaybackProvider);
    final isPlaying = playbackState.playingTrackId == widget.track.id && playbackState.isPlaying;

    final effectiveDur = _isFullTrack ? widget.track.durationSeconds : _durationSeconds;
    final maxStart = max(0, widget.track.durationSeconds - effectiveDur);
    final currentSliderVal = _startSeconds.clamp(0, maxStart).toDouble();

    // Classic Neo-Luxe Premium Palette
    const goldPrimary = Color(0xFFD4AF37);
    const goldLight = Color(0xFFE5C07B);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101420) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, spreadRadius: 4),
        ],
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [goldLight, goldPrimary],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.music_note_rounded, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RiTune Song Setup',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Select a hook, chorus, or attach the full length track',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  ref.read(ritunePlaybackProvider.notifier).stop();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Track Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF171B29) : const Color(0xFFF3F5F9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isPlaying ? goldPrimary.withValues(alpha: 0.6) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: widget.track.artwork,
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 52,
                      height: 52,
                      color: Colors.grey[800],
                      child: const Icon(Icons.music_note_rounded, color: Colors.white70),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.track.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                    color: goldPrimary,
                    size: 38,
                  ),
                  onPressed: () {
                    _previewSnippet();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Duration Selector (15s Hook vs 30s Chorus vs Full Track)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('15s Hook', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: !_isFullTrack && _durationSeconds == 15,
                selectedColor: goldLight,
                labelStyle: TextStyle(
                  color: (!_isFullTrack && _durationSeconds == 15) ? Colors.black : (isDark ? Colors.white : Colors.black87),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _isFullTrack = false;
                      _durationSeconds = 15;
                      if (_startSeconds > max(0, widget.track.durationSeconds - 15)) {
                        _startSeconds = max(0, widget.track.durationSeconds - 15);
                      }
                    });
                    _previewSnippet();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('30s Chorus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: !_isFullTrack && _durationSeconds == 30,
                selectedColor: goldLight,
                labelStyle: TextStyle(
                  color: (!_isFullTrack && _durationSeconds == 30) ? Colors.black : (isDark ? Colors.white : Colors.black87),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _isFullTrack = false;
                      _durationSeconds = 30;
                      if (_startSeconds > max(0, widget.track.durationSeconds - 30)) {
                        _startSeconds = max(0, widget.track.durationSeconds - 30);
                      }
                    });
                    _previewSnippet();
                  }
                },
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Full Track 🎵', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                selected: _isFullTrack,
                selectedColor: goldLight,
                labelStyle: TextStyle(
                  color: _isFullTrack ? Colors.black : (isDark ? Colors.white : Colors.black87),
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _isFullTrack = true;
                      _durationSeconds = 0;
                      _startSeconds = 0;
                    });
                    _previewSnippet();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Visual Waveform representation
          AnimatedBuilder(
            animation: _waveAnimController,
            builder: (context, _) {
              return Container(
                height: 54,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161A26) : const Color(0xFFEEF2F6),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(_waveformHeights.length, (index) {
                    final normalizedIdx = index / _waveformHeights.length;
                    final hookStartNorm = maxStart > 0 ? _startSeconds / widget.track.durationSeconds : 0.0;
                    final hookEndNorm = _isFullTrack
                        ? 1.0
                        : (_startSeconds + _durationSeconds) / widget.track.durationSeconds;

                    final isInHook = _isFullTrack || (normalizedIdx >= hookStartNorm && normalizedIdx <= hookEndNorm);

                    double heightMultiplier = _waveformHeights[index];
                    if (isPlaying && isInHook) {
                      heightMultiplier = (heightMultiplier + sin((_waveAnimController.value * pi) + index))
                          .clamp(0.2, 1.0);
                    }

                    return Container(
                      width: 4.5,
                      height: 44 * heightMultiplier,
                      decoration: BoxDecoration(
                        color: isInHook
                            ? goldLight
                            : (isDark ? Colors.white24 : Colors.black26),
                        borderRadius: BorderRadius.circular(3),
                        boxShadow: isInHook && isPlaying
                            ? [
                                BoxShadow(
                                  color: goldPrimary.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              );
            },
          ),
          const SizedBox(height: 14),

          // Slider & Time Display
          if (!_isFullTrack && maxStart > 0) ...[
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: goldPrimary,
                inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                thumbColor: goldPrimary,
                overlayColor: goldPrimary.withValues(alpha: 0.2),
                trackHeight: 5,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              ),
              child: Slider(
                value: currentSliderVal,
                min: 0,
                max: maxStart.toDouble(),
                onChanged: (val) {
                  setState(() {
                    _startSeconds = val.round();
                  });
                },
                onChangeEnd: (_) {
                  _previewSnippet();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: goldPrimary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: goldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Starts at ${_formatTime(_startSeconds)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: goldLight,
                      ),
                    ),
                  ),
                  Text(
                    'Playing ${_formatTime(_startSeconds)} - ${_formatTime(_startSeconds + _durationSeconds)}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ] else if (_isFullTrack) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.all_inclusive_rounded, size: 16, color: goldLight),
                  const SizedBox(width: 6),
                  Text(
                    'Full Track Selected (${_formatTime(widget.track.durationSeconds)}) • Plays in full',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: goldLight),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Confirm Hook & Attach Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: goldLight,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
              icon: const Icon(Icons.check_circle_rounded, size: 20),
              label: Text(
                _isFullTrack ? 'Attach Full Track to Note' : 'Set Hook & Attach to Note',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              onPressed: () {
                ref.read(ritunePlaybackProvider.notifier).stop();
                final updatedTrack = widget.track.copyWith(
                  snippetStartSeconds: _startSeconds,
                  snippetDurationSeconds: _isFullTrack ? 0 : _durationSeconds,
                );
                Navigator.of(context).pop(updatedTrack);
              },
            ),
          ),
        ],
      ),
    );
  }
}
