import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Silent background service that checks the live website for updates
/// and downloads updated web bundles into local storage without blocking the UI.
class WebUpdateService {
  WebUpdateService._();

  static const String liveBaseUrl = 'https://calcx-web.vercel.app';
  static bool _isSyncing = false;

  /// Silently checks for website updates and downloads new assets in the background.
  static Future<void> syncUpdatesSilently() async {
    if (kIsWeb || _isSyncing) return;
    _isSyncing = true;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final webDir = Directory('${docDir.path}/web_bundle');
      if (!await webDir.exists()) {
        await webDir.create(recursive: true);
      }

      // 1. Check connectivity & fetch remote build ID with short timeout
      final remoteRes = await http
          .get(Uri.parse('$liveBaseUrl/.last_build_id'))
          .timeout(const Duration(seconds: 4));

      if (remoteRes.statusCode != 200) {
        _isSyncing = false;
        return;
      }

      final remoteBuildId = remoteRes.body.trim();
      if (remoteBuildId.isEmpty) {
        _isSyncing = false;
        return;
      }

      // 2. Read local build ID
      final localIdFile = File('${webDir.path}/.last_build_id');
      String localBuildId = '';
      if (await localIdFile.exists()) {
        localBuildId = (await localIdFile.readAsString()).trim();
      } else {
        try {
          localBuildId = (await rootBundle.loadString('assets/web/.last_build_id')).trim();
        } catch (_) {}
      }

      if (localBuildId.isNotEmpty && localBuildId == remoteBuildId) {
        debugPrint('Web bundle is already up to date ($remoteBuildId)');
        _isSyncing = false;
        return;
      }

      debugPrint('Syncing new web release from website: $remoteBuildId (current: $localBuildId)');

      // 3. Download essential files silently
      final essentialFiles = [
        'main.dart.js',
        'flutter_bootstrap.js',
        'index.html',
        'version.json',
      ];

      for (final relPath in essentialFiles) {
        try {
          final fileRes = await http
              .get(Uri.parse('$liveBaseUrl/$relPath'))
              .timeout(const Duration(seconds: 20));
          if (fileRes.statusCode == 200) {
            final targetFile = File('${webDir.path}/$relPath');
            await targetFile.writeAsBytes(fileRes.bodyBytes);
          }
        } catch (e) {
          debugPrint('Error downloading updated $relPath: $e');
        }
      }

      // 4. Save new build ID to finalize update
      await localIdFile.writeAsString(remoteBuildId);
      debugPrint('Web bundle successfully updated to $remoteBuildId');
    } catch (e) {
      debugPrint('Background web sync completed with notice: $e');
    } finally {
      _isSyncing = false;
    }
  }
}
