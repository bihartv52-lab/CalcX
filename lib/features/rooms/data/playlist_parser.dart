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

    // 1. YouTube Playlist
    // e.g. https://www.youtube.com/playlist?list=PL...
    if (cleanedUrl.contains('youtube.com/playlist') || cleanedUrl.contains('&list=')) {
      final listId = RegExp(r'[&?]list=([^&]+)').firstMatch(cleanedUrl)?.group(1);
      if (listId != null) {
        try {
          final response = await http.get(Uri.parse(cleanedUrl));
          if (response.statusCode == 200) {
            // Find all matching videoId patterns: "videoId":"[a-zA-Z0-9_-]{11}"
            final matches = RegExp(r'"videoId":"([a-zA-Z0-9_-]{11})"')
                .allMatches(response.body)
                .map((m) => m.group(1)!)
                .toSet() // remove duplicates
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
    }

    // 2. YouTube Single Video
    if (cleanedUrl.contains('youtube.com/watch') || cleanedUrl.contains('youtu.be/')) {
      final videoId = RegExp(r'(?:v=|\/)([a-zA-Z0-9_-]{11})').firstMatch(cleanedUrl)?.group(1);
      if (videoId != null) {
        return [
          PlaylistItem(
            title: 'YouTube Video ($videoId)',
            url: cleanedUrl,
            thumbnailUrl: 'https://img.youtube.com/vi/$videoId/0.jpg',
            source: 'youtube',
          )
        ];
      }
    }

    // 3. Spotify Playlist / Album
    if (cleanedUrl.contains('spotify.com/playlist/') || cleanedUrl.contains('spotify.com/album/')) {
      try {
        final response = await http.get(Uri.parse(cleanedUrl));
        if (response.statusCode == 200) {
          // Parse all tracks using og:description or matching spotify tracks
          final trackUrls = RegExp(r'https://open.spotify.com/track/([a-zA-Z0-9]+)')
              .allMatches(response.body)
              .map((m) => m.group(0)!)
              .toSet()
              .toList();

          if (trackUrls.isNotEmpty) {
            final List<PlaylistItem> items = [];
            // Retrieve oEmbed details for the first 10 tracks to avoid throttling
            for (var trackUrl in trackUrls.take(10)) {
              try {
                final oembedResponse = await http.get(
                  Uri.parse('https://open.spotify.com/oembed?url=$trackUrl')
                ).timeout(const Duration(seconds: 3));
                
                if (oembedResponse.statusCode == 200) {
                  final data = json.decode(oembedResponse.body);
                  items.add(PlaylistItem(
                    title: data['title'] ?? 'Spotify Track',
                    url: trackUrl,
                    thumbnailUrl: data['thumbnail_url'],
                    source: 'spotify',
                  ));
                } else {
                  items.add(PlaylistItem(
                    title: 'Spotify Track (${trackUrl.split('/').last})',
                    url: trackUrl,
                    source: 'spotify',
                  ));
                }
              } catch (_) {
                items.add(PlaylistItem(
                  title: 'Spotify Track (${trackUrl.split('/').last})',
                  url: trackUrl,
                  source: 'spotify',
                ));
              }
            }
            return items;
          }
        }
      } catch (e) {
        debugPrint('Error parsing Spotify playlist HTML: $e');
      }
    }

    // 4. Spotify Single Track
    if (cleanedUrl.contains('spotify.com/track/')) {
      try {
        final oembedResponse = await http.get(
          Uri.parse('https://open.spotify.com/oembed?url=$cleanedUrl')
        );
        if (oembedResponse.statusCode == 200) {
          final data = json.decode(oembedResponse.body);
          return [
            PlaylistItem(
              title: data['title'] ?? 'Spotify Track',
              url: cleanedUrl,
              thumbnailUrl: data['thumbnail_url'],
              source: 'spotify',
            )
          ];
        }
      } catch (_) {}
      return [
        PlaylistItem(
          title: 'Spotify Track',
          url: cleanedUrl,
          source: 'spotify',
        )
      ];
    }

    // 5. Fallback: Generic URL
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
    try {
      final searchUrl = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';
      final response = await http.get(Uri.parse(searchUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/100.0.0.0 Safari/537.36',
      });
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
