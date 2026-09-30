import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
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
        id: 'itunes_1754562159',
        title: 'Tauba Tauba (Bad Newz)',
        artist: 'Karan Aujla',
        album: 'Bad Newz',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/79/d2/01/79d201d2-e54d-5604-81fb-313f30db7219/198588533581.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/34/8d/63/348d6342-2c35-bf31-8131-2c8b3cfe3c09/mzaf_15374551219149804677.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_6814373102',
        title: 'Apna Bana Le',
        artist: 'Arijit Singh & Sachin-Jigar',
        album: 'Bhediya',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/b8/60/43/b8604350-ec89-b4e0-4393-9fb2c7a6f374/8909024122724.png/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/6c/70/72/6c707283-b39b-db60-9d93-4d8e0a50f501/mzaf_3454343074094843569.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1720723962',
        title: 'O Maahi (Dunki)',
        artist: 'Pritam & Arijit Singh',
        album: 'Dunki',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/9e/fb/28/9efb2892-c3b1-0c1c-f7a3-3bcccce6346e/8903431975058_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/7a/ae/fd/7aaefd06-7082-9f9e-e0b4-6cc37bdbf3e0/mzaf_13695558322503852976.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1730725583',
        title: 'Sajni',
        artist: 'Arijit Singh & Ram Sampath',
        album: 'Laapataa Ladies',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/48/d8/bf/48d8bf8f-df58-e05f-62e2-bc494d748ea4/8902894362252_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/0e/5f/a4/0e5fa4f9-c67b-31f1-1d1e-4c3e0f86e233/mzaf_15112412104812626230.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1698183046',
        title: 'Ve Kamleya',
        artist: 'Arijit Singh & Shreya Ghoshal',
        album: 'Rocky Aur Rani Kii Prem Kahaani',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/f0/75/ba/f075baf5-de5c-5c1b-8ad9-2eab666d1ea6/197189415388.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/30/af/79/30af790f-5576-5307-e436-29e949ae6388/mzaf_3370475763365409547.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1728798022',
        title: 'Tum Se',
        artist: 'Sachin-Jigar & Varun Jain',
        album: 'Teri Baaton Mein Aisa Uljha Jiya',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/eb/25/68/eb256897-d444-504e-b64f-977206d3bf40/8903431982186_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/fd/07/e9/fd07e9df-b3eb-5c4e-0571-d1eefb33635c/mzaf_15156398510483609553.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1718278234',
        title: 'Pehle Bhi Main',
        artist: 'Vishal Mishra & Raj Shekhar',
        album: 'ANIMAL',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/db/ad/5e/dbad5e8b-0bee-d962-92d4-021c90e375ac/8902894362092_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/3a/d8/43/3ad8432d-c2e6-052b-5679-cc01c6a599ea/mzaf_7941667053086496020.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1702461667',
        title: 'Chaleya',
        artist: 'Anirudh Ravichander, Arijit Singh & Shilpa Rao',
        album: 'Jawan',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/1e/ff/32/1eff3216-190d-6fd9-8f68-acbba846e6ee/8903431956026_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/55/fb/9c/55fb9c31-320a-5dba-0a3f-5e69552085a7/mzaf_13508224660474474886.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1635014240',
        title: 'Kesariya',
        artist: 'Pritam & Arijit Singh',
        album: 'Brahmāstra',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/9f/13/ca/9f13ca3b-e533-03e0-f19a-f0aaa774581d/196589311191.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/38/4c/5c/384c5c8f-3ff8-e457-b2f7-3158ce108649/mzaf_12389299033886433185.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1690466656',
        title: 'Heeriye',
        artist: 'Jasleen Royal & Arijit Singh',
        album: 'Heeriye',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music116/v4/f0/8c/2a/f08c2aeb-3903-8738-d0a5-8c2e4547eed7/5054197711039.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/14/9b/ac/149bac62-12f1-2f55-a742-f38429b94c83/mzaf_17225240189976438593.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1745062759',
        title: 'Winning Speech',
        artist: 'Karan Aujla & MXRCI',
        album: 'Winning Speech',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/48/7c/36/487c3668-f7a4-4b1a-e09e-c74dae124dd9/5063483578089_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/e3/ae/b6/e3aeb64f-cadd-5830-c39f-6af51cd91670/mzaf_6001527501800958065.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1649039974',
        title: 'Maan Meri Jaan',
        artist: 'King',
        album: 'Champagne Talk',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music112/v4/90/9d/aa/909daa9a-3a47-9314-2855-39f5a157f1e3/5054197407734.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview221/v4/49/c8/c0/49c8c0eb-6a72-d639-02d2-d55fa0034b89/mzaf_6556689839136809010.plus.aac.p.m4a',
        snippetStartSeconds: 0,
        snippetDurationSeconds: 30,
      ),
      RiTuneTrack(
        id: 'itunes_1669177015',
        title: 'Tere Pyaar Mein',
        artist: 'Pritam, Arijit Singh & Nikhita Gandhi',
        album: 'Tu Jhoothi Main Makkaar',
        artwork: 'https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/f9/81/d9/f981d94a-6ddd-c80a-48a1-1e9f557d63a9/8903431925367_cover.jpg/600x600bb.jpg',
        streamUrl: 'https://audio-ssl.itunes.apple.com/itunes-assets/AudioPreview211/v4/18/4a/ca/184acaec-6769-c3ca-f65b-ecfe4e714fa5/mzaf_17308460714309480289.plus.aac.p.m4a',
        snippetStartSeconds: 0,
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
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final name = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
        String streamUrl = file.path ?? '';
        Uint8List? bytes = file.bytes;

        if (bytes == null && !kIsWeb && file.path != null && file.path!.isNotEmpty) {
          try {
            final f = io.File(file.path!);
            if (await f.exists()) {
              bytes = await f.readAsBytes();
            }
          } catch (readErr) {
            debugPrint('Notice reading local audio file bytes: $readErr');
          }
        }

        if (kIsWeb && bytes != null) {
          final ext = file.name.split('.').last.toLowerCase();
          final mime = ext == 'wav' ? 'audio/wav' : (ext == 'm4a' || ext == 'aac' ? 'audio/aac' : 'audio/mpeg');
          streamUrl = Uri.dataFromBytes(bytes, mimeType: mime).toString();
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
          audioBytes: bytes,
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
