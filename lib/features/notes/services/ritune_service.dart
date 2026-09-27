import 'dart:async';
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
    this.audioBytes,
    this.fileName,
    this.durationSeconds = 30,
    this.snippetStartSeconds = 0,
    this.snippetDurationSeconds = 30,
  });

  final String id;
  final String title;
  final String artist;
  final String album;
  final String artwork;
  final String streamUrl;
  final bool isLocal;
  final String? localPath;
  final Uint8List? audioBytes;
  final String? fileName;
  final int durationSeconds;
  final int snippetStartSeconds;
  final int snippetDurationSeconds;

  RiTuneTrack copyWith({
    String? id,
    String? title,
    String? artist,
    String? album,
    String? artwork,
    String? streamUrl,
    bool? isLocal,
    String? localPath,
    Uint8List? audioBytes,
    String? fileName,
    int? durationSeconds,
    int? snippetStartSeconds,
    int? snippetDurationSeconds,
  }) {
    return RiTuneTrack(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      artwork: artwork ?? this.artwork,
      streamUrl: streamUrl ?? this.streamUrl,
      isLocal: isLocal ?? this.isLocal,
      localPath: localPath ?? this.localPath,
      audioBytes: audioBytes ?? this.audioBytes,
      fileName: fileName ?? this.fileName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      snippetStartSeconds: snippetStartSeconds ?? this.snippetStartSeconds,
      snippetDurationSeconds: snippetDurationSeconds ?? this.snippetDurationSeconds,
    );
  }

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
      snippetStartSeconds: 0,
      snippetDurationSeconds: 30,
    );
  }
}

class RiTunePlaybackState {
  const RiTunePlaybackState({
    this.playingTrackId,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  final String? playingTrackId;
  final bool isPlaying;
  final Duration position;
  final Duration duration;

  RiTunePlaybackState copyWith({
    String? playingTrackId,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
  }) {
    return RiTunePlaybackState(
      playingTrackId: playingTrackId ?? this.playingTrackId,
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

class RiTunePlaybackNotifier extends Notifier<RiTunePlaybackState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription? _posSub;
  StreamSubscription? _durSub;
  StreamSubscription? _stateSub;
  int _snippetStartSec = 0;
  int _snippetDurationSec = 30;

  @override
  RiTunePlaybackState build() {
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.completed || s == PlayerState.stopped) {
        state = const RiTunePlaybackState(playingTrackId: null, isPlaying: false);
      }
    });

    _posSub = _player.onPositionChanged.listen((pos) {
      if (state.playingTrackId != null) {
        state = state.copyWith(position: pos);
        // Loop hook only if a specific snippet clip is selected (not full length)
        if (_snippetDurationSec > 0 &&
            _snippetDurationSec < 900 &&
            pos.inSeconds >= (_snippetStartSec + _snippetDurationSec)) {
          seekTo(Duration(seconds: _snippetStartSec));
        }
      }
    });

    _durSub = _player.onDurationChanged.listen((dur) {
      if (state.playingTrackId != null) {
        state = state.copyWith(duration: dur);
      }
    });

    ref.onDispose(() {
      _posSub?.cancel();
      _durSub?.cancel();
      _stateSub?.cancel();
      try {
        _player.dispose();
      } catch (_) {}
    });

    return const RiTunePlaybackState();
  }

  Future<void> togglePlay(RiTuneTrack track, {int? startSeconds, int? durationSeconds, bool isFullLength = false}) async {
    if (state.playingTrackId == track.id && state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
      return;
    }

    _snippetStartSec = startSeconds ?? track.snippetStartSeconds;
    _snippetDurationSec = isFullLength ? 0 : (durationSeconds ?? track.snippetDurationSeconds);

    try {
      await _player.stop();
      final startPos = _snippetStartSec > 0 ? Duration(seconds: _snippetStartSec) : null;
      final isRemoteHttp = track.streamUrl.startsWith('http://') || track.streamUrl.startsWith('https://');

      if (track.isLocal && !isRemoteHttp && track.localPath != null) {
        await _player.play(DeviceFileSource(track.localPath!), position: startPos);
      } else if (track.streamUrl.isNotEmpty) {
        await _player.play(UrlSource(track.streamUrl), position: startPos);
      }
      state = RiTunePlaybackState(
        playingTrackId: track.id,
        isPlaying: true,
        position: startPos ?? Duration.zero,
      );
    } catch (e) {
      debugPrint('Error playing RiTune track: $e');
      state = const RiTunePlaybackState();
    }
  }

  Future<void> playUrl(
    String url,
    String trackId, {
    bool isLocal = false,
    int startSeconds = 0,
    int durationSeconds = 30,
    bool isFullLength = false,
  }) async {
    if (state.playingTrackId == trackId && state.isPlaying) {
      await _player.pause();
      state = state.copyWith(isPlaying: false);
      return;
    }

    _snippetStartSec = startSeconds;
    _snippetDurationSec = isFullLength ? 0 : durationSeconds;

    try {
      await _player.stop();
      final startPos = startSeconds > 0 ? Duration(seconds: startSeconds) : null;
      final isRemoteHttp = url.startsWith('http://') || url.startsWith('https://');

      if (isLocal && !isRemoteHttp) {
        await _player.play(DeviceFileSource(url), position: startPos);
      } else {
        await _player.play(UrlSource(url), position: startPos);
      }
      state = RiTunePlaybackState(
        playingTrackId: trackId,
        isPlaying: true,
        position: startPos ?? Duration.zero,
      );
    } catch (e) {
      debugPrint('Error playing url: $e');
      state = const RiTunePlaybackState();
    }
  }

  Future<void> seekTo(Duration position) async {
    try {
      await _player.seek(position);
      state = state.copyWith(position: position);
    } catch (e) {
      debugPrint('Error seeking: $e');
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

  static const String rituneWebUrl = 'https://t105d86n98z1-d.space-z.ai';

  /// Searches iTunes official catalog prioritizing Indian music (&country=IN)
  static Future<List<RiTuneTrack>> search(String query) async {
    if (query.trim().isEmpty) return getTrendingHits();
    try {
      final clean = Uri.encodeComponent(query.trim());
      // Explicitly queries Indian store catalog with high relevance
      final res = await http
          .get(Uri.parse('https://itunes.apple.com/search?term=$clean&entity=song&limit=30&country=IN'))
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final results = data['results'] as List<dynamic>? ?? [];
        final parsed = results
            .whereType<Map<String, dynamic>>()
            .where((item) => (item['previewUrl']?.toString() ?? '').isNotEmpty)
            .map(RiTuneTrack.fromItunes)
            .toList();
        if (parsed.isNotEmpty) return parsed;
      }
    } catch (e) {
      debugPrint('RiTune search notice: $e');
    }

    // Fallback filter from curated Indian catalog
    final lower = query.toLowerCase();
    return getTrendingHits().where((t) {
      return t.title.toLowerCase().contains(lower) || t.artist.toLowerCase().contains(lower);
    }).toList();
  }

  /// Curated trending Indian & Bollywood hits matching RiTune Web
  static List<RiTuneTrack> getTrendingHits() {
    return const [
      RiTuneTrack(
        id: 'ritune_1',
        title: 'Saiyaara',
        artist: 'Faheem Abdullah • Arslan Nizami',
        album: 'Saiyaara',
        artwork: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/a4/43/84/a44384e5-94df-d8dc-28d1-7299ba423403/mzaf_10793740921008061732.plus.aac.p.m4a',
        snippetStartSeconds: 10,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_2',
        title: 'Dhun (Arijit Singh)',
        artist: 'Arijit Singh • Mithoon',
        album: 'Saiyaara',
        artwork: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/bd/10/7c/bd107c87-84bc-2a5b-d4c3-e28e67e3a985/mzaf_17730310232598379417.plus.aac.p.m4a',
        snippetStartSeconds: 15,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_3',
        title: 'Tauba Tauba',
        artist: 'Karan Aujla',
        album: 'Bad Newz',
        artwork: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/7c/49/1b/7c491b9f-0925-c9c0-6d4b-7fe8184f4dc5/mzaf_10287950943806938363.plus.aac.p.m4a',
        snippetStartSeconds: 5,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_4',
        title: 'Millionaire',
        artist: 'Yo Yo Honey Singh',
        album: 'Glory',
        artwork: 'https://images.unsplash.com/photo-1518609878373-06d740f60d8b?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/7e/39/1d/7e391df7-a9a3-5c8e-a4be-b33783a3f5a1/mzaf_7162985176742581692.plus.aac.p.m4a',
        snippetStartSeconds: 8,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_5',
        title: 'Sahiba',
        artist: 'Aditya Rikhari',
        album: 'Indie Hits',
        artwork: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/a4/43/84/a44384e5-94df-d8dc-28d1-7299ba423403/mzaf_10793740921008061732.plus.aac.p.m4a',
        snippetStartSeconds: 12,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_6',
        title: 'Finding Her',
        artist: 'kushagra • Showkidd',
        album: 'Pop Hits',
        artwork: 'https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview125/v4/44/e9/87/44e98717-36e7-1755-6672-00109c0ca827/mzaf_4734360341764354224.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_7',
        title: 'Jhol',
        artist: 'Maanu • Annural Khalid',
        album: 'Jhol',
        artwork: 'https://images.unsplash.com/photo-1487180144351-b8472da7d491?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview115/v4/ec/3b/b9/ec3bb970-d29a-245f-c967-df427e02e3dc/mzaf_13840742118359567924.plus.aac.p.m4a',
        snippetStartSeconds: 10,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_8',
        title: 'Ishq',
        artist: 'Faheem Abdullah • Rauhan Malik',
        album: 'Lost;Found',
        artwork: 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/bd/10/7c/bd107c87-84bc-2a5b-d4c3-e28e67e3a985/mzaf_17730310232598379417.plus.aac.p.m4a',
        snippetStartSeconds: 15,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_9',
        title: 'Winning Speech',
        artist: 'Karan Aujla',
        album: 'Four Me',
        artwork: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview116/v4/7c/49/1b/7c491b9f-0925-c9c0-6d4b-7fe8184f4dc5/mzaf_10287950943806938363.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'ritune_10',
        title: 'Apna Bana Le',
        artist: 'Arijit Singh • Sachin-Jigar',
        album: 'Bhediya',
        artwork: 'https://images.unsplash.com/photo-1514525253161-7a46d19cd819?w=500&auto=format&fit=crop&q=80',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview126/v4/bd/10/7c/bd107c87-84bc-2a5b-d4c3-e28e67e3a985/mzaf_17730310232598379417.plus.aac.p.m4a',
        snippetStartSeconds: 15,
        snippetDurationSeconds: 30,
      ),
    ];
  }

  /// Picks a local audio file from the user's device (MP3, M4A, WAV, AAC)
  static Future<RiTuneTrack?> pickLocalSong() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: kIsWeb,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        String streamUrl = file.path ?? '';

        if (kIsWeb && file.bytes != null) {
          final ext = file.name.split('.').last.toLowerCase();
          final mime = ext == 'wav' ? 'audio/wav' : (ext == 'm4a' || ext == 'aac' ? 'audio/aac' : 'audio/mpeg');
          streamUrl = Uri.dataFromBytes(file.bytes!, mimeType: mime).toString();
        }

        return RiTuneTrack(
          id: 'local_${DateTime.now().millisecondsSinceEpoch}',
          title: name.isNotEmpty ? name : 'My Audio Note',
          artist: 'Local Track',
          album: 'Device Music',
          artwork: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=500&auto=format&fit=crop&q=80',
          streamUrl: streamUrl,
          isLocal: true,
          localPath: file.path,
          audioBytes: file.bytes,
          fileName: file.name,
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
