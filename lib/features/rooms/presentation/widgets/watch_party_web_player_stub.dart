import 'dart:typed_data';
import 'package:flutter/material.dart';

class WatchPartyWebController {
  bool isPlaying = false;
  Duration currentPosition = Duration.zero;
  String? currentUrl;
  void Function(bool isPlaying, Duration position)? onPlaybackChanged;

  void play() {}
  void pause() {}
  void seekTo(Duration position) {}
  void setVolume(double volume) {}
  void mute() {}
  void unMute() {}
  void setPlaybackRate(double rate) {}
  void loadSource(String url, {required bool isYouTube, bool autoPlay = true}) {}
  String? createBlobUrl(Uint8List bytes, String filename) => null;
  void loadBlobUrl(String blobUrl, {bool autoPlay = true}) {}
  void dispose() {}
}

class WatchPartyWebPlayerWidget extends StatelessWidget {
  const WatchPartyWebPlayerWidget({
    super.key,
    required this.controller,
    this.isFullscreen = false,
  });

  final WatchPartyWebController controller;
  final bool isFullscreen;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: const Center(
        child: Text(
          'Web player not supported on this platform',
          style: TextStyle(color: Colors.white60),
        ),
      ),
    );
  }
}
