import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// State model for Watch Party PiP overlay state
class WatchPartyPipState {
  final bool isPipActive;
  final bool isMinimized;
  final String? roomId;
  final String? roomName;
  final String? videoUrl;

  const WatchPartyPipState({
    this.isPipActive = false,
    this.isMinimized = false,
    this.roomId,
    this.roomName,
    this.videoUrl,
  });

  WatchPartyPipState copyWith({
    bool? isPipActive,
    bool? isMinimized,
    String? roomId,
    String? roomName,
    String? videoUrl,
  }) {
    return WatchPartyPipState(
      isPipActive: isPipActive ?? this.isPipActive,
      isMinimized: isMinimized ?? this.isMinimized,
      roomId: roomId ?? this.roomId,
      roomName: roomName ?? this.roomName,
      videoUrl: videoUrl ?? this.videoUrl,
    );
  }
}

class WatchPartyPipNotifier extends Notifier<WatchPartyPipState> {
  @override
  WatchPartyPipState build() => const WatchPartyPipState();

  void enterPip({required String roomId, required String roomName, String? videoUrl}) {
    state = WatchPartyPipState(
      isPipActive: true,
      isMinimized: true,
      roomId: roomId,
      roomName: roomName,
      videoUrl: videoUrl,
    );
  }

  void toggleMinimize() {
    state = state.copyWith(isMinimized: !state.isMinimized);
  }

  void exitPip() {
    state = const WatchPartyPipState();
  }
}

final watchPartyPipProvider = NotifierProvider<WatchPartyPipNotifier, WatchPartyPipState>(
  WatchPartyPipNotifier.new,
);

/// Responsive Picture-in-Picture (PiP) Overlay Widget (R2)
class FloatingPipOverlay extends StatefulWidget {
  final Widget child;
  final bool initialMinimized;
  final Size screenSize;
  final Size pipSize;
  final VoidCallback? onToggleMinimize;
  final VoidCallback? onClose;

  const FloatingPipOverlay({
    super.key,
    required this.child,
    this.initialMinimized = false,
    this.screenSize = const Size(400, 500),
    this.pipSize = const Size(160, 90),
    this.onToggleMinimize,
    this.onClose,
  });

  @override
  State<FloatingPipOverlay> createState() => _FloatingPipOverlayState();
}

class _FloatingPipOverlayState extends State<FloatingPipOverlay> {
  late bool _isMinimized;
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _isMinimized = widget.initialMinimized;
    _position = Offset(
      widget.screenSize.width - widget.pipSize.width - 16,
      widget.screenSize.height - widget.pipSize.height - 50,
    );
  }

  void toggleMinimize() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
    widget.onToggleMinimize?.call();
  }

  void updatePosition(Offset delta) {
    setState(() {
      final newX = (_position.dx + delta.dx).clamp(0.0, widget.screenSize.width - widget.pipSize.width);
      final newY = (_position.dy + delta.dy).clamp(0.0, widget.screenSize.height - widget.pipSize.height);
      _position = Offset(newX, newY);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.screenSize.width,
      height: widget.screenSize.height,
      child: Stack(
        children: [
          if (!_isMinimized)
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                key: const ValueKey('full_player'),
                width: widget.screenSize.width,
                height: 220,
                color: Colors.black,
                child: Column(
                  children: [
                    Expanded(child: widget.child),
                    IconButton(
                      key: const ValueKey('pip_minimize_button'),
                      icon: const Icon(Icons.picture_in_picture_alt, color: Colors.white),
                      onPressed: toggleMinimize,
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned(
              left: _position.dx,
              top: _position.dy,
              child: GestureDetector(
                key: const ValueKey('pip_drag_gesture'),
                onPanUpdate: (details) => updatePosition(details.delta),
                child: Container(
                  key: const ValueKey('floating_pip_window'),
                  width: widget.pipSize.width,
                  height: widget.pipSize.height,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.cyanAccent, width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      Center(child: widget.child),
                      Positioned(
                        right: 4,
                        top: 4,
                        child: GestureDetector(
                          key: const ValueKey('pip_maximize_button'),
                          onTap: toggleMinimize,
                          child: const Icon(Icons.fullscreen, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
