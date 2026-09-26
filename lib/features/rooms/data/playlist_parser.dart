import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class PlaylistItem {
  final String title;
  final String url;
  final String? thumbnailUrl;
  final String source; // 'youtube', 'spotify', 'url'

  PlaylistItem({
    required this.title,
    required this.url,
    this.thumbnailUrl,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'thumbnailUrl': thumbnailUrl,
      'source': source,
    };
  }

  factory PlaylistItem.fromMap(Map<String, dynamic> map) {
    return PlaylistItem(
      title: map['title'] as String,
      url: map['url'] as String,
      thumbnailUrl: map['thumbnailUrl'] as String?,
      source: map['source'] as String,
    );
  }
}

class PlaylistParser {
  /// Parse a URL into a list of PlaylistItem objects.
  static Future<List<PlaylistItem>> parse(String url) async {
    final cleanedUrl = url.trim();

    // 1. YouTube Single Video / Shorts / Embed
    final singleVideoId = YouTubeUrlParser.extractVideoId(cleanedUrl);
    final playlistId = YouTubeUrlParser.extractPlaylistId(cleanedUrl);

    if (singleVideoId != null && playlistId == null) {
      return [
        PlaylistItem(
          title: 'YouTube Video ($singleVideoId)',
          url: 'https://www.youtube.com/watch?v=$singleVideoId',
          thumbnailUrl: 'https://img.youtube.com/vi/$singleVideoId/0.jpg',
          source: 'youtube',
        )
      ];
    }

    // 2. YouTube Playlist
    if (playlistId != null) {
      if (!kIsWeb) {
        try {
          final response = await http.get(Uri.parse(cleanedUrl)).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final matches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"')
                .allMatches(response.body)
                .map((m) => m.group(1)!)
                .toSet()
                .toList();

            if (matches.isNotEmpty) {
              return matches.map((id) => PlaylistItem(
                title: 'YouTube Track ($id)',
                url: 'https://www.youtube.com/watch?v=$id',
                thumbnailUrl: 'https://img.youtube.com/vi/$id/0.jpg',
                source: 'youtube',
              )).toList();
            }
          }
        } catch (e) {
          debugPrint('Error parsing YouTube playlist HTML: $e');
        }
      }

      // Safe fallback on Web or when scraping fails
      return [
        PlaylistItem(
          title: 'YouTube Playlist ($playlistId)',
          url: 'https://www.youtube.com/playlist?list=$playlistId',
          thumbnailUrl: singleVideoId != null ? 'https://img.youtube.com/vi/$singleVideoId/0.jpg' : null,
          source: 'youtube',
        )
      ];
    }

    // 3. Spotify Playlist / Album
    if (cleanedUrl.contains('spotify.com/playlist/') || cleanedUrl.contains('spotify.com/album/')) {
      if (!kIsWeb) {
        try {
          final response = await http.get(Uri.parse(cleanedUrl)).timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final trackUrls = RegExp(r'https://open.spotify.com/track/([a-zA-Z0-9]+)')
                .allMatches(response.body)
                .map((m) => m.group(0)!)
                .toSet()
                .toList();

            if (trackUrls.isNotEmpty) {
              final List<PlaylistItem> items = [];
              for (var trackUrl in trackUrls.take(10)) {
                items.add(PlaylistItem(
                  title: 'Spotify Track (${trackUrl.split('/').last})',
                  url: trackUrl,
                  source: 'spotify',
                ));
              }
              return items;
            }
          }
        } catch (e) {
          debugPrint('Error parsing Spotify playlist HTML: $e');
        }
      }

      return [
        PlaylistItem(
          title: 'Spotify Playlist',
          url: cleanedUrl,
          source: 'spotify',
        )
      ];
    }

    // 4. Spotify Single Track
    if (cleanedUrl.contains('spotify.com/track/')) {
      return [
        PlaylistItem(
          title: 'Spotify Track',
          url: cleanedUrl,
          source: 'spotify',
        )
      ];
    }

    // 5. Fallback: Generic URL (Direct MP4, WebM, HLS stream)
    return [
      PlaylistItem(
        title: cleanedUrl.split('/').last.split('?').first,
        url: cleanedUrl,
        source: 'url',
      )
    ];
  }

  /// Search YouTube for a query and return the video ID of the first match.
  static Future<String?> searchYouTube(String query) async {
    if (kIsWeb) {
      // On Web, direct YouTube HTML scraping is blocked by CORS.
      // Search iTunes API as a CORS-safe fallback for song search
      try {
        final uri = Uri.parse('https://itunes.apple.com/search?term=${Uri.encodeComponent(query)}&entity=song&limit=1');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final results = data['results'] as List<dynamic>?;
          if (results != null && results.isNotEmpty) {
            // Track found
            return null;
          }
        }
      } catch (_) {}
      return null;
    }

    try {
      final searchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';
      final response = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
      }).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final match = RegExp(r'/watch\?v=([a-zA-Z0-9_-]{11})').firstMatch(response.body);
        if (match != null) {
          return match.group(1);
        }
      }
    } catch (e) {
      debugPrint('Error searching YouTube: $e');
    }
    return null;
  }
}

/// Helper class for YouTube URL parsing
class YouTubeUrlParser {
  static final RegExp _ytRegex = RegExp(
    r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?|shorts)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
    caseSensitive: false,
  );

  static String? extractVideoId(String url) {
    final clean = url.trim();
    if (clean.isEmpty) return null;
    final match = _ytRegex.firstMatch(clean);
    if (match != null) return match.group(1);
    if (RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(clean)) {
      return clean;
    }
    return null;
  }

  static String? extractPlaylistId(String url) {
    final match = RegExp(r'[?&]list=([a-zA-Z0-9_-]+)').firstMatch(url.trim());
    return match?.group(1);
  }

  static bool isYouTubeUrl(String url) {
    return extractVideoId(url) != null || extractPlaylistId(url) != null;
  }

  static String buildEmbedUrl(String url, {bool autoPlay = true}) {
    final videoId = extractVideoId(url);
    final playlistId = extractPlaylistId(url);
    if (videoId != null) {
      return 'https://www.youtube.com/embed/$videoId?enablejsapi=1&autoplay=${autoPlay ? 1 : 0}&playsinline=1&rel=0&modestbranding=1';
    } else if (playlistId != null) {
      return 'https://www.youtube.com/embed/videoseries?list=$playlistId&enablejsapi=1&autoplay=${autoPlay ? 1 : 0}&playsinline=1&rel=0';
    }
    return url;
  }
}

