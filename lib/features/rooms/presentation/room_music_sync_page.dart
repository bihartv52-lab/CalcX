import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:calcx/features/rooms/domain/playback_state.dart';
import 'package:calcx/features/media/data/media_repository.dart';
import 'package:calcx/features/rooms/data/playlist_parser.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:http/http.dart' as http;

class RoomMusicSyncPage extends ConsumerStatefulWidget {
  const RoomMusicSyncPage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  ConsumerState<RoomMusicSyncPage> createState() => _RoomMusicSyncPageState();
}

class _RoomMusicSyncPageState extends ConsumerState<RoomMusicSyncPage> {
  final _urlController = TextEditingController();
  YoutubePlayerController? _youtubeController;
  ap.AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  String _sourceType = 'youtube'; // 'youtube', 'url', 'local'
  String? _localFilePath;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _roomSubscription;
  String? _currentSourceUrl;

  List<PlaylistItem> _playlistQueue = [];
  int _playlistIndex = -1;
  bool _isParsingPlaylist = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = ap.AudioPlayer();
    _audioPlayer!.onPlayerStateChanged.listen((state) {
      setState(() {
        _isPlaying = state == ap.PlayerState.playing;
      });
    });
    _audioPlayer!.onPositionChanged.listen((position) {
      setState(() {
        _currentPosition = position;
      });
    });
    _audioPlayer!.onDurationChanged.listen((duration) {
      setState(() {
        _totalDuration = duration;
      });
    });

    _roomSubscription = ref.read(roomRepositoryProvider).watchRoom(widget.roomId).listen((roomData) {
      _onRoomDataUpdated(roomData);
    });
  }

  void _onRoomDataUpdated(Map<String, dynamic> roomData) async {
    final myId = ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
    final hostId = roomData['host_id'] as String?;

    if (myId == null || hostId == null) return;
    final isHost = myId == hostId;

    // Parse playback state
    final playbackJson = roomData['playback_state'];
    if (playbackJson == null) return;

    final state = PlaybackStateSnapshot.fromMap(Map<String, dynamic>.from(playbackJson));

    if (isHost) {
      // Host is the driver, don't sync from DB to avoid feedback loops
      return;
    }

    // Sync guest with host's playback state
    final sourceUrl = state.sourceUrl;
    if (sourceUrl == null || sourceUrl.isEmpty) return;

    // Check if source changed
    final sourceChanged = _currentSourceUrl != sourceUrl;
    if (sourceChanged) {
      _currentSourceUrl = sourceUrl;
      _urlController.text = sourceUrl;

      // Auto-detect source type and load
      if (sourceUrl.contains('youtube.com') || sourceUrl.contains('youtu.be')) {
        _loadYouTubeVideo(sourceUrl);
      } else if (sourceUrl.contains('spotify.com')) {
        try {
          final oembedResponse = await http.get(Uri.parse('https://open.spotify.com/oembed?url=$sourceUrl'));
          if (oembedResponse.statusCode == 200) {
            final data = json.decode(oembedResponse.body);
            final title = data['title'] ?? 'Spotify Track';
            final videoId = await PlaylistParser.searchYouTube(title);
            if (videoId != null) {
              _loadYouTubeVideo('https://www.youtube.com/watch?v=$videoId');
              return;
            }
          }
        } catch (_) {}
        await _loadStreamingUrl(sourceUrl);
      } else {
        await _loadStreamingUrl(sourceUrl);
      }
    }

    // Calculate estimated live position
    final targetPosition = state.estimatedLivePosition;
    final isPlaying = state.isPlaying;

    // Sync play/pause and position
    if (_sourceType == 'youtube' && _youtubeController != null) {
      // For YouTube
      if (isPlaying && !_youtubeController!.value.isPlaying) {
        _youtubeController!.play();
      } else if (!isPlaying && _youtubeController!.value.isPlaying) {
        _youtubeController!.pause();
      }

      // Check position difference
      final currentPos = _youtubeController!.value.position;
      final diff = (currentPos - targetPosition).inMilliseconds.abs();
      if (diff > 3000) { // Seek if out of sync by > 3 seconds
        _youtubeController!.seekTo(targetPosition);
      }
    } else if (_audioPlayer != null) {
      // For AudioPlayer
      if (isPlaying && !_isPlaying) {
        await _audioPlayer!.resume();
      } else if (!isPlaying && _isPlaying) {
        await _audioPlayer!.pause();
      }

      // Check position difference
      final diff = (_currentPosition - targetPosition).inMilliseconds.abs();
      if (diff > 3000) { // Seek if out of sync by > 3 seconds
        await _audioPlayer!.seek(targetPosition);
      }
    }
  }

  Future<void> _loadPlaylistItem(PlaylistItem item) async {
    _currentSourceUrl = item.url;
    _urlController.text = item.url;

    if (item.source == 'youtube') {
      _loadYouTubeVideo(item.url);
      await _syncPlayback();
    } else if (item.source == 'spotify') {
      setState(() => _isParsingPlaylist = true);
      final videoId = await PlaylistParser.searchYouTube(item.title);
      setState(() => _isParsingPlaylist = false);
      if (videoId != null) {
        _loadYouTubeVideo('https://www.youtube.com/watch?v=$videoId');
        await _syncPlayback();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not find matching video on YouTube. Playing generic preview.')),
          );
        }
        await _loadStreamingUrl(item.url);
        await _syncPlayback();
      }
    } else {
      await _loadStreamingUrl(item.url);
      await _syncPlayback();
    }
  }

  Future<void> _loadPlaylistOrVideo(String url) async {
    setState(() => _isParsingPlaylist = true);
    try {
      final items = await PlaylistParser.parse(url);
      if (items.isNotEmpty) {
        setState(() {
          _playlistQueue = items;
          _playlistIndex = 0;
        });
        await _loadPlaylistItem(items[0]);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No tracks or videos found in URL.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading URL: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isParsingPlaylist = false);
      }
    }
  }

  Future<void> _nextPlaylistItem() async {
    if (_playlistIndex < _playlistQueue.length - 1) {
      setState(() {
        _playlistIndex++;
      });
      await _loadPlaylistItem(_playlistQueue[_playlistIndex]);
    }
  }

  Future<void> _prevPlaylistItem() async {
    if (_playlistIndex > 0) {
      setState(() {
        _playlistIndex--;
      });
      await _loadPlaylistItem(_playlistQueue[_playlistIndex]);
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _urlController.dispose();
    _youtubeController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  void _loadYouTubeVideo(String url) {
    final videoId = YoutubePlayer.convertUrlToId(url);
    if (videoId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid YouTube URL')));
      return;
    }

    _youtubeController?.dispose();
    _audioPlayer?.stop();

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(autoPlay: false, mute: false),
    );

    setState(() {
      _sourceType = 'youtube';
    });
  }

  Future<void> _loadStreamingUrl(String url) async {
    try {
      _youtubeController?.dispose();
      _youtubeController = null;

      await _audioPlayer!.setSourceUrl(url);
      setState(() {
        _sourceType = 'url';
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Streaming URL loaded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading URL: $e')));
      }
    }
  }

  Future<void> _loadLocalFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);

      if (result == null) return;

      final file = result.files.first;
      final filePath = file.path;
      if (filePath == null) return;

      // Show loading/upload indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 16),
                Text('Uploading music file to party room...'),
              ],
            ),
            duration: Duration(days: 1), // Keep open until finished
          ),
        );
      }

      // Upload file to Supabase Storage
      final mediaRepo = ref.read(mediaRepositoryProvider);
      final uploadResult = await mediaRepo.uploadMedia(
        file: File(filePath),
        fileType: 'audio',
      );

      final publicUrl = uploadResult['url'];
      if (publicUrl == null || publicUrl.isEmpty) {
        throw Exception('Failed to get public URL for uploaded file.');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
      }

      // Load the public url (so it streams instead of playing local path)
      _urlController.text = publicUrl;
      await _loadStreamingUrl(publicUrl);

      // Auto sync playback so other devices receive the new URL immediately
      await _syncPlayback();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Loaded & Shared: ${file.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading file: $e')));
      }
    }
  }

  Future<void> _playPause() async {
    if (_sourceType == 'youtube') {
      if (_youtubeController!.value.isPlaying) {
        _youtubeController!.pause();
      } else {
        _youtubeController!.play();
      }
      setState(() {});
    } else {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
    }
  }

  Future<void> _stop() async {
    if (_sourceType == 'youtube') {
      _youtubeController?.seekTo(Duration.zero);
      _youtubeController?.pause();
    } else {
      await _audioPlayer!.stop();
    }
    setState(() {});
  }

  Future<void> _syncPlayback() async {
    try {
      var position = Duration.zero;
      bool isPlaying = false;

      if (_sourceType == 'youtube' && _youtubeController != null) {
        position = _youtubeController!.value.position;
        isPlaying = _youtubeController!.value.isPlaying;
      } else {
        position = _currentPosition;
        isPlaying = _isPlaying;
      }

      final state = PlaybackStateSnapshot(
        position: position,
        isPlaying: isPlaying,
        sourceUrl: _sourceType == 'local'
            ? _localFilePath ?? ''
            : _urlController.text,
        hostId:
            ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id ??
            '',
        updatedAt: DateTime.now(),
      );

      await ref
          .read(roomRepositoryProvider)
          .updatePlayback(roomId: widget.roomId, state: state);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Playback synced!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing: $e')));
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName),
            const Text(
              'Music Sync',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Source Selection
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Music Source',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.play_circle_outline_rounded,
                        label: 'YouTube',
                        isSelected: _sourceType == 'youtube',
                        onTap: () => setState(() => _sourceType = 'youtube'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.link_rounded,
                        label: 'URL',
                        isSelected: _sourceType == 'url',
                        onTap: () => setState(() => _sourceType = 'url'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.folder_rounded,
                        label: 'Local',
                        isSelected: _sourceType == 'local',
                        onTap: _loadLocalFile,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // URL Input (for YouTube, Spotify and Streaming)
          if (_sourceType != 'local') ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sourceType == 'youtube' ? 'YouTube/Spotify URL or Playlist' : 'Streaming URL',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: _sourceType == 'youtube'
                          ? 'YouTube or Spotify video, song, playlist link...'
                          : 'https://example.com/audio.mp3',
                      prefixIcon: const Icon(Icons.link_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isParsingPlaylist) ...[
                    const LinearProgressIndicator(),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isParsingPlaylist
                          ? null
                          : () {
                              final url = _urlController.text.trim();
                              if (url.isNotEmpty) {
                                if (_sourceType == 'youtube') {
                                  _loadPlaylistOrVideo(url);
                                } else {
                                  _loadStreamingUrl(url);
                                }
                              }
                            },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(_isParsingPlaylist ? 'Parsing Playlist...' : 'Load'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // YouTube Player
          if (_sourceType == 'youtube' && _youtubeController != null) ...[
            GlassCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: YoutubePlayer(
                  controller: _youtubeController!,
                  showVideoProgressIndicator: true,
                  onReady: () => setState(() {}),
                  onEnded: (data) => setState(() {}),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Audio Player Controls (for URL and Local)
          if (_sourceType != 'youtube' &&
              (_sourceType == 'url' || _localFilePath != null)) ...[
            GlassCard(
              child: Column(
                children: [
                  // Progress Bar
                  Row(
                    children: [
                      Text(
                        _formatDuration(_currentPosition),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentPosition.inMilliseconds.toDouble(),
                          max: _totalDuration.inMilliseconds.toDouble(),
                          onChanged: (value) async {
                            await _audioPlayer!.seek(
                              Duration(milliseconds: value.toInt()),
                            );
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Playback Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton.filled(
                        onPressed: _playPause,
                        icon: Icon(
                          _isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                        ),
                        iconSize: 32,
                      ),
                      IconButton.filled(
                        onPressed: _stop,
                        icon: const Icon(Icons.stop_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Sync Button
          if (_youtubeController != null ||
              _localFilePath != null ||
              _sourceType == 'url') ...[
            GlassCard(
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _syncPlayback,
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Sync with Room'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share your current playback with room members',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Playlist Queue Card
          if (_playlistQueue.isNotEmpty) ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Queue (${_playlistIndex + 1}/${_playlistQueue.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.skip_previous_rounded),
                            onPressed: _playlistIndex > 0 ? _prevPlaylistItem : null,
                          ),
                          IconButton(
                            icon: const Icon(Icons.skip_next_rounded),
                            onPressed: _playlistIndex < _playlistQueue.length - 1
                                ? _nextPlaylistItem
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  SizedBox(
                    height: 160,
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _playlistQueue.length,
                      itemBuilder: (context, index) {
                        final item = _playlistQueue[index];
                        final isCurrent = index == _playlistIndex;
                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                              image: item.thumbnailUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(item.thumbnailUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: item.thumbnailUrl == null
                                ? Icon(
                                    item.source == 'spotify'
                                        ? Icons.music_note_rounded
                                        : Icons.video_library_rounded,
                                    size: 20,
                                    color: isCurrent
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white60,
                                  )
                                : null,
                          ),
                          title: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                              color: isCurrent
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            item.source.toUpperCase(),
                            style: const TextStyle(fontSize: 10, color: Colors.white54),
                          ),
                          trailing: isCurrent
                              ? Icon(
                                  Icons.volume_up_rounded,
                                  color: Theme.of(context).colorScheme.primary,
                                )
                              : null,
                          onTap: () {
                            setState(() {
                              _playlistIndex = index;
                            });
                            _loadPlaylistItem(item);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Instructions
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Supported Sources',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _InstructionStep(
                  number: '1',
                  text: 'YouTube - Music videos and songs',
                ),
                _InstructionStep(
                  number: '2',
                  text: 'Streaming URL - Direct MP3/audio links',
                ),
                _InstructionStep(
                  number: '3',
                  text: 'Local Files - Audio files from your device',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.white.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
