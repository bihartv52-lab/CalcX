import 'dart:async';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';

class ActiveCallPage extends ConsumerStatefulWidget {
  const ActiveCallPage({super.key, required this.call});

  final Call call;

  @override
  ConsumerState<ActiveCallPage> createState() => _ActiveCallPageState();
}

class _ActiveCallPageState extends ConsumerState<ActiveCallPage> {
  Timer? _tickerTimer;
  Map<String, dynamic>? _callerProfile;
  Map<String, dynamic>? _receiverProfile;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _callerProfile = widget.call.callerProfile;
    _receiverProfile = widget.call.receiverProfile;
    _fetchProfilesIfNeeded();

    // Set call screen showing synchronously to true to hide overlays immediately
    ref.read(isCallScreenShowingProvider.notifier).state = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = ref.read(activeCallSessionProvider);
      if (session == null || session.call.id != widget.call.id) {
        ref.read(activeCallSessionProvider.notifier).startCallSession(widget.call);
      }
      _startTicker();
    });
  }

  void _startTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final session = ref.read(activeCallSessionProvider);
      if (session != null) {
        setState(() {
          _elapsed = DateTime.now().difference(session.startTime);
        });
      }
    });
  }

  Future<void> _fetchProfilesIfNeeded() async {
    final supabase = ref.read(callRepositoryProvider).supabase;
    if (supabase == null) return;
    try {
      if (_callerProfile == null) {
        final caller = await supabase
            .from('profiles')
            .select()
            .eq('id', widget.call.callerId)
            .single();
        if (mounted) {
          setState(() {
            _callerProfile = caller;
          });
        }
      }
      if (_receiverProfile == null) {
        final receiver = await supabase
            .from('profiles')
            .select()
            .eq('id', widget.call.receiverId)
            .single();
        if (mounted) {
          setState(() {
            _receiverProfile = receiver;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching profiles in ActiveCallPage: $e');
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(isCallScreenShowingProvider.notifier).state = false;
    });
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(activeCallSessionProvider);
    final repository = ref.read(callRepositoryProvider);
    final myId = repository.supabase?.auth.currentUser?.id;

    // Listen to call ending
    ref.listen<CallSession?>(activeCallSessionProvider, (previous, next) {
      if (next == null && mounted) {
        Navigator.of(context).pop();
      }
    });

    String? otherUserName;
    if (widget.call.callerId == myId) {
      otherUserName = _receiverProfile?['display_name'] as String? ?? _receiverProfile?['username'] as String?;
    } else {
      otherUserName = _callerProfile?['display_name'] as String? ?? _callerProfile?['username'] as String?;
    }
    otherUserName ??= 'User';

    final isConnecting = session == null;
    final room = session?.callService.room;
    final remoteParticipants = room?.remoteParticipants.values.toList() ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Video Views
            if (widget.call.isVideo && !isConnecting) ...[
              // Remote Video (Full Screen)
              if (remoteParticipants.isNotEmpty)
                Positioned.fill(
                  child: _RemoteVideoView(
                    participant: remoteParticipants.first,
                  ),
                )
              else
                const Center(
                  child: Text(
                    'Waiting for other participant...',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),

              // Local Video (Picture-in-Picture)
              if (session.isVideoOn)
                Positioned(
                  top: 80,
                  right: 16,
                  child: Container(
                    width: 100,
                    height: 140,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24, width: 1.5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10.5),
                      child: _LocalVideoView(room: room),
                    ),
                  ),
                ),
            ],

            // Audio Call UI
            if (!widget.call.isVideo || isConnecting)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      child: Text(
                        otherUserName.isNotEmpty ? otherUserName[0].toUpperCase() : 'U',
                        style: const TextStyle(fontSize: 48, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      otherUserName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),

            // Top Bar with Minimize Button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
                      onPressed: () {
                        // Simply pop to minimize (go back to app with ongoing call)
                        Navigator.of(context).pop();
                      },
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isConnecting ? 'Connecting...' : otherUserName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            isConnecting ? '' : _formatDuration(_elapsed),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Spacer to balance back button
                  ],
                ),
              ),
            ),

            // Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute Button
                    _CallControlButton(
                      icon: (session?.isMuted ?? false) ? Icons.mic_off : Icons.mic,
                      label: (session?.isMuted ?? false) ? 'Unmute' : 'Mute',
                      onPressed: () => ref.read(activeCallSessionProvider.notifier).toggleMute(),
                      isActive: !(session?.isMuted ?? false),
                    ),

                    // Speaker / Audio Output Button
                    _CallControlButton(
                      icon: (session?.isSpeakerOn ?? true) ? Icons.volume_up : Icons.volume_down,
                      label: 'Audio',
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: const Color(0xFF161616),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (context) {
                            return Consumer(
                              builder: (context, ref, _) {
                                final sess = ref.watch(activeCallSessionProvider);
                                final isSpeaker = sess?.isSpeakerOn ?? true;
                                return SafeArea(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: 16.0),
                                        child: Text(
                                          'Select Audio Output',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.volume_up, color: Colors.white),
                                        title: const Text('Speakerphone', style: TextStyle(color: Colors.white)),
                                        trailing: isSpeaker ? const Icon(Icons.check, color: Colors.green) : null,
                                        onTap: () {
                                          if (!isSpeaker) {
                                            ref.read(activeCallSessionProvider.notifier).toggleSpeaker();
                                          }
                                          Navigator.pop(context);
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.hearing, color: Colors.white),
                                        title: const Text('Earpiece / Bluetooth', style: TextStyle(color: Colors.white)),
                                        trailing: !isSpeaker ? const Icon(Icons.check, color: Colors.green) : null,
                                        onTap: () {
                                          if (isSpeaker) {
                                            ref.read(activeCallSessionProvider.notifier).toggleSpeaker();
                                          }
                                          Navigator.pop(context);
                                        },
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                      isActive: session?.isSpeakerOn ?? true,
                    ),

                    // Video Button (if video call)
                    if (widget.call.isVideo)
                      _CallControlButton(
                        icon: (session?.isVideoOn ?? false) ? Icons.videocam : Icons.videocam_off,
                        label: 'Video',
                        onPressed: () => ref.read(activeCallSessionProvider.notifier).toggleVideo(),
                        isActive: session?.isVideoOn ?? false,
                      ),

                    // Switch Camera (if video on)
                    if (widget.call.isVideo && (session?.isVideoOn ?? false))
                      _CallControlButton(
                        icon: Icons.flip_camera_ios,
                        label: 'Flip',
                        onPressed: () => ref.read(activeCallSessionProvider.notifier).switchCamera(),
                      ),

                    // Screen Share Button
                    if (session != null)
                      _CallControlButton(
                        icon: session.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                        label: session.isScreenSharing ? 'Stop Share' : 'Share Screen',
                        onPressed: () => ref.read(activeCallSessionProvider.notifier).toggleScreenShare(),
                        isActive: session.isScreenSharing,
                      ),

                    // End Call Button
                    _CallControlButton(
                      icon: Icons.call_end,
                      label: 'End',
                      onPressed: () {
                        ref.read(activeCallSessionProvider.notifier).endCurrentCall();
                      },
                      color: Colors.red,
                    ),
                  ],
                ),
              ),
            ),

            // Loading Indicator
            if (isConnecting) const Center(child: CircularProgressIndicator()),
          ],
        ),
      ),
    );
  }
}

class _CallControlButton extends StatelessWidget {
  const _CallControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
    this.isActive = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? (isActive ? Colors.white : Colors.white38);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color ?? Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: buttonColor),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: buttonColor, fontSize: 12)),
      ],
    );
  }
}

class _RemoteVideoView extends StatelessWidget {
  const _RemoteVideoView({required this.participant});

  final RemoteParticipant participant;

  @override
  Widget build(BuildContext context) {
    // Filter the video publications to check if screen share is active
    final screenSharePub = participant.videoTrackPublications
        .where((pub) => pub.source == TrackSource.screenShareVideo)
        .firstOrNull;
    final videoTrack = screenSharePub?.track ?? (participant.videoTrackPublications.isNotEmpty
        ? participant.videoTrackPublications.first.track
        : null);

    if (videoTrack == null) {
      return const Center(
        child: Text('No video', style: TextStyle(color: Colors.white70)),
      );
    }

    return VideoTrackRenderer(
      videoTrack as VideoTrack,
      fit: screenSharePub != null ? VideoViewFit.contain : VideoViewFit.cover,
    );
  }
}

class _LocalVideoView extends StatelessWidget {
  const _LocalVideoView({required this.room});

  final Room? room;

  @override
  Widget build(BuildContext context) {
    final videoTrack =
        room?.localParticipant?.videoTrackPublications.isNotEmpty == true
        ? room!.localParticipant!.videoTrackPublications.first.track
        : null;

    if (videoTrack == null) {
      return Container(
        color: Colors.black,
        child: const Center(
          child: Icon(Icons.videocam_off, color: Colors.white),
        ),
      );
    }

    return VideoTrackRenderer(
      videoTrack as VideoTrack,
      fit: VideoViewFit.cover,
    );
  }
}
