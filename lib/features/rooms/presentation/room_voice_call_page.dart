import 'dart:async';
import 'package:calcx/core/widgets/glass_card.dart';
import 'package:calcx/core/services/livekit_token_service.dart';
import 'package:calcx/features/calls/data/livekit_call_service.dart';
import 'package:calcx/features/friends/data/friends_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoomVoiceCallPage extends ConsumerStatefulWidget {
  const RoomVoiceCallPage({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  ConsumerState<RoomVoiceCallPage> createState() => _RoomVoiceCallPageState();
}

class _RoomVoiceCallPageState extends ConsumerState<RoomVoiceCallPage> {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isInCall = false;
  bool _isConnecting = false;
  DateTime? _callStartTime;
  final Map<String, String> _profileNames = {};

  @override
  void dispose() {
    ref.read(liveKitCallServiceProvider).room?.removeListener(_onRoomUpdate);
    ref.read(liveKitCallServiceProvider).leaveRoom();
    super.dispose();
  }

  void _onRoomUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<String> _getSenderName(String senderId) async {
    if (_profileNames.containsKey(senderId)) {
      return _profileNames[senderId]!;
    }

    try {
      final repo = ref.read(friendsRepositoryProvider);
      final profile = await repo.getUserById(senderId);
      if (profile != null) {
        final name = profile.displayName.isNotEmpty ? profile.displayName : profile.username;
        setState(() {
          _profileNames[senderId] = name;
        });
        return name;
      }
    } catch (_) {}

    return senderId.substring(0, 8);
  }

  Future<void> _startCall() async {
    setState(() => _isConnecting = true);

    try {
      final myId = Supabase.instance.client.auth.currentUser?.id;
      if (myId == null) {
        throw StateError('Not logged in');
      }

      final tokenService = ref.read(livekitTokenServiceProvider);
      final callService = ref.read(liveKitCallServiceProvider);

      final token = await tokenService.getToken(
        roomName: widget.roomId,
        participantName: myId,
      );

      await callService.joinRoom(
        roomName: widget.roomId,
        token: token,
        video: false,
      );

      // Set default speakerphone
      try {
        await Hardware.instance.setSpeakerphoneOn(_isSpeakerOn);
      } catch (e) {
        debugPrint('Error setting initial speakerphone: $e');
      }

      // Listen to room updates
      callService.room?.addListener(_onRoomUpdate);

      setState(() {
        _isInCall = true;
        _isConnecting = false;
        _callStartTime = DateTime.now();
      });

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Room voice call started!')));
      }
    } catch (e) {
      setState(() => _isConnecting = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to join voice call: $e')));
      }
    }
  }

  Future<void> _endCall() async {
    try {
      ref.read(liveKitCallServiceProvider).room?.removeListener(_onRoomUpdate);
      await ref.read(liveKitCallServiceProvider).leaveRoom();
    } catch (e) {
      debugPrint('Error leaving voice call: $e');
    }

    setState(() {
      _isInCall = false;
      _callStartTime = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Call ended')));
    }
  }

  void _toggleMute() async {
    await ref.read(liveKitCallServiceProvider).toggleMicrophone();
    setState(() => _isMuted = !_isMuted);
  }

  void _toggleSpeaker() async {
    final newState = !_isSpeakerOn;
    try {
      await Hardware.instance.setSpeakerphoneOn(newState);
      setState(() => _isSpeakerOn = newState);
    } catch (e) {
      debugPrint('Error toggling speaker: $e');
    }
  }

  String _getCallDuration() {
    if (_callStartTime == null) return '00:00';
    final duration = DateTime.now().difference(_callStartTime!);
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
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
              'Room Voice Call',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      body: _isConnecting
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isInCall) ...[
                  // Start Call Section
                  GlassCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.call_rounded,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Room Voice Call',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Start a voice call with all room members',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _startCall,
                            icon: const Icon(Icons.call_rounded),
                            label: const Text('Start Call'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Features
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Features',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const _FeatureItem(
                          icon: Icons.people_rounded,
                          title: 'Multi-participant',
                          subtitle: 'Talk with all room members',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureItem(
                          icon: Icons.mic_rounded,
                          title: 'Mute/Unmute',
                          subtitle: 'Control your microphone',
                        ),
                        const SizedBox(height: 12),
                        const _FeatureItem(
                          icon: Icons.volume_up_rounded,
                          title: 'Speaker Control',
                          subtitle: 'Toggle speaker on/off',
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Active Call Section
                  GlassCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.call_rounded,
                          size: 80,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Call in Progress',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder(
                          stream: Stream.periodic(const Duration(seconds: 1)),
                          builder: (context, snapshot) {
                            return Text(
                              _getCallDuration(),
                              style: Theme.of(context).textTheme.headlineMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Call Controls
                  GlassCard(
                    child: Column(
                      children: [
                        Text(
                          'Call Controls',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Mute Button
                            Column(
                              children: [
                                IconButton.filled(
                                  onPressed: _toggleMute,
                                  icon: Icon(
                                    _isMuted
                                        ? Icons.mic_off_rounded
                                        : Icons.mic_rounded,
                                  ),
                                  iconSize: 32,
                                  style: IconButton.styleFrom(
                                    backgroundColor: _isMuted
                                        ? Colors.red.withValues(alpha: 0.2)
                                        : Theme.of(context).colorScheme.primary
                                              .withValues(alpha: 0.2),
                                    padding: const EdgeInsets.all(20),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _isMuted ? 'Unmute' : 'Mute',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),

                            // Speaker Button
                            Column(
                              children: [
                                IconButton.filled(
                                  onPressed: _toggleSpeaker,
                                  icon: Icon(
                                    _isSpeakerOn
                                        ? Icons.volume_up_rounded
                                        : Icons.volume_off_rounded,
                                  ),
                                  iconSize: 32,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.2),
                                    padding: const EdgeInsets.all(20),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Speaker',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),

                            // End Call Button
                            Column(
                              children: [
                                IconButton.filled(
                                  onPressed: _endCall,
                                  icon: const Icon(Icons.call_end_rounded),
                                  iconSize: 32,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    padding: const EdgeInsets.all(20),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'End Call',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Participants in Call
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'In Call',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _ParticipantItem(
                          name: 'You',
                          isMuted: _isMuted,
                          isSpeaking: !_isMuted,
                        ),
                        const SizedBox(height: 12),
                        ...(() {
                          final room = ref.read(liveKitCallServiceProvider).room;
                          final remotes = room?.remoteParticipants.values.toList() ?? [];
                          if (remotes.isEmpty) {
                            return [
                              Text(
                                'No other participants in call yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontStyle: FontStyle.italic,
                                ),
                              )
                            ];
                          }

                          return remotes.map((p) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: FutureBuilder<String>(
                                future: _getSenderName(p.identity),
                                builder: (context, snapshot) {
                                  final name = snapshot.data ?? p.identity.substring(0, 8);
                                  return _ParticipantItem(
                                    name: name,
                                    isMuted: !p.isMicrophoneEnabled(),
                                    isSpeaking: p.isSpeaking,
                                  );
                                },
                              ),
                            );
                          }).toList();
                        }()),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ParticipantItem extends StatelessWidget {
  const _ParticipantItem({
    required this.name,
    required this.isMuted,
    required this.isSpeaking,
  });

  final String name;
  final bool isMuted;
  final bool isSpeaking;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                name[0].toUpperCase(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isSpeaking)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.green, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
        if (isMuted)
          Icon(
            Icons.mic_off_rounded,
            size: 20,
            color: Colors.red.withValues(alpha: 0.7),
          ),
      ],
    );
  }
}
