import 'dart:collection';
import 'dart:io';
import 'package:calcx/app/app_router.dart';
import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/widgets/quick_panic_calculator_button.dart';
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
  const WebVaultShell({super.key});

  static const String liveAppUrl = 'https://calcx-web.vercel.app/?unlocked=true';
  static const String offlineAppUrl = 'http://localhost:8080/?unlocked=true';

  @override
  ConsumerState<WebVaultShell> createState() => _WebVaultShellState();
}

class _WebVaultShellState extends ConsumerState<WebVaultShell> {
  final InAppLocalhostServer _localhostServer = InAppLocalhostServer(
    documentRoot: 'assets/web',
    port: 8080,
  );

  InAppWebViewController? _webViewController;
  String _targetUrl = WebVaultShell.offlineAppUrl;
  bool _isServerReady = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  @override
  void dispose() {
    try {
      _localhostServer.close();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _initApp() async {
    // 1. Start the embedded local server serving pre-bundled offline website
    try {
      await _localhostServer.start();
    } catch (e) {
      debugPrint('Localhost server notice: $e');
    }

    // 2. Request native notification permissions politely on first entry
    if (!kIsWeb) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }

    // 3. Resolve target URL: test if live Vercel web app is reachable
    final resolvedUrl = await _resolveInitialUrl();
    if (mounted) {
      setState(() {
        _targetUrl = resolvedUrl;
        _isServerReady = true;
      });
    }
  }

  Future<String> _resolveInitialUrl() async {
    try {
      final lookup = await InternetAddress.lookup('calcx-web.vercel.app')
          .timeout(const Duration(milliseconds: 1500));
      if (lookup.isNotEmpty && lookup[0].rawAddress.isNotEmpty) {
        return WebVaultShell.liveAppUrl;
      }
    } catch (_) {}
    // Offline or unreachable -> Use pre-bundled local website
    return WebVaultShell.offlineAppUrl;
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
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF00E5FF),
            strokeWidth: 2,
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
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // Main WebView with stealth native configuration
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
                  transparentBackground: true,
                  overScrollMode: OverScrollMode.NEVER,
                  disableContextMenu: true,
                  allowsBackForwardNavigationGestures: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                // Silent fallback on any network error: seamlessly redirect to pre-bundled local website
                onReceivedError: (controller, request, error) {
                  final url = request.url;
                  if (url.host != 'localhost') {
                    controller.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(WebVaultShell.offlineAppUrl),
                      ),
                    );
                  }
                },
                onReceivedHttpError: (controller, request, errorResponse) {
                  final url = request.url;
                  if (url.host != 'localhost') {
                    controller.loadUrl(
                      urlRequest: URLRequest(
                        url: WebUri(WebVaultShell.offlineAppUrl),
                      ),
                    );
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
