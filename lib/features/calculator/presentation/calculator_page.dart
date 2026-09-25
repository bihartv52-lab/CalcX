import 'package:calcx/app/app_router.dart';
import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/services/biometric_service.dart';
import 'package:calcx/core/services/notification_service.dart';
import 'package:calcx/core/services/settings_service.dart';
import 'package:calcx/core/services/supabase_service.dart';
import 'package:calcx/core/widgets/neon_scaffold.dart';
import 'package:calcx/features/calculator/presentation/calculator_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CalculatorPage extends ConsumerWidget {
  const CalculatorPage({super.key});

  void _handleUnlock(BuildContext context, WidgetRef ref) {
    ref.read(calculatorUnlockedProvider.notifier).state = true;
    final targetRoute = NotificationService.pendingNotificationRoute;
    NotificationService.pendingNotificationRoute = null;

    if (kIsWeb) {
      final user = SupabaseService.clientOrNull?.auth.currentUser;
      if (targetRoute != null && targetRoute.isNotEmpty) {
        context.go(targetRoute);
      } else if (user != null) {
        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.auth);
      }
    } else {
      if (targetRoute != null && targetRoute.isNotEmpty) {
        context.go('${AppRoutes.webVault}?route=${Uri.encodeComponent(targetRoute)}');
      } else {
        context.go(AppRoutes.webVault);
      }
    }
  }

  static const _keys = [
    'AC',
    '⌫',
    '()',
    '÷',
    '7',
    '8',
    '9',
    'x',
    '4',
    '5',
    '6',
    '-',
    '1',
    '2',
    '3',
    '+',
    '%',
    '0',
    '.',
    '=',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(calculatorControllerProvider);
    final controller = ref.read(calculatorControllerProvider.notifier);
    final colors = Theme.of(context).colorScheme;
    final size = MediaQuery.sizeOf(context);
    final isWide = size.width > 720;
    final biometricEnabled = ref.watch(biometricEnabledProvider);

    return NeonScaffold(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 680;
          final keypadSpacing = compact ? 8.0 : 10.0;
          final keypadAspectRatio = compact ? 1.45 : 1.18;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: compact ? 8 : 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 440 : 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Top Bar
                      Row(
                        children: [
                          Text(
                            'CalcX',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.primary,
                                ),
                          ),
                          const Spacer(),
                          if (biometricEnabled)
                            IconButton.filledTonal(
                              tooltip: 'Biometric unlock',
                              onPressed: () async {
                                final ok = await ref.read(biometricServiceProvider).unlock();
                                if (!context.mounted) return;
                                if (ok) {
                                  final outcome = await controller.biometricUnlock();
                                  if (!context.mounted) return;
                                  if (outcome == CalculatorOutcome.unlocked) {
                                    _handleUnlock(context, ref);
                                  }
                                }
                              },
                              icon: const Icon(Icons.fingerprint_rounded),
                            ),
                        ],
                      ),

                      SizedBox(height: compact ? 24 : 48),

                      // Expression Display
                      Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          reverse: true,
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            state.display,
                            key: ValueKey(state.display),
                            maxLines: 1,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: compact ? 40 : 52,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),

                      // Messages / Instructions
                      SizedBox(
                        height: 36,
                        child: Column(
                          children: [
                            if (state.error != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  state.error!,
                                  style: TextStyle(color: colors.error, fontSize: 13),
                                ),
                              ),
                            if (state.showInstruction)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Set your passcode as a calculation and press =',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.primary.withValues(alpha: 0.8),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                      SizedBox(height: compact ? 12 : 20),

                      // Main 4x5 Keypad
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _keys.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 4,
                          crossAxisSpacing: keypadSpacing,
                          mainAxisSpacing: keypadSpacing,
                          childAspectRatio: keypadAspectRatio,
                        ),
                        itemBuilder: (context, index) {
                          final key = _keys[index];
                          final isEquals = key == '=';
                          final isOperator = ['÷', 'x', '-', '+'].contains(key);
                          final isUtility = ['AC', '⌫', '()', '%'].contains(key);

                          return _CalculatorKey(
                            label: key,
                            emphasized: isEquals,
                            operatorKey: isOperator,
                            utility: isUtility,
                            onTap: () async {
                              final outcome = await controller.press(key);
                              if (!context.mounted) return;

                              if (outcome == CalculatorOutcome.passcodeCreated) {
                                ref.read(calculatorUnlockedProvider.notifier).state = true;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('✅ Passcode successfully created'),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                await Future.delayed(const Duration(milliseconds: 500));
                                if (!context.mounted) return;
                                if (kIsWeb) {
                                  context.go(AppRoutes.auth);
                                } else {
                                  context.go(AppRoutes.webVault);
                                }
                              }
                              if (outcome == CalculatorOutcome.unlocked) {
                                _handleUnlock(context, ref);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CalculatorKey extends StatefulWidget {
  const _CalculatorKey({
    required this.label,
    required this.onTap,
    this.emphasized = false,
    this.operatorKey = false,
    this.utility = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;
  final bool operatorKey;
  final bool utility;

  @override
  State<_CalculatorKey> createState() => _CalculatorKeyState();
}

class _CalculatorKeyState extends State<_CalculatorKey> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background = widget.emphasized
        ? colors.primary
        : widget.operatorKey
            ? colors.primary.withValues(alpha: 0.22)
            : widget.utility
                ? colors.secondary.withValues(alpha: 0.25)
                : Colors.white.withValues(alpha: 0.08);

    final foreground = widget.emphasized
        ? Colors.black
        : widget.operatorKey
            ? colors.primary
            : Colors.white;

    return AnimatedScale(
      duration: const Duration(milliseconds: 90),
      scale: _pressed ? 0.94 : 1,
      child: Listener(
        onPointerDown: (_) => setState(() => _pressed = true),
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            widget.onTap();
          },
          child: FittedBox(
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: widget.label == '⌫' ? 20 : 22,
                fontWeight: widget.emphasized || widget.operatorKey
                    ? FontWeight.w900
                    : FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
