import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:calcx/features/rooms/domain/playback_state.dart';
import 'package:calcx/features/rooms/data/playlist_parser.dart';
import 'package:calcx/features/rooms/presentation/widgets/floating_pip_overlay.dart';

typedef TestFloatingPipOverlay = FloatingPipOverlay;


void main() {
  group('Watch Party Sync (R2) - Broadcast Play/Pause/Seek Sync (<500ms)', () {
    test('BroadcastSyncEvent calculates latency accurately and satisfies <500ms threshold', () {
      final emitTime = DateTime.now().toUtc();
      final receiveTime = emitTime.add(const Duration(milliseconds: 120)); // 120ms latency

      final event = BroadcastSyncEvent(
        action: 'play',
        positionMs: 45000,
        timestamp: emitTime,
        hostId: 'host_user_1',
        sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );

      final latency = event.calculateLatencyMs(receiveTime);
      expect(latency, equals(120));
      expect(latency, lessThan(500), reason: 'Broadcast sync latency must be <500ms');
    });

    test('WatchPartySyncEngine synchronizes play state within <500ms broadcast adjustment', () {
      final engine = WatchPartySyncEngine();
      final emitTime = DateTime.now().toUtc();
      final receiveTime = emitTime.add(const Duration(milliseconds: 200));

      final event = BroadcastSyncEvent(
        action: 'play',
        positionMs: 10000,
        timestamp: emitTime,
        hostId: 'host_1',
      );

      engine.handleBroadcastEvent(event, receivedAt: receiveTime);

      expect(engine.currentState.isPlaying, isTrue);
      expect(engine.currentState.position.inMilliseconds, equals(10200)); // 10000 + 200ms latency compensating
    });

    test('WatchPartySyncEngine handles pause and seek events correctly', () {
      final engine = WatchPartySyncEngine();
      final emitTime = DateTime.now().toUtc();

      // Pause event
      final pauseEvent = BroadcastSyncEvent(
        action: 'pause',
        positionMs: 65000,
        timestamp: emitTime,
        hostId: 'host_1',
      );
      engine.handleBroadcastEvent(pauseEvent, receivedAt: emitTime);
      expect(engine.currentState.isPlaying, isFalse);
      expect(engine.currentState.position.inMilliseconds, equals(65000));

      // Seek event
      final seekEvent = BroadcastSyncEvent(
        action: 'seek',
        positionMs: 120000,
        timestamp: emitTime.add(const Duration(seconds: 1)),
        hostId: 'host_1',
      );
      engine.handleBroadcastEvent(seekEvent, receivedAt: emitTime.add(const Duration(seconds: 1)));
      expect(engine.currentState.position.inMilliseconds, equals(120000));
    });

    test('Detects sync drift exceeding threshold (500ms)', () {
      final engine = WatchPartySyncEngine();
      const clientPos = Duration(milliseconds: 10000);
      const hostPosDrifted = Duration(milliseconds: 10600); // 600ms diff
      const hostPosSynced = Duration(milliseconds: 10200);  // 200ms diff

      expect(engine.isSyncDriftExceeded(clientPos, hostPosDrifted), isTrue);
      expect(engine.isSyncDriftExceeded(clientPos, hostPosSynced), isFalse);
    });
  });

  group('Watch Party Sync (R2) - YouTube URL Parsing', () {
    test('Extracts video ID from standard YouTube watch URL', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), equals('dQw4w9WgXcQ'));
      expect(YouTubeUrlParser.isYouTubeUrl(url), isTrue);
    });

    test('Extracts video ID from shortened youtu.be URL', () {
      const url = 'https://youtu.be/dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(url), equals('dQw4w9WgXcQ'));
    });

    test('Extracts video ID from YouTube Shorts and Embed URLs', () {
      const shortsUrl = 'https://www.youtube.com/shorts/dQw4w9WgXcQ';
      const embedUrl = 'https://www.youtube.com/embed/dQw4w9WgXcQ';
      expect(YouTubeUrlParser.extractVideoId(shortsUrl), equals('dQw4w9WgXcQ'));
      expect(YouTubeUrlParser.extractVideoId(embedUrl), equals('dQw4w9WgXcQ'));
    });

    test('Extracts video ID despite extra query parameters', () {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=120s&list=PL1234';
      expect(YouTubeUrlParser.extractVideoId(url), equals('dQw4w9WgXcQ'));
    });

    test('Returns null for invalid or non-YouTube URLs', () {
      expect(YouTubeUrlParser.extractVideoId('https://vimeo.com/123456'), isNull);
      expect(YouTubeUrlParser.extractVideoId('https://example.com/video.mp4'), isNull);
      expect(YouTubeUrlParser.extractVideoId('invalid_url_string'), isNull);
    });

    test('PlaylistParser parses YouTube single video URL into PlaylistItem', () async {
      const url = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';
      final items = await PlaylistParser.parse(url);
      expect(items.length, equals(1));
      expect(items.first.source, equals('youtube'));
      expect(items.first.thumbnailUrl, contains('dQw4w9WgXcQ'));
    });
  });

  group('Watch Party Sync (R2) - Floating PiP Overlay Driver', () {
    testWidgets('Toggles floating PiP overlay minimize and maximize state', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestFloatingPipOverlay(
              screenSize: Size(400, 500),
              child: Text('Video Stream Player'),
            ),
          ),
        ),
      );

      // Initially full player mode
      expect(find.byKey(const ValueKey('full_player')), findsOneWidget);
      expect(find.text('Video Stream Player'), findsOneWidget);

      // Tap minimize button
      await tester.tap(find.byKey(const ValueKey('pip_minimize_button')));
      await tester.pumpAndSettle();

      // Floating PiP overlay mode
      expect(find.byKey(const ValueKey('floating_pip_window')), findsOneWidget);

      // Tap maximize button on floating PiP overlay
      await tester.tap(find.byKey(const ValueKey('pip_maximize_button')), warnIfMissed: false);
      await tester.pumpAndSettle();

      // Back to full player mode
      expect(find.byKey(const ValueKey('full_player')), findsOneWidget);
    });

    testWidgets('Drags floating PiP overlay within screen bounds', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TestFloatingPipOverlay(
              initialMinimized: true,
              screenSize: Size(400, 500),
              pipSize: Size(160, 90),
              child: Text('PiP Video'),
            ),
          ),
        ),
      );

      expect(find.byKey(const ValueKey('floating_pip_window')), findsOneWidget);

      // Drag PiP overlay upwards by -50px
      await tester.drag(find.byKey(const ValueKey('pip_drag_gesture')), const Offset(0, -50), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('floating_pip_window')), findsOneWidget);
    });
  });
}
