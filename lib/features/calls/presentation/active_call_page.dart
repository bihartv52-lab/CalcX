import 'dart:async';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/core/widgets/incoming_call_listener.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:calcx/features/chat/data/chat_repository.dart';
import 'package:calcx/features/chat/presentation/chat_page.dart';
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

  bool _showChatOverlay = false;
  final TextEditingController _callChatController = TextEditingController();
  final ScrollController _callChatScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _callerProfile = widget.call.callerProfile;
    _receiverProfile = widget.call.receiverProfile;
    _fetchProfilesIfNeeded();

    // Set call screen showing synchronously to true to hide overlays immediately
    ref.read(isCallScreenShowingProvider.notifier).state = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final session = ref.read(activeCallSessionProvider);
      if (session == null || session.call.id != widget.call.id) {
        try {
          await ref.read(activeCallSessionProvider.notifier).startCallSession(widget.call);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to connect call: $e')),
            );
            Navigator.of(context).pop();
          }
        }
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

  Future<void> _sendCallChatMessage(String otherUserId) async {
    final text = _callChatController.text.trim();
    if (text.isEmpty) return;
    _callChatController.clear();
    try {
      await ref.read(chatRepositoryProvider).sendMessage(receiverId: otherUserId, content: text);
      if (_callChatScrollController.hasClients) {
        _callChatScrollController.animateTo(
          _callChatScrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send in-call message: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tickerTimer?.cancel();
    _callChatController.dispose();
    _callChatScrollController.dispose();
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

    String? otherUserId;
    String? otherUserName;
    if (widget.call.callerId == myId) {
      otherUserId = widget.call.receiverId;
      otherUserName = _receiverProfile?['display_name'] as String? ?? _receiverProfile?['username'] as String?;
    } else {
      otherUserId = widget.call.callerId;
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

            // In-Call Chat Overlay Strip (Floating on Video)
            if (_showChatOverlay && otherUserId != null)
              Builder(
                builder: (context) {
                  final String chatPartnerId = otherUserId!;
                  return Positioned(
                    left: 16,
                    right: 16,
                    bottom: 125,
                    height: 240,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xEE141414),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.6),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Header
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: const BoxDecoration(
                                border: Border(bottom: BorderSide(color: Colors.white10)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.chat_bubble_rounded, color: Colors.blueAccent, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'In-Call Chat • $otherUserName',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const Spacer(),
                                  GestureDetector(
                                    onTap: () => setState(() => _showChatOverlay = false),
                                    child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                                  ),
                                ],
                              ),
                            ),

                            // Chat Messages List
                            Expanded(
                              child: Consumer(
                                builder: (context, ref, _) {
                                  final messagesAsync = ref.watch(chatMessagesProvider(chatPartnerId));
                                  return messagesAsync.when(
                                    data: (messages) {
                                      if (messages.isEmpty) {
                                        return const Center(
                                          child: Text(
                                            'No messages yet. Send a quick chat!',
                                            style: TextStyle(color: Colors.white38, fontSize: 12),
                                          ),
                                        );
                                      }
                                      final recent = messages.take(30).toList().reversed.toList();
                                      return ListView.builder(
                                        controller: _callChatScrollController,
                                        padding: const EdgeInsets.all(10),
                                        itemCount: recent.length,
                                        itemBuilder: (context, index) {
                                          final msg = recent[index];
                                          final isMe = msg.senderId == myId;
                                          return Align(
                                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                            child: Container(
                                              margin: const EdgeInsets.symmetric(vertical: 3),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: isMe
                                                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
                                                    : const Color(0xFF282828),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                msg.content,
                                                style: const TextStyle(color: Colors.white, fontSize: 12.5),
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                    loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    error: (_, __) => const Center(
                                      child: Text('Error loading chat', style: TextStyle(color: Colors.white38, fontSize: 12)),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // Input Field
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: const BoxDecoration(
                                border: Border(top: BorderSide(color: Colors.white10)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _callChatController,
                                      style: const TextStyle(color: Colors.white, fontSize: 13),
                                      decoration: InputDecoration(
                                        hintText: 'Type a message...',
                                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        fillColor: Colors.white10,
                                        filled: true,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(20),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      onSubmitted: (_) => _sendCallChatMessage(chatPartnerId),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(Icons.send_rounded, color: Colors.blueAccent, size: 20),
                                    onPressed: () => _sendCallChatMessage(chatPartnerId),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Top Bar with Minimize & PiP Buttons
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
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 30),
                      tooltip: 'Minimize call',
                      onPressed: () {
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
                    IconButton(
                      icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white, size: 22),
                      tooltip: 'Minimize to Picture-in-Picture (PiP)',
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Controls Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.95),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 8),

                      // Mute Button
                      _CallControlButton(
                        icon: (session?.isMuted ?? false) ? Icons.mic_off : Icons.mic,
                        label: (session?.isMuted ?? false) ? 'Unmute' : 'Mute',
                        onPressed: () => ref.read(activeCallSessionProvider.notifier).toggleMute(),
                        isActive: !(session?.isMuted ?? false),
                      ),
                      const SizedBox(width: 12),

                      // Speaker Output Button
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
                      const SizedBox(width: 12),

                      // Sound Control Sheet Trigger
                      _CallControlButton(
                        icon: Icons.tune_rounded,
                        label: 'Sound',
                        onPressed: () {
                          showSoundControlSheet(context, ref);
                        },
                      ),
                      const SizedBox(width: 12),

                      // In-Call Chat Button
                      _CallControlButton(
                        icon: _showChatOverlay ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                        label: 'Chat',
                        onPressed: () {
                          setState(() {
                            _showChatOverlay = !_showChatOverlay;
                          });
                        },
                        isActive: _showChatOverlay,
                      ),
                      const SizedBox(width: 12),

                      // Video Button (if video call)
                      if (widget.call.isVideo) ...[
                        _CallControlButton(
                          icon: (session?.isVideoOn ?? false) ? Icons.videocam : Icons.videocam_off,
                          label: 'Video',
                          onPressed: () => ref.read(activeCallSessionProvider.notifier).toggleVideo(),
                          isActive: session?.isVideoOn ?? false,
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Switch Camera (if video on)
                      if (widget.call.isVideo && (session?.isVideoOn ?? false)) ...[
                        _CallControlButton(
                          icon: Icons.flip_camera_ios,
                          label: 'Flip',
                          onPressed: () => ref.read(activeCallSessionProvider.notifier).switchCamera(),
                        ),
                        const SizedBox(width: 12),
                      ],

                      // Screen Share Button
                      if (session != null) ...[
                        _CallControlButton(
                          icon: session.isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                          label: session.isScreenSharing ? 'Stop Share' : 'Share Screen',
                          onPressed: () => ref.read(activeCallSessionProvider.notifier).toggleScreenShare(),
                          isActive: session.isScreenSharing,
                        ),
                        const SizedBox(width: 12),
                      ],

                      // End Call Button
                      _CallControlButton(
                        icon: Icons.call_end,
                        label: 'End',
                        onPressed: () {
                          ref.read(activeCallSessionProvider.notifier).endCurrentCall();
                        },
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
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
