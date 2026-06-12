import 'dart:math';
import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/features/auth/data/auth_repository.dart';
import 'package:calcx/features/auth/presentation/auth_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _usernameFocusNode = FocusNode();
  bool _signup = true;
  bool _showPassword = false;
  bool _userEditedUsername = false;

  late final AnimationController _bgAnimController;
  late final AnimationController _formAnimController;
  late final Animation<double> _formSlide;
  late final Animation<double> _formFade;

  @override
  void initState() {
    super.initState();
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _formAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _formSlide = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _formAnimController, curve: Curves.easeOutCubic),
    );
    _formFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _formAnimController,
        curve: const Interval(0.2, 1, curve: Curves.easeOut),
      ),
    );
    _formAnimController.forward();

    _email.addListener(_onEmailChanged);
    _usernameFocusNode.addListener(() {
      if (_usernameFocusNode.hasFocus) {
        _userEditedUsername = true;
      }
    });
  }

  void _onEmailChanged() {
    if (!_userEditedUsername && _signup) {
      final emailText = _email.text.trim();
      if (emailText.isNotEmpty) {
        final suggestion = emailText
            .split('@')
            .first
            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
        _username.text = suggestion;
      } else {
        _username.clear();
      }
    }
  }

  @override
  void dispose() {
    _bgAnimController.dispose();
    _formAnimController.dispose();
    _email.dispose();
    _username.dispose();
    _password.dispose();
    _usernameFocusNode.dispose();
    super.dispose();
  }

  void _switchMode() {
    setState(() => _signup = !_signup);
    _formAnimController.reset();
    _formAnimController.forward();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen(authControllerProvider, (_, next) {
      if (!next.hasError && !next.isLoading) {
        _checkAndNavigate();
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        children: [
          // Animated gradient background
          AnimatedBuilder(
            animation: _bgAnimController,
            builder: (context, _) {
              return CustomPaint(
                size: MediaQuery.sizeOf(context),
                painter: _AuroraBackgroundPainter(
                  animationValue: _bgAnimController.value,
                ),
              );
            },
          ),
          // Main content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: AnimatedBuilder(
                  animation: _formAnimController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _formSlide.value),
                      child: Opacity(opacity: _formFade.value, child: child),
                    );
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Hero
                        _buildHero(context),
                        const SizedBox(height: 32),
                        // Form card
                        _buildFormCard(context, authState),
                        const SizedBox(height: 20),
                        // Switch mode
                        _buildSwitchMode(context),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _checkAndNavigate() async {
    final repo = ref.read(authRepositoryProvider);
    final signedIn = await repo.isSignedIn();
    if (signedIn && mounted) {
      context.go(AppRoutes.home);
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController(text: _email.text);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F0F19),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.lock_reset_rounded, color: Color(0xFF7C3AED)),
            SizedBox(width: 10),
            Text(
              'Reset Password',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email address to receive a password reset link.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email Address',
                labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF7C3AED)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final emailText = emailController.text.trim();
              if (emailText.isEmpty) return;
              Navigator.pop(context);

              try {
                await ref.read(authControllerProvider.notifier).sendPasswordReset(emailText);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Password reset request sent! Check your email.'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString().replaceAll('Exception:', '')}'),
                      backgroundColor: const Color(0xFFFF4D6A),
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link 🚀'),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return Column(
      children: [
        // Glowing icon
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899), Color(0xFFF59E0B)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                blurRadius: 32,
                spreadRadius: 4,
              ),
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.3),
                blurRadius: 48,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.calculate_rounded,
            size: 42,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 28),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFE0E7FF), Colors.white, Color(0xFFE0E7FF)],
          ).createShader(bounds),
          child: Text(
            _signup ? 'Create Account' : 'Welcome Back',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _signup
              ? 'Your vibe, your space — totally private 🔒'
              : 'Slide back in — we missed you ✨',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withValues(alpha: 0.55),
            letterSpacing: 0.2,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFormCard(BuildContext context, AsyncValue<void> authState) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.08),
            blurRadius: 40,
            spreadRadius: -10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Tab pills
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _GlowTab(
                    label: 'Sign Up',
                    isSelected: _signup,
                    onTap: () {
                      if (!_signup) _switchMode();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _GlowTab(
                    label: 'Log In',
                    isSelected: !_signup,
                    onTap: () {
                      if (_signup) _switchMode();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // Email or Username
          _NeonTextField(
            controller: _email,
            label: _signup ? 'Email' : 'Email or Username',
            icon: Icons.alternate_email_rounded,
            keyboardType: _signup ? TextInputType.emailAddress : TextInputType.text,
          ),

          // Username (signup only)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _signup
                ? Column(
                    children: [
                      const SizedBox(height: 16),
                      _NeonTextField(
                        controller: _username,
                        label: 'Username',
                        icon: Icons.face_rounded,
                        focusNode: _usernameFocusNode,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),

          const SizedBox(height: 16),

          // Password
          _NeonTextField(
            controller: _password,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: !_showPassword,
            suffixIcon: IconButton(
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_rounded
                    : Icons.visibility_rounded,
                size: 20,
                color: Colors.white.withValues(alpha: 0.4),
              ),
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
          ),

          if (!_signup) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordDialog,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Forgot Password?',
                  style: TextStyle(
                    color: Color(0xFF00DBE9),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 28),

          // Submit button
          _GlowButton(
            label: _signup ? 'Get Started 🚀' : 'Let\'s Go →',
            isLoading: authState.isLoading,
            onPressed: authState.isLoading
                ? null
                : () async {
                    final controller = ref.read(
                      authControllerProvider.notifier,
                    );
                    if (_signup) {
                      final emailVal = _email.text.trim();
                      var usernameVal = _username.text.trim();

                      if (emailVal.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Email is required'),
                            backgroundColor: Color(0xFFFF4D6A),
                          ),
                        );
                        return;
                      }

                      if (usernameVal.isEmpty) {
                        var suggested = emailVal
                            .split('@')
                            .first
                            .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
                        if (suggested.length < 3) {
                          suggested = '${suggested}_calcx';
                        }
                        if (suggested.length > 20) {
                          suggested = suggested.substring(0, 20);
                        }

                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF0F0F19),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                              side: BorderSide(
                                color: const Color(
                                  0xFF7C3AED,
                                ).withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            title: const Row(
                              children: [
                                Icon(
                                  Icons.face_rounded,
                                  color: Color(0xFF7C3AED),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  'Choose Username',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'You left the username field blank. Would you like to use this suggested username?',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF7C3AED,
                                      ).withValues(alpha: 0.25),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '@$suggested',
                                      style: const TextStyle(
                                        color: Color(0xFF00DBE9),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF7C3AED),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('Yes, sounds good! 🚀'),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true) {
                          return;
                        }
                        usernameVal = suggested;
                        _username.text = suggested;
                      }

                      await controller.signUp(
                        email: emailVal,
                        username: usernameVal,
                        password: _password.text,
                      );
                    } else {
                      await controller.signIn(
                        email: _email.text.trim(),
                        password: _password.text,
                      );
                    }
                  },
          ),

          // Error
          if (authState.hasError) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFFFF4D6A).withValues(alpha: 0.1),
                border: Border.all(
                  color: const Color(0xFFFF4D6A).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: Color(0xFFFF4D6A),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.error.toString(),
                      style: const TextStyle(
                        color: Color(0xFFFF8A9E),
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSwitchMode(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _signup ? 'Already have an account? ' : 'New here? ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: _switchMode,
          child: ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
            ).createShader(bounds),
            child: Text(
              _signup ? 'Log In' : 'Sign Up',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Custom Widgets ────────────────────────────────────────────

class _GlowTab extends StatelessWidget {
  const _GlowTab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                )
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C3AED).withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }
}

class _NeonTextField extends StatelessWidget {
  const _NeonTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: Colors.white),
      cursorColor: const Color(0xFF7C3AED),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.35),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF7C3AED)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }
}

class _GlowButton extends StatefulWidget {
  const _GlowButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _pressing = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressing = true),
      onTapUp: (_) {
        setState(() => _pressing = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressing = false),
      child: AnimatedScale(
        scale: _pressing ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF7C3AED,
                ).withValues(alpha: _pressing ? 0.6 : 0.35),
                blurRadius: _pressing ? 24 : 16,
                spreadRadius: _pressing ? 2 : 0,
                offset: const Offset(0, 4),
              ),
              BoxShadow(
                color: const Color(0xFFEC4899).withValues(alpha: 0.2),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Aurora Background Painter ───────────────────────────────────

class _AuroraBackgroundPainter extends CustomPainter {
  _AuroraBackgroundPainter({required this.animationValue});

  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Purple blob
    paint.color = const Color(0xFF7C3AED).withValues(alpha: 0.12);
    canvas.drawCircle(
      Offset(
        size.width * 0.2 + sin(animationValue * 2 * pi) * 30,
        size.height * 0.15 + cos(animationValue * 2 * pi) * 20,
      ),
      size.width * 0.45,
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );

    // Pink blob
    paint.color = const Color(0xFFEC4899).withValues(alpha: 0.08);
    canvas.drawCircle(
      Offset(
        size.width * 0.8 + cos(animationValue * 2 * pi + 1) * 25,
        size.height * 0.7 + sin(animationValue * 2 * pi + 1) * 30,
      ),
      size.width * 0.4,
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 90),
    );

    // Cyan accent
    paint.color = const Color(0xFF00DBE9).withValues(alpha: 0.05);
    canvas.drawCircle(
      Offset(
        size.width * 0.5 + sin(animationValue * 2 * pi + 2) * 40,
        size.height * 0.4 + cos(animationValue * 2 * pi + 2) * 25,
      ),
      size.width * 0.3,
      paint..maskFilter = const MaskFilter.blur(BlurStyle.normal, 70),
    );
  }

  @override
  bool shouldRepaint(covariant _AuroraBackgroundPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
