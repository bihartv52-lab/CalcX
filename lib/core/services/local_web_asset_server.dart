import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

/// Embedded ultra-fast local HTTP server that serves pre-bundled web assets
/// and dynamically updated bundles from local storage with 0ms network latency.
class LocalWebAssetServer {
  LocalWebAssetServer({this.port = 8080});

  final int port;
  HttpServer? _server;
  Directory? _customBundleDir;
  bool _started = false;

  bool get isRunning => _started && _server != null;

  Future<void> start() async {
    if (_started && _server != null) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _customBundleDir = Directory('${docDir.path}/web_bundle');
      if (!await _customBundleDir!.exists()) {
        await _customBundleDir!.create(recursive: true);
      }
    } catch (e) {
      debugPrint('LocalWebAssetServer directory setup notice: $e');
    }

    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        port,
        shared: true,
      );
      _started = true;
      _server!.listen(_handleRequest, onError: (e) {
        debugPrint('LocalWebAssetServer request error: $e');
      });
      debugPrint('LocalWebAssetServer active on http://127.0.0.1:$port');
    } catch (e) {
      debugPrint('LocalWebAssetServer bind notice: $e');
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      var rawPath = request.uri.path;
      if (rawPath.startsWith('/')) rawPath = rawPath.substring(1);
      if (rawPath.isEmpty || rawPath.endsWith('/')) {
        rawPath += 'index.html';
      }

      final decodedPath = Uri.decodeFull(rawPath);
      Uint8List? body;

      // 1. Check if a newer version of this file was downloaded into local storage
      if (_customBundleDir != null) {
        final localFile = File('${_customBundleDir!.path}/$decodedPath');
        if (await localFile.exists()) {
          try {
            body = await localFile.readAsBytes();
          } catch (_) {}
        }
      }

      // 2. Fall back to pre-downloaded assets bundled inside APK
      if (body == null) {
        try {
          final data = await rootBundle.load('assets/web/$decodedPath');
          body = data.buffer.asUint8List();
        } catch (_) {}
      }

      // 3. SPA fallback: if not found and has no extension, serve index.html
      if (body == null && !decodedPath.contains('.')) {
        if (_customBundleDir != null) {
          final localIndex = File('${_customBundleDir!.path}/index.html');
          if (await localIndex.exists()) {
            try {
              body = await localIndex.readAsBytes();
            } catch (_) {}
          }
        }
        if (body == null) {
          try {
            final data = await rootBundle.load('assets/web/index.html');
            body = data.buffer.asUint8List();
          } catch (_) {}
        }
      }

      if (body == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final mimeType = _resolveMimeType(decodedPath);
      request.response.headers.set(HttpHeaders.contentTypeHeader, mimeType);
      request.response.headers.set('Access-Control-Allow-Origin', '*');
      request.response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
      request.response.headers.set('Access-Control-Allow-Headers', '*');
      request.response.headers.set('Cache-Control', 'no-cache');
      request.response.add(body);
      await request.response.close();
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  static String _resolveMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.html')) return 'text/html; charset=utf-8';
    if (lower.endsWith('.js') || lower.endsWith('.mjs')) return 'application/javascript; charset=utf-8';
    if (lower.endsWith('.wasm')) return 'application/wasm';
    if (lower.endsWith('.json')) return 'application/json; charset=utf-8';
    if (lower.endsWith('.css')) return 'text/css; charset=utf-8';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.ico')) return 'image/x-icon';
    if (lower.endsWith('.otf')) return 'font/otf';
    if (lower.endsWith('.ttf')) return 'font/ttf';
    if (lower.endsWith('.woff')) return 'font/woff';
    if (lower.endsWith('.woff2')) return 'font/woff2';
    return 'application/octet-stream';
  }

  Future<void> close() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    _started = false;
  }
}
