import 'dart:async';
import 'package:calcx/app/app_router.dart';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:calcx/features/calls/presentation/incoming_call_page.dart';
import 'package:calcx/features/friends/presentation/friends_page.dart';
import 'package:calcx/features/chat/presentation/chat_list_page.dart';
import 'package:calcx/features/rooms/presentation/room_game_zone_page.dart';
import 'package:calcx/features/rooms/presentation/room_watch_party_page.dart';
import 'package:calcx/features/rooms/data/room_repository.dart';
import 'package:calcx/core/constants/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';

final notificationsStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final client = SupabaseService.clientOrNull;
  if (client == null) return const Stream.empty();
  final myId = client.auth.currentUser?.id;
  if (myId == null) return const Stream.empty();

  return client
      .from('notifications')
      .stream(primaryKey: ['id'])
      .eq('user_id', myId)
      .order('created_at', ascending: false)
      .limit(1);
});

class WatchPartyMutedNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle() {
    state = !state;
  }
}

final watchPartyMutedProvider = NotifierProvider<WatchPartyMutedNotifier, bool>(
  WatchPartyMutedNotifier.new,
);

class WatchPartyVolumeNotifier extends Notifier<double> {
  @override
  double build() => 1.0;

  void setVolume(double val) {
    state = val.clamp(0.0, 1.0);
  }
}

final watchPartyVolumeProvider = NotifierProvider<WatchPartyVolumeNotifier, double>(
  WatchPartyVolumeNotifier.new,
);

class IncomingCallListener extends ConsumerStatefulWidget {
  const IncomingCallListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<IncomingCallListener> createState() => _IncomingCallListenerState();
}

class _IncomingCallListenerState extends ConsumerState<IncomingCallListener> {
  String? _displayedCallId;
  bool _isPageShowing = false;
  Route? _activeRoute;

  // New states for overlay banners
  String? _lastNotificationId;
  bool _isFirstNotificationEmission = true;
  Map<String, dynamic>? _activeNotification;
  Timer? _notificationDismissTimer;
  bool _showNotificationBanner = false;

  Map<String, dynamic>? _callerProfile;
  Map<String, dynamic>? _receiverProfile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(appRouterProvider).routerDelegate.addListener(_onRouteChanged);
    });
  }

  @override
  void dispose() {
    try {
      ref.read(appRouterProvider).routerDelegate.removeListener(_onRouteChanged);
    } catch (_) {}
    _notificationDismissTimer?.cancel();
    super.dispose();
  }

  void _onRouteChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _fetchProfilesIfNeeded(Call call) async {
    final supabase = ref.read(callRepositoryProvider).supabase;
    if (supabase == null) return;
    try {
      if (_callerProfile == null || _callerProfile!['id'] != call.callerId) {
        final caller = await supabase.from('profiles').select().eq('id', call.callerId).single();
        if (mounted) {
          setState(() => _callerProfile = caller);
        }
      }
      if (_receiverProfile == null || _receiverProfile!['id'] != call.receiverId) {
        final receiver = await supabase.from('profiles').select().eq('id', call.receiverId).single();
        if (mounted) {
          setState(() => _receiverProfile = receiver);
        }
      }
    } catch (_) {}
  }



  Widget _buildNotificationBanner(BuildContext context, Map<String, dynamic> notification) {
    final type = notification['type'] as String?;
    final title = notification['title'] as String? ?? 'Notification';
    final body = notification['body'] as String? ?? '';

    IconData icon;
    Color iconColor;
    if (type == 'friend_request' || type == 'friend_request_accepted') {
      icon = Icons.person_add_rounded;
      iconColor = Theme.of(context).colorScheme.primary;
    } else {
      icon = Icons.chat_bubble_rounded;
      iconColor = const Color(0xFFFF007F); // Premium Neon Pink
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _showNotificationBanner = false;
        });

        final rootKey = ref.read(rootNavigatorKeyProvider);
        final rootContext = rootKey.currentContext;
        if (rootContext != null) {
          if (type == 'friend_request' || type == 'friend_request_accepted') {
            Navigator.push(
              rootContext,
              MaterialPageRoute(builder: (_) => const FriendsPage()),
            );
          } else if (type == 'message') {
            final data = notification['data'] as Map<String, dynamic>?;
            final senderId = data?['sender_id'] as String?;
            if (senderId != null) {
              rootContext.push('/chat/$senderId');
            }
          }
        }
      },
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xEE1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: iconColor.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: iconColor.withValues(alpha: 0.15),
                child: Icon(icon, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                onPressed: () {
                  setState(() {
                    _showNotificationBanner = false;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. Check for incoming calls
    final calls = ref.watch(incomingCallsProvider).value ?? [];
    final router = ref.read(appRouterProvider);
    final location = router.routerDelegate.currentConfiguration.uri.toString();
    final isOnCalculatorOrAuth = location == AppRoutes.calculator || location == AppRoutes.auth;

    if (calls.isEmpty) {
      if (_isPageShowing && _activeRoute != null) {
        final rootKey = ref.read(rootNavigatorKeyProvider);
        final rootContext = rootKey.currentContext;
        if (rootContext != null && _activeRoute!.isCurrent) {
          Navigator.of(rootContext).removeRoute(_activeRoute!);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isPageShowing = false;
              _displayedCallId = null;
              _activeRoute = null;
            });
          }
        });
      }
    } else if (!isOnCalculatorOrAuth) {
      final call = calls.first;
      if (call.id != _displayedCallId || !_isPageShowing) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (ref.read(incomingCallsProvider).value?.isEmpty ?? true) return;
          if (_isPageShowing && _displayedCallId == call.id) return;

          setState(() {
            _displayedCallId = call.id;
            _isPageShowing = true;
          });

          final rootKey = ref.read(rootNavigatorKeyProvider);
          final rootContext = rootKey.currentContext;
          if (rootContext != null) {
            final route = MaterialPageRoute(
              builder: (context) => IncomingCallPage(call: call),
              fullscreenDialog: true,
            );
            _activeRoute = route;

            Navigator.push(rootContext, route).then((_) {
              if (mounted) {
                setState(() {
                  _isPageShowing = false;
                  _displayedCallId = null;
                  _activeRoute = null;
                });
              }
            });
          }
        });
      }
    }

    // 2. Listen for in-app notifications
    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(notificationsStreamProvider, (previous, next) {
      if (next is! AsyncData) return;
      final notifications = next.value ?? [];
      
      // Seed first emission to prevent old messages popping at boot
      if (_isFirstNotificationEmission) {
        _isFirstNotificationEmission = false;
        if (notifications.isNotEmpty) {
          _lastNotificationId = notifications.first['id'] as String?;
        }
        return;
      }

      if (notifications.isEmpty) return;

      final latest = notifications.first;
      final id = latest['id'] as String?;
      if (id == null || id == _lastNotificationId) return;

      _lastNotificationId = id;

      final type = latest['type'] as String?;
      if (type == 'call') return; // Handled separately by incomingCallsProvider

      if (type == 'room_invite') {
        final router = ref.read(appRouterProvider);
        final location = router.routerDelegate.currentConfiguration.uri.toString();
        final isOnCalculatorOrAuth = location == AppRoutes.calculator || location == AppRoutes.auth;
        if (isOnCalculatorOrAuth) return; // Suppress invite popup on calculator/auth screens

        final data = latest['data'] as Map<String, dynamic>? ?? {};
        final roomId = data['room_id'] as String?;
        final roomName = data['room_name'] as String? ?? 'A game room';
        final roomType = data['room_type'] as String? ?? 'game';
        final hostUsername = data['host_username'] as String? ?? 'Someone';

        if (roomId != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final rootKey = ref.read(rootNavigatorKeyProvider);
            final rootContext = rootKey.currentContext;
            if (rootContext != null) {
              showDialog(
                context: rootContext,
                barrierDismissible: false,
                builder: (ctx) => AlertDialog(
                  backgroundColor: const Color(0xFF1E1E1E),
                  title: Row(
                    children: [
                      Icon(
                        roomType == 'game' 
                            ? Icons.sports_esports_rounded 
                            : Icons.movie_filter_rounded,
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text('Room Invitation', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: Text(
                    '@$hostUsername has invited you to join: $roomName',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('Decline', style: TextStyle(color: Colors.grey)),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          await ref.read(roomRepositoryProvider).joinRoom(roomId);
                          // Route user to the room page
                          if (rootContext.mounted) {
                            if (roomType == 'game') {
                              Navigator.push(
                                rootContext,
                                MaterialPageRoute(
                                  builder: (_) => RoomGameZonePage(
                                    roomId: roomId,
                                    roomName: roomName,
                                  ),
                                ),
                              );
                            } else {
                              Navigator.push(
                                rootContext,
                                MaterialPageRoute(
                                  builder: (_) => RoomWatchPartyPage(
                                    roomId: roomId,
                                    roomName: roomName,
                                  ),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (rootContext.mounted) {
                            ScaffoldMessenger.of(rootContext).showSnackBar(
                              SnackBar(content: Text('Error joining room: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Join Room'),
                    ),
                  ],
                ),
              );
            }
          });
        }
        return;
      }

      // If it's a message, check if we're already chatting with this user
      if (type == 'message') {
        final data = latest['data'] as Map<String, dynamic>?;
        final senderId = data?['sender_id'] as String?;
        final router = ref.read(appRouterProvider);
        final location = router.routerDelegate.currentConfiguration.uri.toString();
        if (senderId != null && location.contains('/chat/$senderId')) {
          // Already in chat, no notification banner needed
          return;
        }
      }

      // Show notification banner if not on calculator/auth
      final router = ref.read(appRouterProvider);
      final location = router.routerDelegate.currentConfiguration.uri.toString();
      final isOnCalculatorOrAuth = location == AppRoutes.calculator || location == AppRoutes.auth;

      if (!isOnCalculatorOrAuth) {
        setState(() {
          _activeNotification = latest;
          _showNotificationBanner = true;
        });

        // Auto dismiss after 4 seconds
        _notificationDismissTimer?.cancel();
        _notificationDismissTimer = Timer(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _showNotificationBanner = false;
            });
          }
        });
      }

      // Auto-refresh lists when notification arrives
      if (type == 'friend_request' || type == 'friend_request_accepted') {
        ref.invalidate(pendingRequestsProvider);
        ref.invalidate(friendsListProvider);
      } else if (type == 'message') {
        ref.invalidate(recentChatsProvider);
      }
    });

    final session = ref.watch(activeCallSessionProvider);
    final isCallSessionActive = session != null;
    final isCallScreenShowing = ref.watch(isCallScreenShowingProvider);

    // Only show ongoing call indicator banner if call is active but call page is minimized,
    // and the user is NOT on the calculator or auth screen.
    final showFloatingBanner = isCallSessionActive && !isCallScreenShowing && !isOnCalculatorOrAuth;

    String? otherUserName;
    if (showFloatingBanner) {
      final myId = ref.read(callRepositoryProvider).supabase?.auth.currentUser?.id;
      _fetchProfilesIfNeeded(session.call);
      if (session.call.callerId == myId) {
        otherUserName = _receiverProfile?['display_name'] as String? ?? _receiverProfile?['username'] as String?;
      } else {
        otherUserName = _callerProfile?['display_name'] as String? ?? _callerProfile?['username'] as String?;
      }
      otherUserName ??= 'User';
    }

    final showNotification = _showNotificationBanner && _activeNotification != null && !isOnCalculatorOrAuth;

    return Stack(
      children: [
        widget.child,
        
        // Notification Banner (does not appear on calculator/auth)
        if (showNotification)
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: SafeArea(
              child: _buildNotificationBanner(context, _activeNotification!),
            ),
          ),

        // Draggable Picture-in-Picture Call Overlay for Video / Sleek Top Banner for Voice
        if (showFloatingBanner)
          if (session.call.isVideo)
            _DraggableCallOverlay(
              session: session,
              otherUserName: otherUserName ?? 'User',
            )
          else
            _OngoingCallTopBanner(
              session: session,
              otherUserName: otherUserName ?? 'User',
            ),
      ],
    );
  }
}

class _OngoingCallTopBanner extends ConsumerStatefulWidget {
  const _OngoingCallTopBanner({
    required this.session,
    required this.otherUserName,
  });

  final CallSession session;
  final String otherUserName;

  @override
  ConsumerState<_OngoingCallTopBanner> createState() => _OngoingCallTopBannerState();
}

class _OngoingCallTopBannerState extends ConsumerState<_OngoingCallTopBanner> {
  Timer? _tickerTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _elapsed = DateTime.now().difference(widget.session.startTime);
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _elapsed = DateTime.now().difference(widget.session.startTime);
        });
      }
    });
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final primaryColor = colors.primary;

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: GestureDetector(
            onTap: () {
              final rootKey = ref.read(rootNavigatorKeyProvider);
              final rootContext = rootKey.currentContext;
              if (rootContext != null) {
                Navigator.push(
                  rootContext,
                  MaterialPageRoute(
                    builder: (context) => ActiveCallPage(call: widget.session.call),
                  ),
                );
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161616).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                  child: Row(
                    children: [
                      // Pulsing green dot
                      const _PulsingIndicator(),
                      const SizedBox(width: 12),
                      
                      // Call Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.otherUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Voice Call • ${_formatDuration(_elapsed)}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Controls (Mute, Speaker, Music, End)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              widget.session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              color: widget.session.isMuted ? Colors.red : Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              ref.read(activeCallSessionProvider.notifier).toggleMute();
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              widget.session.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              ref.read(activeCallSessionProvider.notifier).toggleSpeaker();
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              ref.watch(watchPartyMutedProvider) ? Icons.music_off_rounded : Icons.music_note_rounded,
                              color: ref.watch(watchPartyMutedProvider) ? Colors.red : Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              ref.read(watchPartyMutedProvider.notifier).toggle();
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            onPressed: () {
                              _showSoundControlSheet(context, ref);
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.call_end_rounded,
                              color: Colors.red,
                              size: 18,
                            ),
                            onPressed: () {
                              ref.read(activeCallSessionProvider.notifier).endCurrentCall();
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DraggableCallOverlay extends ConsumerStatefulWidget {
  const _DraggableCallOverlay({
    required this.session,
    required this.otherUserName,
  });

  final CallSession session;
  final String otherUserName;

  @override
  ConsumerState<_DraggableCallOverlay> createState() => _DraggableCallOverlayState();
}

class _DraggableCallOverlayState extends ConsumerState<_DraggableCallOverlay> {
  Offset? _position;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    final double width = 130;
    final double height = 190;

    _position ??= Offset(
      screenWidth - width - 16,
      screenHeight - height - 100,
    );

    double x = _position!.dx;
    double y = _position!.dy;
    x = x.clamp(8.0, screenWidth - width - 8.0);
    y = y.clamp(mediaQuery.padding.top + 8.0, screenHeight - height - 8.0);

    final room = widget.session.callService.room;
    final remoteParticipants = room?.remoteParticipants.values.toList() ?? [];
    
    // Unsafe null-cast prevention logic
    final firstParticipant = remoteParticipants.isNotEmpty ? remoteParticipants.first : null;
    final firstVideoPublication = (firstParticipant != null && firstParticipant.videoTrackPublications.isNotEmpty) 
        ? firstParticipant.videoTrackPublications.first 
        : null;
    final remoteVideoTrack = firstVideoPublication?.track;
    final hasRemoteVideo = remoteVideoTrack != null;

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              _position!.dx + details.delta.dx,
              _position!.dy + details.delta.dy,
            );
          });
        },
        onTap: () {
          final rootKey = ref.read(rootNavigatorKeyProvider);
          final rootContext = rootKey.currentContext;
          if (rootContext != null) {
            Navigator.push(
              rootContext,
              MaterialPageRoute(
                builder: (context) => ActiveCallPage(call: widget.session.call),
              ),
            );
          }
        },
        child: Material(
          elevation: 12,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          color: const Color(0xFF161616),
          child: Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                if (hasRemoteVideo)
                  Positioned.fill(
                    child: VideoTrackRenderer(
                      remoteVideoTrack as VideoTrack,
                      fit: VideoViewFit.cover,
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: Colors.black,
                      child: const Center(
                        child: Icon(Icons.videocam_off, color: Colors.white54, size: 28),
                      ),
                    ),
                  ),

                // Tiny local video thumbnail (PiP in PiP) to keep local camera active and let the user see their feed
                if (room?.localParticipant != null && room!.localParticipant!.videoTrackPublications.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final localPub = room.localParticipant!.videoTrackPublications.first;
                      final localTrack = localPub.track;
                      if (localTrack is VideoTrack) {
                        return Positioned(
                          top: 6,
                          right: 6,
                          width: 36,
                          height: 52,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white38, width: 1),
                              boxShadow: const [
                                BoxShadow(color: Colors.black38, blurRadius: 4),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: VideoTrackRenderer(
                              localTrack as VideoTrack,
                              fit: VideoViewFit.cover,
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],

                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    color: Colors.black87,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Mic Mute Toggle
                        GestureDetector(
                          onTap: () {
                            ref.read(activeCallSessionProvider.notifier).toggleMute();
                          },
                          child: Icon(
                            widget.session.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                            color: widget.session.isMuted ? Colors.redAccent : Colors.white,
                            size: 16,
                          ),
                        ),
                        // Call Speaker Output Toggle
                        GestureDetector(
                          onTap: () {
                            ref.read(activeCallSessionProvider.notifier).toggleSpeaker();
                          },
                          child: Icon(
                            widget.session.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        // Watch Party Mute Toggle
                        GestureDetector(
                          onTap: () {
                            ref.read(watchPartyMutedProvider.notifier).toggle();
                          },
                          child: Icon(
                            ref.watch(watchPartyMutedProvider) ? Icons.music_off_rounded : Icons.music_note_rounded,
                            color: ref.watch(watchPartyMutedProvider) ? Colors.redAccent : Colors.white,
                            size: 16,
                          ),
                        ),
                        // Sound Settings (Tune)
                        GestureDetector(
                          onTap: () {
                            _showSoundControlSheet(context, ref);
                          },
                          child: const Icon(
                            Icons.tune_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        // End Call Button
                        GestureDetector(
                          onTap: () {
                            ref.read(activeCallSessionProvider.notifier).endCurrentCall();
                          },
                          child: const Icon(
                            Icons.call_end_rounded,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                        ),
                        // Maximize/Fullscreen Button
                        GestureDetector(
                          onTap: () {
                            final rootKey = ref.read(rootNavigatorKeyProvider);
                            final rootContext = rootKey.currentContext;
                            if (rootContext != null) {
                              Navigator.push(
                                rootContext,
                                MaterialPageRoute(
                                  builder: (context) => ActiveCallPage(call: widget.session.call),
                                ),
                              );
                            }
                          },
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Colors.white,
                            size: 16,
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
    );
  }
}

class _PulsingIndicator extends StatefulWidget {
  const _PulsingIndicator();

  @override
  State<_PulsingIndicator> createState() => _PulsingIndicatorState();
}

class _PulsingIndicatorState extends State<_PulsingIndicator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
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
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Theme.of(context).colorScheme.primary,
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6 * _controller.value),
                blurRadius: 8 * _controller.value,
                spreadRadius: 2.5 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

void _showSoundControlSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF1E1E1E),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return Consumer(
        builder: (context, ref, _) {
          final session = ref.watch(activeCallSessionProvider);
          final mediaVolume = ref.watch(watchPartyVolumeProvider);
          final isMediaMuted = ref.watch(watchPartyMutedProvider);

          return Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sound Control Panel',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                // Call Speakerphone Control
                if (session != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            session.isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Call Speakerphone',
                                style: TextStyle(color: Colors.white, fontSize: 14),
                              ),
                              Text(
                                session.isSpeakerOn ? 'On (Loudspeaker)' : 'Off (Earpiece/Bluetooth)',
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: session.isSpeakerOn,
                        onChanged: (_) {
                          ref.read(activeCallSessionProvider.notifier).toggleSpeaker();
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 24),
                ],
                // Watch Party Media Volume Slider
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        isMediaMuted ? Icons.music_off_rounded : Icons.music_note_rounded,
                        color: isMediaMuted ? Colors.redAccent : Colors.white70,
                      ),
                      onPressed: () {
                        ref.read(watchPartyMutedProvider.notifier).toggle();
                      },
                    ),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Watch Party Media Volume',
                        style: TextStyle(color: Colors.white, fontSize: 14),
                      ),
                    ),
                    Text(
                      isMediaMuted ? 'Muted' : '${(mediaVolume * 100).toInt()}%',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.volume_down_rounded, color: Colors.white30, size: 16),
                    Expanded(
                      child: Slider(
                        value: isMediaMuted ? 0.0 : mediaVolume,
                        min: 0.0,
                        max: 1.0,
                        onChanged: (val) {
                          if (isMediaMuted && val > 0.0) {
                            ref.read(watchPartyMutedProvider.notifier).toggle();
                          }
                          ref.read(watchPartyVolumeProvider.notifier).setVolume(val);
                        },
                        activeColor: Theme.of(context).colorScheme.primary,
                        inactiveColor: Colors.white12,
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded, color: Colors.white30, size: 16),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      );
    },
  );
}
