import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutDeveloperCard extends StatefulWidget {
  const AboutDeveloperCard({super.key});

  @override
  State<AboutDeveloperCard> createState() => _AboutDeveloperCardState();
}

class _AboutDeveloperCardState extends State<AboutDeveloperCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _pulseAnimation;
  late final Animation<double> _shimmerAnimation;
  bool _isHovered = false;
  bool _isPressed = false;

  static const String instagramUrl = 'https://www.instagram.com/__adarsh._.008';
  static const String instagramHandle = '@__adarsh._.008';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _launchInstagram(BuildContext context) async {
    HapticFeedback.mediumImpact();
    try {
      final uri = Uri.parse(instagramUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open Instagram: '),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _copyHandle(BuildContext context) {
    Clipboard.setData(const ClipboardData(text: instagramHandle));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📋 Instagram handle copied to clipboard!'),
        duration: Duration(seconds: 2),
        backgroundColor: Color(0xFFC13584),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * 2 * math.pi;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: SweepGradient(
              center: Alignment.center,
              transform: GradientRotation(angle),
              colors: const [
                Color(0xFF833AB4),
                Color(0xFFFD1D1D),
                Color(0xFFFCAF45),
                Color(0xFF00F2FE),
                Color(0xFF4FACFE),
                Color(0xFF833AB4),
              ],
              stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE1306C).withValues(alpha: isDark ? 0.3 : 0.18),
                blurRadius: 22,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: const Color(0xFF00F2FE).withValues(alpha: isDark ? 0.2 : 0.1),
                blurRadius: 25,
                spreadRadius: -4,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(2.2),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              color: isDark ? const Color(0xFF131722) : const Color(0xFFFBFBFE),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF833AB4), Color(0xFFE1306C)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE1306C).withValues(alpha: 0.4),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'About CalcX',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 12, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Text(
                            'v1.0.0+1 • Stealth',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF1E2333),
                              const Color(0xFF161A26),
                            ]
                          : [
                              const Color(0xFFF3F4F8),
                              const Color(0xFFEAECEF),
                            ],
                    ),
                    border: Border.all(
                      color: isDark ? Colors.white12 : Colors.black12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF4FACFE),
                                Color(0xFF00F2FE),
                                Color(0xFF833AB4),
                                Color(0xFFE1306C),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF00F2FE).withValues(alpha: 0.4),
                                blurRadius: 14,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.code_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  colors: const [
                                    Color(0xFF00F2FE),
                                    Color(0xFFE1306C),
                                    Color(0xFFFCAF45),
                                    Color(0xFF00F2FE),
                                  ],
                                  stops: const [0.0, 0.35, 0.7, 1.0],
                                  transform: GradientRotation(_shimmerAnimation.value * math.pi),
                                ).createShader(bounds);
                              },
                              child: const Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'Developed by Adarsh',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 6),
                                  Icon(
                                    Icons.verified_rounded,
                                    size: 18,
                                    color: Color(0xFF00F2FE),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Architect & Lead Developer',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Crafted with precision & stealth security',
                              style: TextStyle(
                                fontSize: 11,
                                fontStyle: FontStyle.italic,
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                MouseRegion(
                  onEnter: (_) => setState(() => _isHovered = true),
                  onExit: (_) => setState(() => _isHovered = false),
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTapDown: (_) => setState(() => _isPressed = true),
                    onTapUp: (_) => setState(() => _isPressed = false),
                    onTapCancel: () => setState(() => _isPressed = false),
                    onTap: () => _launchInstagram(context),
                    onLongPress: () => _copyHandle(context),
                    child: AnimatedScale(
                      scale: _isPressed ? 0.97 : (_isHovered ? 1.02 : 1.0),
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeOutCubic,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF405DE6),
                              Color(0xFF5851DB),
                              Color(0xFF833AB4),
                              Color(0xFFC13584),
                              Color(0xFFE1306C),
                              Color(0xFFFD1D1D),
                              Color(0xFFF56040),
                              Color(0xFFFCAF45),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE1306C).withValues(alpha: _isHovered ? 0.6 : 0.35),
                              blurRadius: _isHovered ? 22 : 14,
                              spreadRadius: _isHovered ? 2 : 0,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Instagram Profile',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    Text(
                                      '__adarsh._.008',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 18),
                                  tooltip: 'Copy handle',
                                  onPressed: () => _copyHandle(context),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    children: [
                                      Text(
                                        'Visit',
                                        style: TextStyle(
                                          color: Color(0xFFC13584),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                      SizedBox(width: 4),
                                      Icon(
                                        Icons.open_in_new_rounded,
                                        size: 13,
                                        color: Color(0xFFC13584),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
