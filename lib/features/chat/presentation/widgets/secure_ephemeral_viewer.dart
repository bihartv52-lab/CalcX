import 'package:better_player_plus/better_player_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:calcx/core/services/security_service.dart';
import 'package:flutter/material.dart';

class SecureEphemeralViewer extends StatefulWidget {
  final String mediaUrl;
  final bool isVideo;
  final int maxViews;
  final int remainingViews;

  const SecureEphemeralViewer({
    super.key,
    required this.mediaUrl,
    required this.isVideo,
    required this.maxViews,
    required this.remainingViews,
  });

  @override
  State<SecureEphemeralViewer> createState() => _SecureEphemeralViewerState();
}

class _SecureEphemeralViewerState extends State<SecureEphemeralViewer> {
  BetterPlayerController? _betterPlayerController;

  @override
  void initState() {
    super.initState();
    SecurityService.enableSecure();

    if (widget.isVideo) {
      const betterPlayerConfiguration = BetterPlayerConfiguration(
        aspectRatio: 16 / 9,
        fit: BoxFit.contain,
        autoPlay: true,
        looping: false,
        controlsConfiguration: BetterPlayerControlsConfiguration(
          showControls: true,
          enableFullscreen: false,
          enablePip: false,
          enablePlayPause: true,
          enableMute: true,
          enableProgressBar: true,
          enableProgressBarDrag: true,
        ),
      );
      final dataSource = BetterPlayerDataSource(
        BetterPlayerDataSourceType.network,
        widget.mediaUrl,
      );
      _betterPlayerController = BetterPlayerController(betterPlayerConfiguration);
      _betterPlayerController!.setupDataSource(dataSource);
    }
  }

  @override
  void dispose() {
    _betterPlayerController?.dispose();
    SecurityService.disableSecure();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewLabel = widget.maxViews == 1 ? '1x View Once' : '2x View Twice';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blueAccent, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      '',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  viewLabel,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 2),
            const Text(
              'Screenshots and downloads blocked',
              style: TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Center(
            child: widget.isVideo
                ? AspectRatio(
                    aspectRatio: 16 / 9,
                    child: BetterPlayer(controller: _betterPlayerController!),
                  )
                : InteractiveViewer(
                    clipBehavior: Clip.none,
                    minScale: 0.8,
                    maxScale: 3.0,
                    child: CachedNetworkImage(
                      imageUrl: widget.mediaUrl,
                      fit: BoxFit.contain,
                      progressIndicatorBuilder: (context, url, downloadProgress) {
                        final percent = downloadProgress.progress != null
                            ? (downloadProgress.progress! * 100).toInt()
                            : null;
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: CircularProgressIndicator(
                                  value: downloadProgress.progress,
                                  strokeWidth: 2.5,
                                  color: const Color(0xFF3897F0),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                percent != null
                                    ? 'Downloading protected media %'
                                    : 'Downloading protected media...',
                                style: const TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                      errorWidget: (context, error, stackTrace) => const Center(
                        child: Icon(Icons.broken_image_rounded, color: Colors.white70, size: 48),
                      ),
                    ),
                  ),
          ),
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.75),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shield_rounded, color: Color(0xFF10B981), size: 16),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Screenshot protection active • Cannot be saved or forwarded',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
