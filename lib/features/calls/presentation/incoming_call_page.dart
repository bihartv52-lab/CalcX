import 'dart:async';
import 'package:calcx/core/models/call.dart';
import 'package:calcx/features/calls/data/call_repository.dart';
import 'package:calcx/features/calls/presentation/active_call_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomingCallPage extends ConsumerStatefulWidget {
  const IncomingCallPage({
    super.key,
    required this.call,
  });

  final Call call;

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage>
    with SingleTickerProviderStateMixin {
  Timer? _timeoutTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Map<String, dynamic>? _callerProfile;

  @override
  void initState() {
    super.initState();
    _callerProfile = widget.call.callerProfile;
    if (_callerProfile == null) {
      _fetchCallerProfile();
    }

    // Setup pulse animation for avatar
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-reject after 30 seconds
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (mounted) {
        _rejectCall();
      }
    });
  }

  Future<void> _fetchCallerProfile() async {
    try {
      final repository = ref.read(callRepositoryProvider);
      final supabase = repository.supabase;
      if (supabase != null) {
        final profile = await supabase
            .from('profiles')
            .select()
            .eq('id', widget.call.callerId)
            .single();
        if (mounted) {
          setState(() {
            _callerProfile = profile;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching caller profile: $e');
    }
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _acceptCall() async {
    try {
      final repository = ref.read(callRepositoryProvider);
      await repository.acceptCall(widget.call.id);

      if (mounted) {
        // Navigate to active call page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ActiveCallPage(call: widget.call.copyWith(callerProfile: _callerProfile)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error accepting call: $e')),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _rejectCall() async {
    try {
      final repository = ref.read(callRepositoryProvider);
      await repository.rejectCall(widget.call.id);

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final callerName = _callerProfile?['display_name'] ?? 'Unknown';
    final callerAvatar = _callerProfile?['avatar_url'] as String?;
    final isVideo = widget.call.isVideo;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),

            // Caller Avatar with Pulse Animation
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Theme.of(context).primaryColor,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 73,
                  backgroundImage:
                      callerAvatar != null ? NetworkImage(callerAvatar) : null,
                  child: callerAvatar == null
                      ? Text(
                          callerName[0].toUpperCase(),
                          style: const TextStyle(fontSize: 48),
                        )
                      : null,
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Caller Name
            Text(
              callerName,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            // Call Type
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isVideo ? Icons.videocam : Icons.call,
                  color: Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Incoming ${isVideo ? 'Video' : 'Audio'} Call',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject Button
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: const Icon(
                            Icons.call_end,
                            size: 32,
                            color: Colors.white,
                          ),
                          onPressed: _rejectCall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Decline',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),

                  // Accept Button
                  Column(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.green.withValues(alpha: 0.5),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            isVideo ? Icons.videocam : Icons.call,
                            size: 32,
                            color: Colors.white,
                          ),
                          onPressed: _acceptCall,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Accept',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
