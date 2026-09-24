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

  static const String webAppUrl = 'https://calcx-web.vercel.app/?unlocked=true';

  @override
  ConsumerState<WebVaultShell> createState() => _WebVaultShellState();
}

class _WebVaultShellState extends ConsumerState<WebVaultShell> {
  InAppWebViewController? _webViewController;
  double _loadProgress = 0;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _requestInitialPermissions();
  }

  Future<void> _requestInitialPermissions() async {
    if (!kIsWeb) {
      try {
        await Permission.notification.request();
      } catch (_) {}
    }
  }

  Future<void> _handleFileDownload(DownloadStartRequest request) async {
    try {
      final url = request.url.toString();
      final filename = request.suggestedFilename ??
          'calcx_download_';

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text('Downloading ...')),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );

      if (Platform.isAndroid) {
        await Permission.storage.request();
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
          final filePath = '/';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);

          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Saved to Downloads: '),
              backgroundColor: const Color(0xFF10B981),
              duration: const Duration(seconds: 5),
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
      debugPrint('Error handling download: ');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Download failed: '),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _panicLock() {
    HapticFeedback.heavyImpact();
    ref.read(calculatorUnlockedProvider.notifier).state = false;
    context.go(AppRoutes.calculator);
  }

  @override
  Widget build(BuildContext context) {
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
              // Main WebView
              InAppWebView(
                initialUrlRequest: URLRequest(
                  url: WebUri(WebVaultShell.webAppUrl),
                ),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  useOnDownloadStart: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  cacheEnabled: true,
                  supportZoom: false,
                  transparentBackground: true,
                  allowsBackForwardNavigationGestures: true,
                  mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                ),
                onWebViewCreated: (controller) {
                  _webViewController = controller;
                },
                onLoadStart: (controller, url) {
                  setState(() {
                    _isLoading = true;
                    _hasError = false;
                  });
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _loadProgress = progress / 100.0;
                    if (progress >= 100) {
                      _isLoading = false;
                    }
                  });
                },
                onLoadStop: (controller, url) {
                  setState(() {
                    _isLoading = false;
                  });
                },
                onReceivedError: (controller, request, error) {
                  setState(() {
                    _isLoading = false;
                    _hasError = true;
                    _errorMessage = error.description;
                  });
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

              // Linear Progress Indicator
              if (_isLoading && _loadProgress < 1.0)
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: LinearProgressIndicator(
                    value: _loadProgress > 0 ? _loadProgress : null,
                    backgroundColor: Colors.transparent,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00E5FF)),
                    minHeight: 2.5,
                  ),
                ),

              // Offline / Error Overlay
              if (_hasError)
                Container(
                  color: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.wifi_off_rounded,
                            size: 40,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Offline Mode',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage.isNotEmpty
                              ? 'Unable to connect: '
                              : 'Please check your internet connection to access the online vault.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white70,
                                side: const BorderSide(color: Colors.white24),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: _panicLock,
                              icon: const Icon(Icons.calculate_outlined, size: 18),
                              label: const Text('Calculator'),
                            ),
                            const SizedBox(width: 14),
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00E5FF),
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: () {
                                setState(() {
                                  _hasError = false;
                                  _isLoading = true;
                                });
                                _webViewController?.reload();
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Retry', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
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
