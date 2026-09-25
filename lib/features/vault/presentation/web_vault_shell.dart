import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'package:calcx/app/app_router.dart';
import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/services/local_web_asset_server.dart';
import 'package:calcx/core/services/notification_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/services/web_update_service.dart';
import 'package:calcx/core/widgets/quick_panic_calculator_button.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';

class WebVaultShell extends ConsumerStatefulWidget {
  const WebVaultShell({super.key, this.initialRoute});

  final String? initialRoute;

  static const String baseUrl = 'http://localhost:8080/';

  static String buildUrl(String? route) {
    if (route != null && route.isNotEmpty) {
      final cleanRoute = route.startsWith('/') ? route : '/$route';
      return '$baseUrl#$cleanRoute?unlocked=true';
    }
    return '$baseUrl?unlocked=true';
  }

  @override
  ConsumerState<WebVaultShell> createState() => _WebVaultShellState();
}

class _WebVaultShellState extends ConsumerState<WebVaultShell> {
  final LocalWebAssetServer _localServer = LocalWebAssetServer(port: 8080);
  InAppWebViewController? _webViewController;
  late String _targetUrl;
  bool _isServerReady = false;
  bool _isPageLoading = true;

  @override
  void initState() {
    super.initState();
    _targetUrl = WebVaultShell.buildUrl(widget.initialRoute);
    _initApp();
  }

  @override
  void dispose() {
    try {
      _localServer.close();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initApp() async {
    // 1. Start local asset server serving pre-downloaded local bundle
    await _localServer.start();
    if (mounted) {
      setState(() {
        _isServerReady = true;
      });
    }

    // 2. Request native notification permissions on Android 13+
    if (!kIsWeb) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }

    // 3. Listen for push notifications while web vault is active
    if (!kIsWeb) {
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final senderId = message.data['sender_id'] as String?;
        final roomId = message.data['room_id'] as String?;
        String? targetRoute;
        if (senderId != null && senderId.isNotEmpty) {
          targetRoute = '/chat/$senderId';
        } else if (roomId != null && roomId.isNotEmpty) {
          targetRoute = '/room/$roomId/chat';
        }
        if (targetRoute != null && _webViewController != null) {
          final targetUrl = WebVaultShell.buildUrl(targetRoute);
          _webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
        }
      });
    }

    // 4. Silently check for website updates in the background (0ms impact on UI)
    unawaited(WebUpdateService.syncUpdatesSilently());
  }

  String? _extractUserId(dynamic obj) {
    if (obj == null) return null;
    if (obj is String) {
      try {
        return _extractUserId(jsonDecode(obj));
      } catch (_) {
        return null;
      }
    }
    if (obj is Map) {
      if (obj['user_id'] is String && (obj['user_id'] as String).isNotEmpty) {
        return obj['user_id'] as String;
      }
      if (obj['id'] is String && obj['email'] != null && (obj['id'] as String).isNotEmpty) {
        return obj['id'] as String;
      }
      if (obj['user'] is Map) {
        final userMap = obj['user'] as Map;
        if (userMap['id'] is String && (userMap['id'] as String).isNotEmpty) {
          return userMap['id'] as String;
        }
      }
      if (obj['currentSession'] is Map) {
        final sessionMap = obj['currentSession'] as Map;
        if (sessionMap['user'] is Map) {
          final userMap = sessionMap['user'] as Map;
          if (userMap['id'] is String && (userMap['id'] as String).isNotEmpty) {
            return userMap['id'] as String;
          }
        }
      }
      for (final val in obj.values) {
        if (val is Map) {
          final id = _extractUserId(val);
          if (id != null) return id;
        }
      }
    }
    return null;
  }

  Future<void> _handleFileDownload(DownloadStartRequest request) async {
    try {
      final url = request.url.toString();
      final filename = request.suggestedFilename ??
          'calcx_download_${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Downloading $filename...')),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      if (Platform.isAndroid) {
        try {
          await Permission.storage.request();
        } catch (_) {}
      }

      final uri = Uri.parse(url);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        Directory? targetDir;
        if (Platform.isAndroid) {
          final publicDownload = Directory('/storage/emulated/0/Download');
          if (await publicDownload.exists()) {
            targetDir = publicDownload;
          } else {
            targetDir = await getExternalStorageDirectory();
          }
        } else {
          targetDir = await getApplicationDocumentsDirectory();
        }

        if (targetDir != null) {
          final filePath = '${targetDir.path}/$filename';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to Downloads: $filename'),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Share',
                textColor: Colors.white,
                onPressed: () {
                  Share.shareXFiles([XFile(filePath)]);
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling download: $e');
    }
  }

  void _panicLock() {
    HapticFeedback.heavyImpact();
    ref.read(calculatorUnlockedProvider.notifier).state = false;
    context.go(AppRoutes.calculator);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isServerReady) {
      return const Scaffold(
        backgroundColor: Color(0xFF0B0F19),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00FFCC),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_webViewController != null && await _webViewController!.canGoBack()) {
          await _webViewController!.goBack();
        } else {
          _panicLock();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0F19),
        body: SafeArea(
          child: Stack(
            children: [
              // Main WebView loading pre-downloaded local bundle
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(_targetUrl),
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: '''
                      (function() {
                        var style = document.createElement('style');
                        style.innerHTML = `
                          * { -webkit-tap-highlight-color: transparent !important; -webkit-touch-callout: none !important; }
                          ::-webkit-scrollbar { display: none !important; width: 0px !important; height: 0px !important; }
                        `;
                        if (document.head) {
                          document.head.appendChild(style);
                        } else {
                          document.addEventListener('DOMContentLoaded', function() {
                            document.head.appendChild(style);
                          });
                        }

                        // Robust Web ↔ Native Auth & FCM Bridge
                        function getPlatformReady() {
                          return new Promise(function(resolve) {
                            if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                              resolve();
                            } else {
                              window.addEventListener('flutterInAppWebViewPlatformReady', function() {
                                resolve();
                              }, { once: true });
                              setTimeout(resolve, 800);
                            }
                          });
                        }

                        function checkAndSyncAuth() {
                          getPlatformReady().then(function() {
                            if (!window.flutter_inappwebview || !window.flutter_inappwebview.callHandler) return;
                            try {
                              for (var i = 0; i < localStorage.length; i++) {
                                var key = localStorage.key(i);
                                var val = localStorage.getItem(key);
                                if (!val || val.length < 20) continue;
                                
                                var parsed = null;
                                try {
                                  parsed = JSON.parse(val);
                                  if (typeof parsed === 'string') parsed = JSON.parse(parsed);
                                } catch(e) {}

                                if (parsed && typeof parsed === 'object') {
                                  var user = parsed.user || (parsed.currentSession && parsed.currentSession.user);
                                  if (user && user.id) {
                                    window.flutter_inappwebview.callHandler('syncAuthSession', val);
                                    return;
                                  }
                                }
                              }
                            } catch(e) {}
                          });
                        }

                        window.calcxSyncAuth = checkAndSyncAuth;
                        window.addEventListener('storage', checkAndSyncAuth);
                        if (document.readyState === 'complete') {
                          checkAndSyncAuth();
                        } else {
                          window.addEventListener('load', checkAndSyncAuth);
                        }
                        setInterval(checkAndSyncAuth, 3000);
                      })();
                    ''',
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                  ),
                ]),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  useOnDownloadStart: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  cacheEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  supportZoom: false,
                  transparentBackground: false,
                  overScrollMode: OverScrollMode.NEVER,
                  disableContextMenu: true,
                  allowsBackForwardNavigationGestures: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;

                  // 1. Sync auth session and Android FCM token
                  controller.addJavaScriptHandler(
                    handlerName: 'syncAuthSession',
                    callback: (args) async {
                      if (args.isEmpty || args[0] == null) return;
                      try {
                        final raw = args[0];
                        final userId = _extractUserId(raw);
                        final rawJson = raw is String ? raw : jsonEncode(raw);

                        final client = SupabaseService.clientOrNull;
                        if (client != null) {
                          if (rawJson.isNotEmpty) {
                            try {
                              await client.auth.recoverSession(rawJson);
                            } catch (_) {}
                          }
                          final finalUserId = userId ?? client.auth.currentUser?.id;
                          if (finalUserId != null && finalUserId.isNotEmpty) {
                            await NotificationService.syncToken(null, finalUserId);
                            debugPrint('Linked Web Auth Session and Synced FCM Token for User: $finalUserId');
                          }
                        }
                      } catch (e) {
                        debugPrint('Error in syncAuthSession handler: $e');
                      }
                    },
                  );

                  // 2. Allow web app to directly query the native FCM token
                  controller.addJavaScriptHandler(
                    handlerName: 'getFcmToken',
                    callback: (args) async {
                      try {
                        return await FirebaseMessaging.instance.getToken();
                      } catch (e) {
                        return null;
                      }
                    },
                  );
                },
                onLoadStop: (controller, url) {
                  if (mounted && _isPageLoading) {
                    setState(() {
                      _isPageLoading = false;
                    });
                  }
                },
                onProgressChanged: (controller, progress) {
                  if (progress >= 85 && mounted && _isPageLoading) {
                    setState(() {
                      _isPageLoading = false;
                    });
                  }
                },
                onPermissionRequest: (controller, request) async {
                  final resources = request.resources;
                  final granted = <PermissionResourceType>[];

                  for (final res in resources) {
                    if (res == PermissionResourceType.CAMERA) {
                      final status = await Permission.camera.request();
                      if (status.isGranted) granted.add(res);
                    } else if (res == PermissionResourceType.MICROPHONE) {
                      final status = await Permission.microphone.request();
                      if (status.isGranted) granted.add(res);
                    } else {
                      granted.add(res);
                    }
                  }

                  return PermissionResponse(
                    resources: granted,
                    action: granted.isNotEmpty
                        ? PermissionResponseAction.GRANT
                        : PermissionResponseAction.DENY,
                  );
                },
                onDownloadStartRequest: (controller, downloadRequest) {
                  _handleFileDownload(downloadRequest);
                },
              ),

              // Seamless stealth transition loading cover - eliminates black screen completely
              IgnorePointer(
                ignoring: !_isPageLoading,
                child: AnimatedOpacity(
                  opacity: _isPageLoading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  child: Container(
                    color: const Color(0xFF0B0F19),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 38,
                            height: 38,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Color(0xFF00FFCC),
                            ),
                          ),
                          SizedBox(height: 18),
                          Text(
                            'CALCX VAULT',
                            style: TextStyle(
                              color: Color(0xFF00FFCC),
                              fontSize: 13,
                              letterSpacing: 2.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Floating Quick Panic Calculator Lock Button
              Positioned(
                top: 8,
                right: 12,
                child: const QuickPanicCalculatorButton(
                  size: 38,
                  compact: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
