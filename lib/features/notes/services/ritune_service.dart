import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

@immutable
class RiTuneTrack {
  const RiTuneTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.album = '',
    required this.artwork,
    required this.streamUrl,
    this.isLocal = false,
    this.localPath,
    this.durationSeconds = 30,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artwork;
  final String streamUrl;
  final bool isLocal;
  final String? localPath;
  final int durationSeconds;

  factory RiTuneTrack.fromItunes(Map<String, dynamic> item) {
    final rawArtwork = item['artworkUrl100']?.toString() ?? '';
    final highResArtwork = rawArtwork.isNotEmpty
        ? rawArtwork.replaceAll('100x100bb', '600x600bb')
        : 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80';

    return RiTuneTrack(
      id: 'itunes_${item['trackId']}',
      title: item['trackName']?.toString() ?? 'Unknown Track',
      artist: item['artistName']?.toString() ?? 'Unknown Artist',
      album: item['collectionName']?.toString() ?? 'Single',
      artwork: highResArtwork,
      streamUrl: item['previewUrl']?.toString() ?? '',
      isLocal: false,
      durationSeconds: ((item['trackTimeMillis'] as num?)?.toInt() ?? 30000) ~/ 1000,
    );
  }
}

class RiTunePlaybackState {
  const RiTunePlaybackState({
    this.playingTrackId,
    this.isPlaying = false,
  });

  final String? playingTrackId;
  final bool isPlaying;
}

class RiTunePlaybackNotifier extends Notifier<RiTunePlaybackState> {
  final AudioPlayer _player = AudioPlayer();

  @override
  RiTunePlaybackState build() {
    _player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.completed || s == PlayerState.stopped) {
        state = const RiTunePlaybackState(playingTrackId: null, isPlaying: false);
      }
    });

    ref.onDispose(() {
      try {
        _player.dispose();
      } catch (_) {}
    });

    return const RiTunePlaybackState();
  }

  Future<void> togglePlay(RiTuneTrack track) async {
    if (state.playingTrackId == track.id && state.isPlaying) {
      await _player.pause();
      state = RiTunePlaybackState(playingTrackId: track.id, isPlaying: false);
      return;
    }

    try {
      await _player.stop();
      if (track.isLocal && track.localPath != null) {
        await _player.play(DeviceFileSource(track.localPath!));
      } else if (track.streamUrl.isNotEmpty) {
        await _player.play(UrlSource(track.streamUrl));
      }
      state = RiTunePlaybackState(playingTrackId: track.id, isPlaying: true);
    } catch (e) {
      debugPrint('Error playing RiTune track: $e');
      state = const RiTunePlaybackState();
    }
  }

  Future<void> playUrl(String url, String trackId, {bool isLocal = false}) async {
    if (state.playingTrackId == trackId && state.isPlaying) {
      await _player.pause();
      state = RiTunePlaybackState(playingTrackId: trackId, isPlaying: false);
      return;
    }

    try {
      await _player.stop();
      if (isLocal) {
        await _player.play(DeviceFileSource(url));
      } else {
        await _player.play(UrlSource(url));
      }
      state = RiTunePlaybackState(playingTrackId: trackId, isPlaying: true);
    } catch (e) {
      debugPrint('Error playing url: $e');
      state = const RiTunePlaybackState();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
    state = const RiTunePlaybackState();
  }
}

final ritunePlaybackProvider =
    NotifierProvider<RiTunePlaybackNotifier, RiTunePlaybackState>(RiTunePlaybackNotifier.new);

class RiTuneService {
  RiTuneService._();

  static const String rituneWebUrl = 'https://calcx-web.vercel.app';

  /// Searches iTunes official catalog with zero CORS errors and high-quality 30s previews
  static Future<List<RiTuneTrack>> search(String query) async {
    if (query.trim().isEmpty) return getTrendingHits();
    try {
      final clean = Uri.encodeComponent(query.trim());
      final res = await http
          .get(Uri.parse('https://itunes.apple.com/search?term=$clean&entity=song&limit=25'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        return results
            .whereType<Map<String, dynamic>>()
            .where((item) => (item['previewUrl']?.toString() ?? '').isNotEmpty)
            .map(RiTuneTrack.fromItunes)
            .toList();
      }
    } catch (e) {
      debugPrint('RiTune search notice: $e');
    }

    // Fallback filter from curated catalog
    final lower = query.toLowerCase();
    return getTrendingHits().where((t) {
      return t.title.toLowerCase().contains(lower) || t.artist.toLowerCase().contains(lower);
    }).toList();
  }

  /// Curated trending hits matching RiTune Web & APK
  static List<RiTuneTrack> getTrendingHits() {
    return const [
      RiTuneTrack(
        id: 'hit_1',
        title: 'Teri Yaad',
        artist: 'Aditya Rikhari',
        album: 'Indie Hits',
        artwork: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/a4/43/84/a44384e5-94df-d8dc-28d1-7299ba423403/mzaf_10793740921008061732.plus.aac.p.m4a',
      ),
      RiTuneTrack(
        id: 'hit_2',
        title: 'Ja Ve (feat. Yuvraj Tung)',
        artist: 'Zeeshan Ali',
        album: 'Acoustic Soul',
        artwork: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/bd/10/7c/bd107c87-84bc-2a5b-d4c3-e28e67e3a985/mzaf_17730310232598379417.plus.aac.p.m4a',
      ),
      RiTuneTrack(
        id: 'hit_3',
        title: 'Starboy',
        artist: 'The Weeknd, Daft Punk',
        album: 'Starboy',
        artwork: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/44/e9/87/44e98717-36e7-1755-6672-00109c0ca827/mzaf_4734360341764354224.plus.aac.p.m4a',
      ),
      RiTuneTrack(
        id: 'hit_4',
        title: 'Midnight City',
        artist: 'M83',
        album: 'Hurry Up, We\'re Dreaming',
        artwork: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/ec/3b/b9/ec3bb970-d29a-245f-c967-df427e02e3dc/mzaf_13840742118359567924.plus.aac.p.m4a',
      ),
      RiTuneTrack(
        id: 'hit_5',
        title: 'Counting Stars',
        artist: 'OneRepublic',
        album: 'Native',
        artwork: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/7e/39/1d/7e391df7-a9a3-5c8e-a4be-b33783a3f5a1/mzaf_7162985176742581692.plus.aac.p.m4a',
      ),
      RiTuneTrack(
        id: 'hit_6',
        title: 'Lo-Fi Chill Beats',
        artist: 'RiTune Beats',
        album: 'Lo-Fi Sessions',
        artwork: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/7c/49/1b/7c491b9f-0925-c9c0-6d4b-7fe8184f4dc5/mzaf_10287950943806938363.plus.aac.p.m4a',
      ),
    ];
  }

  /// Picks a local audio file from the user's device (MP3, M4A, WAV, AAC)
  static Future<RiTuneTrack?> pickLocalSong() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        final path = file.path;

        return RiTuneTrack(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          title: name.isNotEmpty ? name : 'My Audio Note',
          artist: 'Local Track',
          album: 'Device Music',
          artwork: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
          streamUrl: path ?? '',
          isLocal: true,
          localPath: path,
        );
      }
    } catch (e) {
      debugPrint('Error picking local song: $e');
    }
    return null;
  }

  /// Launch external RiTune web streaming website
  static Future<void> launchRiTuneWeb() async {
    try {
      final uri = Uri.parse(rituneWebUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Could not launch RiTune web: $e');
    }
  }
}
