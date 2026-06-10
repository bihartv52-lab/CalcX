import 'dart:async';
import 'dart:math';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:calcx/features/rooms/domain/playback_state.dart';
import 'package:calcx/features/rooms/data/playlist_parser.dart';
import 'package:calcx/features/calls/data/livekit_call_service.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/rooms/presentation/widgets/room_chat_sidebar.dart';
import 'package:calcx/core/widgets/incoming_call_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class RoomWatchPartyPage extends ConsumerStatefulWidget {
  const RoomWatchPartyPage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  ConsumerState<RoomWatchPartyPage> createState() => _RoomWatchPartyPageState();
}

class _RoomWatchPartyPageState extends ConsumerState<RoomWatchPartyPage> {
  final _urlController = TextEditingController();
  final GlobalKey _betterPlayerKey = GlobalKey();
  YoutubePlayerController? _youtubeController;
  BetterPlayerController? _betterPlayerController;
  InAppWebViewController? _webViewController;
  String _sourceType = 'youtube'; // 'youtube', 'url', 'local'
  String? _localFilePath;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _messageSubscription;
  String? _currentSourceUrl;
  double _playbackSpeed = 1.0;
  Timer? _syncTimer;
  Map<String, dynamic>? _lastRoomData;
  final List<FloatingEmoji> _floatingEmojis = [];

  // Playlist variables
  List<PlaylistItem> _playlistQueue = [];
  int _playlistIndex = -1;
  bool _isParsingPlaylist = false;

  // Fullscreen and Side Panel variables
  bool _isFullscreen = false;
  String _sidePanelType = 'none'; // 'none', 'chat', 'vc', 'call', 'moderation'
  double _sidePanelWidthFraction = 0.25; // default 25% of screen width
  bool _showWidthControls = true;



  // Chat Toast variables
  String? _toastMessage;
  String? _toastSender;
  Timer? _toastTimer;
  final Map<String, String> _profileNames = {};

  // Chat variables
  final _chatController = TextEditingController();
  final _chatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _roomSubscription = ref.read(roomRepositoryProvider).watchRoom(widget.roomId).listen((roomData) {
      _lastRoomData = roomData;
      _onRoomDataUpdated(roomData);
    });

    // Listen for room reactions, kicks, and mutes
    final myId = ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
    _messageSubscription = ref.read(chatRepositoryProvider).watchRoomMessages(widget.roomId).listen((messages) {
      if (messages.isEmpty) return;
      final lastMsg = messages.last;
      
      // Emojis sent in the last 4 seconds
      if (lastMsg.messageType == 'room_reaction' && 
          DateTime.now().difference(lastMsg.createdAt).inSeconds < 4) {
        _triggerFloatingEmoji(lastMsg.content);
      }
      
      if (lastMsg.messageType == 'kick' && lastMsg.content == myId) {
        _onKickedByHost();
      }

      if (lastMsg.messageType == 'mute' && lastMsg.content == myId) {
        final room = ref.read(liveKitCallServiceProvider).room;
        final localParticipant = room?.localParticipant;
        if (localParticipant != null && localParticipant.isMicrophoneEnabled()) {
          localParticipant.setMicrophoneEnabled(false);
        }
      }

      // Brief floating chat bubble toast if sidebar is closed
      if (lastMsg.senderId != myId && 
          _sidePanelType != 'chat' && 
          lastMsg.messageType == 'text' && 
          DateTime.now().difference(lastMsg.createdAt).inSeconds < 4) {
        _getParticipantName(lastMsg.senderId).then((senderName) {
          if (mounted) {
            setState(() {
              _toastMessage = lastMsg.content;
              _toastSender = senderName;
            });
            _toastTimer?.cancel();
            _toastTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  _toastMessage = null;
                  _toastSender = null;
                });
              }
            });
          }
        });
      }
    });

    // Auto re-sync timer every 3 seconds for guests, and auto-sync for hosts when playing
    _syncTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_lastRoomData != null && myId != null) {
        final hostId = _lastRoomData!['host_id'] as String?;
        if (myId != hostId) {
          _onRoomDataUpdated(_lastRoomData!); // trigger guest re-sync check
        } else {
          // Host auto-syncs position to database periodically when playing
          bool isPlaying = false;
          if (_sourceType == 'youtube' && _youtubeController != null) {
            isPlaying = _youtubeController!.value.isPlaying;
          } else if (_sourceType == 'browser') {
            isPlaying = true;
          } else if (_betterPlayerController != null) {
            isPlaying = _betterPlayerController!.isPlaying() ?? false;
          }
          if (isPlaying) {
            _syncPlayback(showSnackBar: false);
          }
        }
      }
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

      // Respect dbSourceType or Auto-detect source type and load
      final dbSourceType = state.sourceType;
      if (dbSourceType != null && dbSourceType != _sourceType) {
        setState(() {
          _sourceType = dbSourceType;
        });
      }

      final targetSourceType = dbSourceType ?? (
        (sourceUrl.contains('youtube.com') || sourceUrl.contains('youtu.be'))
            ? 'youtube'
            : (sourceUrl.contains('spotify.com') ? 'youtube' : 'url')
      );

      if (targetSourceType == 'youtube') {
        _loadYouTubeVideo(sourceUrl);
      } else if (targetSourceType == 'browser') {
        _loadBrowserUrl(sourceUrl);
      } else {
        await _loadDirectUrl(sourceUrl);
      }
    }

    // Calculate estimated live position
    final targetPosition = state.estimatedLivePosition;
    final isPlaying = state.isPlaying;
    final targetSpeed = state.playbackSpeed;

    // Sync playback speed
    if (_playbackSpeed != targetSpeed) {
      _playbackSpeed = targetSpeed;
      if (_sourceType == 'youtube' && _youtubeController != null) {
        _youtubeController!.setPlaybackRate(targetSpeed);
      } else if (_betterPlayerController != null) {
        _betterPlayerController!.setSpeed(targetSpeed);
      }
    }

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
      if (diff > 1500) { // Seek if out of sync by > 1.5 seconds
        _youtubeController!.seekTo(targetPosition);
      }
    } else if (_betterPlayerController != null) {
      // For Better Player
      final playerIsPlaying = _betterPlayerController!.isPlaying() ?? false;
      if (isPlaying && !playerIsPlaying) {
        await _betterPlayerController!.play();
      } else if (!isPlaying && playerIsPlaying) {
        await _betterPlayerController!.pause();
      }

      // Check position difference
      final currentPos = await _betterPlayerController!.videoPlayerController?.position ?? Duration.zero;
      final diff = (currentPos - targetPosition).inMilliseconds.abs();
      if (diff > 1500) { // Seek if out of sync by > 1.5 seconds
        await _betterPlayerController!.seekTo(targetPosition);
      }
    }
  }

  @override
  void dispose() {
    _roomSubscription?.cancel();
    _messageSubscription?.cancel();
    _syncTimer?.cancel();
    _urlController.dispose();
    _chatController.dispose();
    _chatScrollController.dispose();
    _youtubeController?.dispose();
    _betterPlayerController?.dispose();

    _toastTimer?.cancel();
    ref.read(liveKitCallServiceProvider).leaveRoom();

    // Reset orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    super.dispose();
  }

  Future<String> _getParticipantName(String userId) async {
    if (_profileNames.containsKey(userId)) {
      return _profileNames[userId]!;
    }
    try {
      final repo = ref.read(friendsRepositoryProvider);
      final profile = await repo.getUserById(userId);
      if (profile != null) {
        final name = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
        setState(() {
          _profileNames[userId] = name;
        });
        return name;
      }
    } catch (_) {}
    return userId.substring(0, 8);
  }

  void _triggerFloatingEmoji(String emoji) {
    if (!mounted) return;
    final random = Random();
    final startX = random.nextDouble() * (MediaQuery.of(context).size.width * 0.5) + (MediaQuery.of(context).size.width * 0.1);
    final key = UniqueKey();
    
    setState(() {
      _floatingEmojis.add(
        FloatingEmoji(
          emoji: emoji,
          startX: startX,
          delay: 0.0,
          key: key,
        ),
      );
    });
  }

  void _onKickedByHost() {
    ref.read(liveKitCallServiceProvider).leaveRoom();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ You have been kicked from the watch party by the host.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendRoomReaction(String emoji) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;
      await client.from('messages').insert({
        'sender_id': client.auth.currentUser!.id,
        'room_id': widget.roomId,
        'content': emoji,
        'message_type': 'room_reaction',
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error sending room reaction: $e');
    }
  }

  Future<void> _kickUser(String targetUserId) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;
      
      // Remove from room_participants database
      await client
          .from('room_participants')
          .delete()
          .eq('room_id', widget.roomId)
          .eq('user_id', targetUserId);

      // Send kick signal message
      await client.from('messages').insert({
        'sender_id': client.auth.currentUser!.id,
        'room_id': widget.roomId,
        'content': targetUserId,
        'message_type': 'kick',
        'created_at': DateTime.now().toIso8601String(),
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User kicked successfully.')),
        );
      }
    } catch (e) {
      debugPrint('Error kicking user: $e');
    }
  }

  Future<void> _sendMuteSignal(String targetUserId) async {
    try {
      final client = SupabaseService.clientOrNull;
      if (client == null) return;
      await client.from('messages').insert({
        'sender_id': client.auth.currentUser!.id,
        'room_id': widget.roomId,
        'content': targetUserId,
        'message_type': 'mute',
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sent mute request to user.')),
        );
      }
    } catch (e) {
      debugPrint('Error sending mute request: $e');
    }
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
    _betterPlayerController?.dispose();
    _betterPlayerController = null;

    _youtubeController = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
      ),
    );

    setState(() {
      _sourceType = 'youtube';
    });
  }

  Future<void> _loadBrowserUrl(String url) async {
    try {
      _youtubeController?.dispose();
      _youtubeController = null;
      _betterPlayerController?.dispose();
      _betterPlayerController = null;

      setState(() {
        _sourceType = 'browser';
        _currentSourceUrl = url;
      });

      if (_webViewController != null) {
        await _webViewController!.loadUrl(urlRequest: URLRequest(url: WebUri(url)));
      }

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Browser URL loaded!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading web page: $e')));
      }
    }
  }

  Future<void> _loadDirectUrl(String url) async {
    try {
      _youtubeController?.dispose();
      _youtubeController = null;
      _betterPlayerController?.dispose();

      _betterPlayerController = BetterPlayerController(
        const BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          fit: BoxFit.contain,
          autoPlay: false,
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.network,
          url,
        ),
      );

      setState(() {
        _sourceType = 'url';
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Video URL loaded!')));
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
      final result = await FilePicker.platform.pickFiles(type: FileType.video);

      if (result == null) return;

      final file = result.files.first;
      _localFilePath = file.path;

      _youtubeController?.dispose();
      _youtubeController = null;
      _betterPlayerController?.dispose();

      _betterPlayerController = BetterPlayerController(
        const BetterPlayerConfiguration(
          aspectRatio: 16 / 9,
          fit: BoxFit.contain,
          autoPlay: false,
        ),
        betterPlayerDataSource: BetterPlayerDataSource(
          BetterPlayerDataSourceType.file,
          _localFilePath!,
        ),
      );

      setState(() {
        _sourceType = 'local';
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Loaded: ${file.name}')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading file: $e')));
      }
    }
  }

  Future<void> _syncPlayback({bool showSnackBar = true}) async {
    try {
      var position = Duration.zero;
      bool isPlaying = false;

      if (_sourceType == 'youtube' && _youtubeController != null) {
        position = _youtubeController!.value.position;
        isPlaying = _youtubeController!.value.isPlaying;
      } else if (_sourceType == 'browser') {
        position = Duration.zero;
        isPlaying = true;
      } else if (_betterPlayerController != null) {
        position =
            await _betterPlayerController!.videoPlayerController?.position ??
            Duration.zero;
        isPlaying = _betterPlayerController!.isPlaying() ?? false;
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
        playbackSpeed: _playbackSpeed,
        sourceType: _sourceType,
      );

      await ref
          .read(roomRepositoryProvider)
          .updatePlayback(roomId: widget.roomId, state: state);

      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Video synced with room!')),
        );
      }
    } catch (e) {
      if (mounted && showSnackBar) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error syncing: $e')));
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
        await _loadDirectUrl(item.url);
        await _syncPlayback();
      }
    } else {
      await _loadDirectUrl(item.url);
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

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }



  Widget _buildVideoPlayerArea() {
    final myId = ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
    final hostId = _lastRoomData?['host_id'] as String?;
    final isHost = myId != null && hostId != null && myId == hostId;

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: ClipRect(
        child: Stack(
          children: [
            // The Player
            Positioned.fill(
              child: _sourceType == 'youtube' && _youtubeController != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
                      child: YoutubePlayer(
                        controller: _youtubeController!,
                        showVideoProgressIndicator: true,
                        progressIndicatorColor: Theme.of(context).colorScheme.primary,
                        onReady: () => setState(() {}),
                        onEnded: (data) => setState(() {}),
                      ),
                    )
                  : _sourceType == 'browser'
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
                          child: InAppWebView(
                            initialUrlRequest: URLRequest(url: WebUri(_currentSourceUrl ?? 'https://google.com')),
                            initialSettings: InAppWebViewSettings(
                              javaScriptEnabled: true,
                              domStorageEnabled: true,
                              databaseEnabled: true,
                              allowsInlineMediaPlayback: true,
                              useHybridComposition: true,
                              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                              useShouldOverrideUrlLoading: true,
                              mediaPlaybackRequiresUserGesture: false,
                            ),
                            onWebViewCreated: (controller) {
                              _webViewController = controller;
                            },
                            onLoadStop: (controller, url) async {
                              if (isHost && url != null) {
                                final urlStr = url.toString();
                                if (urlStr != _currentSourceUrl) {
                                  _currentSourceUrl = urlStr;
                                  _urlController.text = urlStr;
                                  _syncPlayback(showSnackBar: false);
                                }
                              }
                            },
                          ),
                        )
                      : _betterPlayerController != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(_isFullscreen ? 0 : 16),
                              child: BetterPlayer(
                                key: _betterPlayerKey,
                                controller: _betterPlayerController!,
                              ),
                            )
                          : Container(
                              color: Colors.black,
                              child: const Center(
                                child: Text('No video loaded', style: TextStyle(color: Colors.white60)),
                              ),
                            ),
            ),

            // Floating Chat Bubble Toast Overlay
            if (_toastMessage != null && _toastSender != null)
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Material(
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 16),
                          const SizedBox(width: 8),
                          Flexible(
                            child: RichText(
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: '$_toastSender: ',
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: _toastMessage,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // Emojis floating overlay
            ..._floatingEmojis.map((e) => _AnimatedEmoji(
                  key: e.key,
                  emoji: e.emoji,
                  startX: e.startX,
                  onComplete: () {
                    setState(() {
                      _floatingEmojis.remove(e);
                    });
                  },
                )),

            // Custom control overlays
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(_isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded, color: Colors.white),
                      onPressed: _toggleFullscreen,
                    ),
                    if (_sourceType != 'youtube')
                      IconButton(
                        icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                        tooltip: 'Picture-in-Picture',
                        onPressed: () {
                          if (_betterPlayerController != null) {
                            _betterPlayerController!.enablePictureInPicture(_betterPlayerKey);
                          }
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Settings/Sidepanel selector button (top right)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(
                        _sidePanelType == 'chat'
                            ? Icons.chat_bubble_rounded
                            : _sidePanelType == 'vc'
                                ? Icons.videocam_rounded
                                : _sidePanelType == 'call'
                                    ? Icons.call_rounded
                                    : _sidePanelType == 'moderation'
                                        ? Icons.people_rounded
                                        : Icons.view_sidebar_rounded,
                        color: _sidePanelType == 'none' ? Colors.white : Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        // Show pop-up menu to select side-panel layout
                        showMenu(
                          context: context,
                          position: RelativeRect.fromLTRB(MediaQuery.of(context).size.width, 56, 0, 0),
                          items: [
                            const PopupMenuItem(value: 'none', child: Text('No Side Panel')),
                            const PopupMenuItem(value: 'chat', child: Text('Chat Sidebar')),
                            const PopupMenuItem(value: 'vc', child: Text('Video Call Sidebar')),
                            const PopupMenuItem(value: 'call', child: Text('Voice Call Sidebar')),
                            const PopupMenuItem(value: 'moderation', child: Text('Participants & Moderation')),
                          ],
                        ).then((value) {
                          if (value != null) {
                            setState(() {
                              _sidePanelType = value;
                            });
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Floating Emoji Reactions row (above bottom controls)
            Positioned(
              bottom: 48,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: ['💖', '😂', '😮', '😢', '🎉'].map((emoji) {
                    return InkWell(
                      onTap: () => _sendRoomReaction(emoji),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            // Small bottom overlays for play/pause/sync
            if (_sourceType != 'local')
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Row(
                        children: [
                          if (_playlistQueue.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 18),
                              onPressed: _playlistIndex > 0 ? _prevPlaylistItem : null,
                            ),
                          ],
                          IconButton(
                            icon: Icon(
                              _sourceType == 'youtube' && _youtubeController != null
                                  ? (_youtubeController!.value.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded)
                                  : (_betterPlayerController?.isPlaying() == true ? Icons.pause_rounded : Icons.play_arrow_rounded),
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              if (_sourceType == 'youtube' && _youtubeController != null) {
                                if (_youtubeController!.value.isPlaying) {
                                  _youtubeController!.pause();
                                } else {
                                  _youtubeController!.play();
                                }
                              } else if (_betterPlayerController != null) {
                                if (_betterPlayerController!.isPlaying() == true) {
                                  _betterPlayerController!.pause();
                                } else {
                                  _betterPlayerController!.play();
                                }
                              }
                              setState(() {});
                              if (isHost) {
                                _syncPlayback(showSnackBar: false);
                              }
                            },
                          ),
                          if (_playlistQueue.isNotEmpty) ...[
                            IconButton(
                              icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 18),
                              onPressed: _playlistIndex < _playlistQueue.length - 1 ? _nextPlaylistItem : null,
                            ),
                          ],
                          // Playback Speed Selector (Menu)
                          PopupMenuButton<double>(
                            icon: const Icon(Icons.speed_rounded, color: Colors.white, size: 18),
                            tooltip: 'Playback Speed',
                            onSelected: (double speed) {
                              setState(() {
                                _playbackSpeed = speed;
                              });
                              if (_sourceType == 'youtube' && _youtubeController != null) {
                                _youtubeController!.setPlaybackRate(speed);
                              } else if (_betterPlayerController != null) {
                                _betterPlayerController!.setSpeed(speed);
                              }
                              if (isHost) {
                                _syncPlayback(showSnackBar: false);
                              }
                            },
                            itemBuilder: (BuildContext context) => <PopupMenuEntry<double>>[
                              const PopupMenuItem<double>(value: 1.0, child: Text('1.0x')),
                              const PopupMenuItem<double>(value: 1.25, child: Text('1.25x')),
                              const PopupMenuItem<double>(value: 1.5, child: Text('1.5x')),
                              const PopupMenuItem<double>(value: 2.0, child: Text('2.0x')),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.tune_rounded,
                              color: _showWidthControls ? Theme.of(context).colorScheme.primary : Colors.white60,
                              size: 18,
                            ),
                            tooltip: 'Toggle Width Controls',
                            onPressed: () {
                              setState(() {
                                _showWidthControls = !_showWidthControls;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                      child: TextButton.icon(
                        onPressed: _syncPlayback,
                        icon: const Icon(Icons.sync_rounded, color: Colors.white, size: 14),
                        label: const Text('Sync', style: TextStyle(color: Colors.white, fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMediaMuted = ref.watch(watchPartyMutedProvider);
    final mediaVolume = ref.watch(watchPartyVolumeProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final vol = isMediaMuted ? 0.0 : mediaVolume;
      if (_betterPlayerController != null) {
        _betterPlayerController!.setVolume(vol);
      }
      if (_youtubeController != null) {
        if (isMediaMuted || vol == 0.0) {
          _youtubeController!.mute();
        } else {
          _youtubeController!.unMute();
          _youtubeController!.setVolume((vol * 100).toInt());
        }
      }
    });

    final myId = ref.read(roomRepositoryProvider).supabase?.auth.currentUser?.id;
    final hostId = _lastRoomData?['host_id'] as String?;
    final isHost = myId != null && hostId != null && myId == hostId;

    if (_isFullscreen) {
      final screenWidth = MediaQuery.of(context).size.width;
      final showSidebar = _sidePanelType != 'none';
      final sidebarWidth = screenWidth * _sidePanelWidthFraction;

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) {
            _toggleFullscreen();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Row(
            children: [
              // Left video area
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: Center(child: _buildVideoPlayerArea())),
                    // Width slider control visible only when side panel is open
                    if (showSidebar && _showWidthControls)
                      Container(
                        color: Colors.black87,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        child: Row(
                          children: [
                            const Text('Panel Width: ', style: TextStyle(fontSize: 10, color: Colors.white60)),
                            Expanded(
                              child: Slider(
                                value: _sidePanelWidthFraction,
                                min: 0.10,
                                max: 0.30,
                                divisions: 4,
                                label: '${(_sidePanelWidthFraction * 100).toInt()}%',
                                onChanged: (val) {
                                  setState(() {
                                    _sidePanelWidthFraction = val;
                                  });
                                },
                              ),
                            ),
                            Text('${(_sidePanelWidthFraction * 100).toInt()}%', style: const TextStyle(fontSize: 10, color: Colors.white)),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _showWidthControls = false;
                                });
                              },
                              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white60),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              // Right sidebar
              if (showSidebar)
                Container(
                  width: sidebarWidth,
                  color: const Color(0xFF131313),
                  child: RoomSideChatPanel(
                    roomId: widget.roomId,
                    roomName: widget.roomName,
                    roomType: 'party',
                    sidePanelType: _sidePanelType,
                    onPanelTypeChanged: (newType) {
                      setState(() {
                        _sidePanelType = newType;
                      });
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.roomName),
            const Text(
              'Watch Party',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Selected Source Buttons
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Video Source',
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
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.link_rounded,
                        label: 'Direct URL',
                        isSelected: _sourceType == 'url',
                        onTap: () => setState(() => _sourceType = 'url'),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SourceButton(
                        icon: Icons.language_rounded,
                        label: 'Browser',
                        isSelected: _sourceType == 'browser',
                        onTap: () => setState(() => _sourceType = 'browser'),
                      ),
                    ),
                    const SizedBox(width: 6),
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

          // URL Input
          if (_sourceType != 'local') ...[
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _sourceType == 'youtube' 
                        ? 'YouTube/Spotify URL or Playlist' 
                        : (_sourceType == 'browser' ? 'Website URL (Browser)' : 'Direct Video URL'),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      hintText: _sourceType == 'youtube'
                          ? 'YouTube or Spotify video, song, playlist link...'
                          : (_sourceType == 'browser' ? 'https://google.com' : 'https://example.com/video.mp4'),
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
                                } else if (_sourceType == 'browser') {
                                  _loadBrowserUrl(url);
                                  if (isHost) {
                                    _syncPlayback(showSnackBar: false);
                                  }
                                } else {
                                  _loadDirectUrl(url);
                                }
                              }
                            },
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(_isParsingPlaylist 
                          ? 'Parsing Playlist...' 
                          : (_sourceType == 'browser' ? 'Open Website' : 'Load Video')),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Video Player Box
          _buildVideoPlayerArea(),
          const SizedBox(height: 16),

          // Playlist Queue
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

          // Sync Buttons (Portrait View)
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
                      'Supported Video Sources',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const _InstructionStep(
                  icon: Icons.play_circle_outline_rounded,
                  text: 'YouTube / Spotify - Songs, videos & playlists links',
                ),
                const _InstructionStep(
                  icon: Icons.link_rounded,
                  text: 'Direct URL - MP4, WebM, M3U8 streams',
                ),
                const _InstructionStep(
                  icon: Icons.folder_rounded,
                  text: 'Local Files - Videos from your device',
                ),
                const _InstructionStep(
                  icon: Icons.sync_rounded,
                  text: 'Sync to watch together in real-time',
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
  const _InstructionStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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

class FloatingEmoji {
  final String emoji;
  final double startX;
  final double delay;
  final Key key;

  FloatingEmoji({required this.emoji, required this.startX, required this.delay, required this.key});
}

class _AnimatedEmoji extends StatefulWidget {
  final String emoji;
  final double startX;
  final VoidCallback onComplete;

  const _AnimatedEmoji({required this.emoji, required this.startX, required this.onComplete, super.key});

  @override
  State<_AnimatedEmoji> createState() => _AnimatedEmojiState();
}

class _AnimatedEmojiState extends State<_AnimatedEmoji> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _yAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _yAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _fadeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_controller);

    _controller.forward().then((_) => widget.onComplete());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Positioned(
          left: widget.startX,
          bottom: (screenHeight * 0.3) * (1.0 - _yAnim.value) + 20,
          child: Opacity(
            opacity: _fadeAnim.value,
            child: Text(
              widget.emoji,
              style: const TextStyle(fontSize: 32),
            ),
          ),
        );
      },
    );
  }
}

