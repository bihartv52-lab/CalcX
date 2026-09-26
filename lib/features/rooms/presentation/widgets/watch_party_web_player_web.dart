import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

class WatchPartyWebController {
  html.DivElement? _container;
  html.IFrameElement? _iframeElement;
  html.VideoElement? _videoElement;

  StreamSubscription<html.Event>? _messageSub;
  StreamSubscription<html.Event>? _videoPlaySub;
  StreamSubscription<html.Event>? _videoPauseSub;
  StreamSubscription<html.Event>? _videoTimeSub;
  StreamSubscription<html.Event>? _videoSeekSub;

  bool isPlaying = false;
  double _currentSeconds = 0.0;
  Duration get currentPosition => Duration(milliseconds: (_currentSeconds * 1000).toInt());
  void Function(bool isPlaying, Duration position)? onPlaybackChanged;

  bool _isYouTube = false;
  String? _currentUrl;
  String? get currentUrl => _currentUrl;
  final String viewId;

  WatchPartyWebController()
      : viewId = 'calcx-watch-party-${DateTime.now().millisecondsSinceEpoch}' {
    _initContainer();
  }

  void _initContainer() {
    _container = html.DivElement()
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.backgroundColor = '#000000'
      ..style.display = 'flex'
      ..style.alignItems = 'center'
      ..style.justifyContent = 'center'
      ..style.overflow = 'hidden';

    ui_web.platformViewRegistry.registerViewFactory(
      viewId,
      (int id) => _container!,
    );

    // Global listener for YouTube iframe postMessage API
    _messageSub = html.window.onMessage.listen((event) {
      final data = event.data;
      if (data is String) {
        try {
          final decoded = jsonDecode(data);
          if (decoded is Map<String, dynamic>) {
            final evt = decoded['event'];
            if (evt == 'infoDelivery') {
              final info = decoded['info'];
              if (info is Map<String, dynamic>) {
                if (info.containsKey('currentTime')) {
                  _currentSeconds = (info['currentTime'] as num).toDouble();
                }
                if (info.containsKey('playerState')) {
                  final state = info['playerState'] as int;
                  final nowPlaying = (state == 1 || state == 3);
                  if (isPlaying != nowPlaying) {
                    isPlaying = nowPlaying;
                    onPlaybackChanged?.call(isPlaying, currentPosition);
                  }
                }
              }
            } else if (evt == 'onStateChange') {
              final state = decoded['info'];
              if (state is int) {
                final nowPlaying = (state == 1 || state == 3);
                if (isPlaying != nowPlaying) {
                  isPlaying = nowPlaying;
                  onPlaybackChanged?.call(isPlaying, currentPosition);
                }
              }
            }
          }
        } catch (_) {}
      }
    });
  }

  void _cleanupVideoSubscriptions() {
    _videoPlaySub?.cancel();
    _videoPauseSub?.cancel();
    _videoTimeSub?.cancel();
    _videoSeekSub?.cancel();
    _videoPlaySub = null;
    _videoPauseSub = null;
    _videoTimeSub = null;
    _videoSeekSub = null;
  }

  void loadSource(String url, {required bool isYouTube, bool autoPlay = true}) {
    _currentUrl = url;
    _isYouTube = isYouTube;
    _container?.children.clear();
    _cleanupVideoSubscriptions();

    if (isYouTube) {
      _videoElement = null;
      _iframeElement = html.IFrameElement()
        ..src = url
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..setAttribute(
          'allow',
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share',
        )
        ..setAttribute('allowfullscreen', 'true');
      _container?.append(_iframeElement!);
    } else {
      _iframeElement = null;
      _videoElement = html.VideoElement()
        ..src = url
        ..controls = true
        ..autoplay = autoPlay
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'contain'
        ..style.backgroundColor = '#000000'
        ..setAttribute('playsinline', 'true');

      _videoPlaySub = _videoElement!.onPlay.listen((_) {
        isPlaying = true;
        onPlaybackChanged?.call(true, currentPosition);
      });
      _videoPauseSub = _videoElement!.onPause.listen((_) {
        isPlaying = false;
        onPlaybackChanged?.call(false, currentPosition);
      });
      _videoTimeSub = _videoElement!.onTimeUpdate.listen((_) {
        _currentSeconds = _videoElement!.currentTime.toDouble();
      });
      _videoSeekSub = _videoElement!.onSeeked.listen((_) {
        _currentSeconds = _videoElement!.currentTime.toDouble();
        onPlaybackChanged?.call(isPlaying, currentPosition);
      });

      _container?.append(_videoElement!);
    }
  }

  String? createBlobUrl(Uint8List bytes, String filename) {
    try {
      final ext = filename.split('.').last.toLowerCase();
      String mime = 'video/mp4';
      if (ext == 'webm') mime = 'video/webm';
      if (ext == 'ogg') mime = 'video/ogg';
      if (ext == 'mov') mime = 'video/quicktime';
      final blob = html.Blob([bytes], mime);
      return html.Url.createObjectUrlFromBlob(blob);
    } catch (e) {
      debugPrint('Error creating blob url: $e');
      return null;
    }
  }

  void loadBlobUrl(String blobUrl, {bool autoPlay = true}) {
    loadSource(blobUrl, isYouTube: false, autoPlay: autoPlay);
  }

  void _sendYtCommand(String func, [dynamic arg]) {
    if (_iframeElement?.contentWindow == null) return;
    try {
      final payload = jsonEncode({
        'event': 'command',
        'func': func,
        'args': arg != null ? [arg] : [],
      });
      _iframeElement!.contentWindow!.postMessage(payload, '*');
    } catch (_) {}
  }

  void play() {
    isPlaying = true;
    if (_isYouTube) {
      _sendYtCommand('playVideo');
    } else {
      _videoElement?.play();
    }
  }

  void pause() {
    isPlaying = false;
    if (_isYouTube) {
      _sendYtCommand('pauseVideo');
    } else {
      _videoElement?.pause();
    }
  }

  void seekTo(Duration position) {
    final seconds = position.inMilliseconds / 1000.0;
    _currentSeconds = seconds;
    if (_isYouTube) {
      _sendYtCommand('seekTo', seconds);
    } else {
      if (_videoElement != null) {
        _videoElement!.currentTime = seconds;
      }
    }
  }

  void setVolume(double volume) {
    final vol = volume.clamp(0.0, 1.0);
    if (_isYouTube) {
      _sendYtCommand('setVolume', (vol * 100).toInt());
    } else {
      _videoElement?.volume = vol;
    }
  }

  void mute() {
    if (_isYouTube) {
      _sendYtCommand('mute');
    } else {
      if (_videoElement != null) _videoElement!.muted = true;
    }
  }

  void unMute() {
    if (_isYouTube) {
      _sendYtCommand('unMute');
    } else {
      if (_videoElement != null) _videoElement!.muted = false;
    }
  }

  void setPlaybackRate(double rate) {
    if (_isYouTube) {
      _sendYtCommand('setPlaybackRate', rate);
    } else {
      if (_videoElement != null) _videoElement!.playbackRate = rate;
    }
  }

  void dispose() {
    _messageSub?.cancel();
    _cleanupVideoSubscriptions();
    _container?.children.clear();
    _iframeElement = null;
    _videoElement = null;
    _container = null;
  }
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(isFullscreen ? 0 : 16),
      child: HtmlElementView(
        key: ValueKey(controller.viewId),
        viewType: controller.viewId,
      ),
    );
  }
}
