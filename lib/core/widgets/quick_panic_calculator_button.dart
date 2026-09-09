import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/features/calculator/presentation/calculator_controller.dart';
import 'package:calcx/features/calls/data/call_session_provider.dart';
import 'package:calcx/core/widgets/incoming_call_listener.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// A prominent red emergency button that immediately snaps the app back
/// to the innocent Calculator screen with zero delay.
class QuickPanicCalculatorButton extends ConsumerWidget {
  final double size;
  final EdgeInsetsGeometry? margin;
  final bool compact;

  const QuickPanicCalculatorButton({
    super.key,
    this.size = 36,
    this.margin,
    this.compact = false,
  });

  void _triggerPanic(BuildContext context, WidgetRef ref) {
    // Instant haptic feedback for tactile certainty
    HapticFeedback.heavyImpact();

    // Ensure call screen overlay flags are reset
    try {
      ref.read(isCallScreenShowingProvider.notifier).state = false;
    } catch (_) {}

    // Reset calculator engine to clean innocent state
    try {
      ref.read(calculatorControllerProvider.notifier).press('AC');
    } catch (_) {}

    // Instantly snap to the Calculator page
    try {
      context.go(AppRoutes.calculator);
    } catch (_) {
      Navigator.of(context, rootNavigator: true).pushNamedAndRemoveUntil(
        AppRoutes.calculator,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Tooltip(
        message: 'Quick Calculator (Panic Switch)',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _triggerPanic(context, ref),
            borderRadius: BorderRadius.circular(size / 2),
            splashColor: Colors.white30,
            highlightColor: Colors.white10,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFF334B),
                    Color(0xFFD32F2F),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD32F2F).withOpacity(0.45),
                    blurRadius: 6,
                    spreadRadius: 1,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.2,
                ),
              ),
              child: Icon(
                Icons.calculate_rounded,
                size: compact ? 17 : 20,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
