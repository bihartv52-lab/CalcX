import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calcx/core/constants/app_routes.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  int _activeTab = 0;

  final List<Map<String, dynamic>> _tabs = [
    {
      'title': '🧮 Calculator Disguise',
      'tagline': 'Fully Functional Math Calculator',
      'icon': Icons.calculate_outlined,
      'color': const Color(0xFF00DBE9),
      'desc': 'Looks and functions exactly like a real calculator. Secret formula unlocks your private suite.',
    },
    {
      'title': '💬 Encrypted Chat',
      'tagline': 'Instagram DM Style Private Chat',
      'icon': Icons.chat_bubble_outline,
      'color': const Color(0xFF00E676),
      'desc': 'Instant messages, live voice waveforms with duration, video notes, and dual wallpapers.',
    },
    {
      'title': '📞 Studio HD Calls',
      'tagline': 'LiveKit Audio/Video with Sound Mixer',
      'icon': Icons.videocam_outlined,
      'color': const Color(0xFFB600F8),
      'desc': 'Crystal clear WebRTC calls, frosted-glass in-call chat, and individual participant volume sliders.',
    },
    {
      'title': '🍿 Watch Party',
      'tagline': 'Synchronized Cinema & YouTube',
      'icon': Icons.movie_creation_outlined,
      'color': const Color(0xFFFF5722),
      'desc': 'Sub-500ms sync broadcast across participants. Watch videos together with room voice calling.',
    },
    {
      'title': '🎮 Arcade Zone',
      'tagline': 'Multiplayer Scribble & Ludo',
      'icon': Icons.sports_esports_outlined,
      'color': const Color(0xFFFFD600),
      'desc': 'Real-time drawing & guessing canvas plus synchronized Ludo board games with voice chat.',
    },
  ];

  Future<void> _downloadApk() async {
    final apkUrls = [
      Uri.parse('CalcX.apk'),
      Uri.parse('/CalcX.apk'),
      Uri.parse('https://github.com/bihartv52-lab/CalcX/raw/main/CalcX.apk'),
    ];

    for (final url in apkUrls) {
      try {
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Downloading CalcX.apk... If download does not start, please check browser permissions.'),
          backgroundColor: Color(0xFF00DBE9),
        ),
      );
    }
  }

  void _launchWebApp() {
    context.go(AppRoutes.calculator);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      backgroundColor: const Color(0xFF07090E),
      body: SelectionArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildNavbar(isMobile),
              _buildHeroSection(isMobile, screenWidth),
              _buildCorePillars(isMobile),
              _buildHowItWorks(isMobile),
              _buildDownloadBanner(isMobile),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavbar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 48,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E14).withValues(alpha: 0.85),
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00DBE9), Color(0xFFB600F8)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00DBE9).withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Icons.calculate, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Text(
                    'CalcX',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00DBE9).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF00DBE9).withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'v1.0.1',
                      style: TextStyle(
                        color: Color(0xFF00DBE9),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (!isMobile)
                Text(
                  'The Stealth Disguised Social Suite',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: _downloadApk,
            icon: const Icon(Icons.android, size: 16),
            label: Text(isMobile ? 'APK' : 'Download APK'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF00DBE9),
              side: const BorderSide(color: Color(0xFF00DBE9)),
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 12 : 20,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _launchWebApp,
            icon: const Icon(Icons.rocket_launch, size: 16),
            label: Text(isMobile ? 'Launch' : 'Launch Web App'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00DBE9),
              foregroundColor: Colors.black,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 14 : 24,
                vertical: 14,
              ),
              elevation: 8,
              shadowColor: const Color(0xFF00DBE9).withValues(alpha: 0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(bool isMobile, double screenWidth) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: isMobile ? 40 : 80,
      ),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.2,
          colors: [
            const Color(0xFF00DBE9).withValues(alpha: 0.12),
            const Color(0xFFB600F8).withValues(alpha: 0.05),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161C26),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: const Color(0xFF00DBE9).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFF00E676),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  '100% PRIVATE • ZERO DISCOVERY • STEALTH PASSCODE PROTECTED',
                  style: TextStyle(
                    color: Color(0xFF00DBE9),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Disguised on the Surface.\nBoundless Connection Inside.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 32 : 56,
              fontWeight: FontWeight.w900,
              height: 1.15,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Text(
              'CalcX looks and acts like a standard mathematical calculator. Enter your secret passcode to reveal a secure social ecosystem featuring encrypted chat, LiveKit studio HD calls with per-track volume controls, synchronized cinema watch parties, and real-time multiplayer arcade games.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.72),
                fontSize: isMobile ? 15 : 18,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _launchWebApp,
                icon: const Icon(Icons.open_in_browser, size: 20),
                label: const Text('🚀 Launch Web App Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00DBE9),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  elevation: 10,
                  shadowColor: const Color(0xFF00DBE9).withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _downloadApk,
                icon: const Icon(Icons.android, size: 20),
                label: const Text('📥 Download Android APK (111 MB)'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color(0xFF141A24),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 56),
          _buildInteractiveShowcase(isMobile),
        ],
      ),
    );
  }

  Widget _buildInteractiveShowcase(bool isMobile) {
    final active = _tabs[_activeTab];
    final activeColor = active['color'] as Color;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0E121A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: activeColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: activeColor.withValues(alpha: 0.15),
              blurRadius: 36,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF080B10),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_tabs.length, (index) {
                    final isSelected = _activeTab == index;
                    final tab = _tabs[index];
                    final color = tab['color'] as Color;

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => setState(() => _activeTab = index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? color.withValues(alpha: 0.6) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                tab['icon'] as IconData,
                                size: 18,
                                color: isSelected ? color : Colors.white.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                tab['title'] as String,
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.6),
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 36),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active['tagline'] as String,
                            style: TextStyle(
                              color: activeColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            active['title'] as String,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: isMobile ? 18 : 24,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: activeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: activeColor.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'LIVE READY',
                          style: TextStyle(
                            color: activeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    active['desc'] as String,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 28),
                  _buildMockupPreview(isMobile, _activeTab, activeColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMockupPreview(bool isMobile, int tabIndex, Color accentColor) {
    switch (tabIndex) {
      case 0:
        return _buildCalculatorMockup();
      case 1:
        return _buildChatMockup();
      case 2:
        return _buildCallMockup();
      case 3:
        return _buildWatchPartyMockup();
      case 4:
        return _buildArcadeMockup();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCalculatorMockup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(
              color: const Color(0xFF101520),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '1234 = ?',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 14),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Secret Unlocked 🔓',
                  style: TextStyle(
                    color: Color(0xFF00DBE9),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['C', '±', '%', '÷'].map((k) => _buildCalcKey(k, isOp: true)).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['7', '8', '9', '×'].map((k) => _buildCalcKey(k, isOp: k == '×')).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['4', '5', '6', '-'].map((k) => _buildCalcKey(k, isOp: k == '-')).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['1', '2', '3', '+'].map((k) => _buildCalcKey(k, isOp: k == '+')).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['0', '.', '🚨 Panic', '='].map((k) => _buildCalcKey(k, isOp: k == '=' || k.contains('Panic'), isAccent: k == '=')).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalcKey(String label, {bool isOp = false, bool isAccent = false}) {
    Color bg = const Color(0xFF181F2C);
    Color fg = Colors.white;
    if (isAccent) {
      bg = const Color(0xFF00DBE9);
      fg = Colors.black;
    } else if (label.contains('Panic')) {
      bg = const Color(0xFFFF1744).withValues(alpha: 0.2);
      fg = const Color(0xFFFF1744);
    } else if (isOp) {
      bg = const Color(0xFF242E40);
      fg = const Color(0xFF00DBE9);
    }

    return Container(
      width: label.contains('Panic') ? 90 : 54,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildChatMockup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1D2635),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hey! Did you check out the new watch party sync?',
                    style: TextStyle(color: Colors.white, fontSize: 13),
                  ),
                  SizedBox(height: 4),
                  Text('10:42 PM', style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00DBE9), Color(0xFF00E676)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.black, size: 28),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(
                          18,
                          (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            width: 3,
                            height: (i % 4 + 1) * 6.0,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '0:45 • Voice Note',
                        style: TextStyle(color: Colors.black87, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF00E676).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF00E676).withValues(alpha: 0.3)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wallpaper, color: Color(0xFF00E676), size: 14),
                SizedBox(width: 6),
                Text(
                  'Dual Wallpaper Active: 9:16 Portrait Phone & 16:9 Widescreen Desktop',
                  style: TextStyle(color: Color(0xFF00E676), fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallMockup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF1744),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'LiveKit WebRTC Call • 04:32',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFB600F8).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Frosted Chat Overlay',
                  style: TextStyle(color: Color(0xFFB600F8), fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141923),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🔊 Participant Sound Volume Mixer',
                      style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text('85%', style: TextStyle(color: Color(0xFFB600F8), fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    value: 0.85,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation(Color(0xFFB600F8)),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatchPartyMockup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFFFF5722).withValues(alpha: 0.3), const Color(0xFF0F1520)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.play_circle_fill, color: Color(0xFFFF5722), size: 48),
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Row(
                    children: [
                      Icon(Icons.sync, color: Color(0xFF00E676), size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Sub-500ms Realtime Drift Correction • YouTube & Direct Video Sync',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArcadeMockup() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF06080C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141923),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.draw, color: Color(0xFFFFD600), size: 36),
                  SizedBox(height: 8),
                  Text('Scribble Canvas', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Draw & guess in real-time', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF141923),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(Icons.casino, color: Color(0xFF00E676), size: 36),
                  SizedBox(height: 8),
                  Text('Ludo Multiplayer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  SizedBox(height: 4),
                  Text('Turn-based board battle', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorePillars(bool isMobile) {
    final pillars = [
      {
        'icon': Icons.calculate,
        'color': const Color(0xFF00DBE9),
        'title': 'Stealth Calculator Disguise',
        'desc': 'Opens to a full math calculator. Anyone unlocking your phone sees normal addition, multiplication, and history. Your secret formula snaps into your social hub.',
      },
      {
        'icon': Icons.chat,
        'color': const Color(0xFF00E676),
        'title': 'Encrypted Direct Messaging',
        'desc': 'Optimistic instant messaging (<100ms), voice notes with dynamic durations and waveforms, video attachments, emoji reactions, and adaptive dual wallpapers.',
      },
      {
        'icon': Icons.video_call,
        'color': const Color(0xFFB600F8),
        'title': 'LiveKit HD Calls & Mixer',
        'desc': 'Studio-grade voice and video calls powered by LiveKit WebRTC. Features floating overlay, frosted chat with continuous autofocus, and per-track volume sliders.',
      },
      {
        'icon': Icons.movie,
        'color': const Color(0xFFFF5722),
        'title': 'Cinema Watch Parties',
        'desc': 'Synchronized playback for YouTube videos and direct links with sub-500ms broadcast sync, millisecond latency correction, and integrated room voice calls.',
      },
      {
        'icon': Icons.sports_esports,
        'color': const Color(0xFFFFD600),
        'title': 'Arcade Multiplayer Zone',
        'desc': 'Compete with friends in real-time drawing and word-guessing Scribble games or synchronous multiplayer Ludo boards while voice chatting.',
      },
      {
        'icon': Icons.security,
        'color': const Color(0xFF2979FF),
        'title': 'Masked Push Notifications',
        'desc': 'Incoming messages arrive as "You have a pending calculation" so shoulder surfers never suspect a thing. Direct chat banners are silenced when you are inside the conversation.',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 60,
      ),
      child: Column(
        children: [
          const Text(
            'ENGINEERED FOR PRIVACY & POWER',
            style: TextStyle(
              color: Color(0xFF00DBE9),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Everything You Need. Perfectly Disguised.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 26 : 40,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: pillars.map((p) {
              final color = p['color'] as Color;
              return Container(
                width: isMobile ? double.infinity : 360,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D121B),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(p['icon'] as IconData, color: color, size: 28),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      p['title'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      p['desc'] as String,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHowItWorks(bool isMobile) {
    final steps = [
      {
        'num': '01',
        'title': 'Standard Calculator',
        'desc': 'Anyone opening the app is greeted by a real, functional mathematical calculator with history & scientific functions.',
      },
      {
        'num': '02',
        'title': 'Enter Secret Passcode',
        'desc': 'Punch in your private passcode (e.g. 1234=) to instantly dissolve the disguise and enter your encrypted hub.',
      },
      {
        'num': '03',
        'title': 'Instant Panic Button',
        'desc': 'If anyone walks into the room, tap the red Panic button to instantly lock the app and snap back to the calculator.',
      },
    ];

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 60,
      ),
      color: const Color(0xFF080B11),
      child: Column(
        children: [
          const Text(
            'HOW THE DISGUISE WORKS',
            style: TextStyle(
              color: Color(0xFF00DBE9),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Simplicity on the Outside. Fortress Inside.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: isMobile ? 26 : 38,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(
            spacing: 24,
            runSpacing: 20,
            alignment: WrapAlignment.center,
            children: steps.map((s) {
              return Container(
                width: isMobile ? double.infinity : 340,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: const Color(0xFF101520),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFF00DBE9).withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s['num']!,
                      style: const TextStyle(
                        color: Color(0xFF00DBE9),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s['title']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s['desc']!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadBanner(bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 64,
        vertical: 80,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 950),
          child: Container(
            padding: EdgeInsets.all(isMobile ? 28 : 56),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF00DBE9), Color(0xFFB600F8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00DBE9).withValues(alpha: 0.35),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'READY TO EXPERIENCE CALCX?',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Download for Android or Launch on Any Web Browser',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: isMobile ? 26 : 38,
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No installation required for Web. Direct APK installation for full Android background notifications & calling.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.75),
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 36),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _downloadApk,
                      icon: const Icon(Icons.android, size: 22),
                      label: const Text('Download CalcX.apk (111 MB)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _launchWebApp,
                      icon: const Icon(Icons.language, size: 22),
                      label: const Text('Open Web App Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF040609),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00DBE9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.calculate, color: Colors.black, size: 16),
              ),
              const SizedBox(width: 8),
              const Text(
                'CalcX',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Powered by Flutter Web • Supabase Auth & Realtime • LiveKit WebRTC',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Text(
            '© 2026 CalcX by bihartv52-lab. All rights reserved.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
