import 'package:calcx/core/constants/app_routes.dart';
import 'package:calcx/core/services/biometric_service.dart';
import 'package:calcx/core/services/settings_service.dart';
import 'package:calcx/core/widgets/neon_scaffold.dart';
import 'package:calcx/features/calculator/presentation/calculator_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class CalculatorPage extends ConsumerWidget {
  const CalculatorPage({super.key});

  static const _keys = [
    'AC',
    'DEL',
    '%',
    '/',
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
    '0',
    '.',
    '()',
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
          final keypadSpacing = compact ? 8.0 : 12.0;
          final keypadAspectRatio = compact ? 1.45 : 1.12;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: compact ? 8 : 18),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isWide ? 420 : 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'CalcX',
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: colors.primary,
                                ),
                          ),
                          const Spacer(),
                          if (biometricEnabled)
                            IconButton.filledTonal(
                              tooltip: 'Biometric unlock',
                              onPressed: () async {
                                final ok = await ref
                                    .read(biometricServiceProvider)
                                    .unlock();
                                if (!context.mounted) {
                                  return;
                                }
                                if (ok) {
                                  final outcome = await controller
                                      .biometricUnlock();
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (outcome == CalculatorOutcome.unlocked) {
                                    context.go(AppRoutes.home);
                                  }
                                }
                              },
                              icon: const Icon(Icons.fingerprint_rounded),
                            ),
                        ],
                      ),
                      SizedBox(height: compact ? 28 : 72),
                      Align(
                        alignment: Alignment.centerRight,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Text(
                            state.display,
                            key: ValueKey(state.display),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: Theme.of(context).textTheme.displayMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w300,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 48,
                        child: Column(
                          children: [
                            if (state.error != null)
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  state.error!,
                                  style: TextStyle(color: colors.error),
                                ),
                              ),
                            if (state.showInstruction)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  'Set your passcode as a calculation and press =',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: colors.primary.withValues(alpha: 0.8),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 12 : 18),
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
                          return _CalculatorKey(
                            label: key,
                            emphasized: key == '=',
                            utility: index < 3,
                            onTap: () async {
                              final outcome = await controller.press(key);
                              if (!context.mounted) {
                                return;
                              }
                              if (outcome ==
                                  CalculatorOutcome.passcodeCreated) {
                                // Show success message
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('✅ Passcode successfully created'),
                                    backgroundColor: Theme.of(context).colorScheme.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                // Navigate to auth after a short delay
                                await Future.delayed(const Duration(milliseconds: 500));
                                if (!context.mounted) return;
                                context.go(AppRoutes.auth);
                              }
                              if (outcome == CalculatorOutcome.unlocked) {
                                context.go(AppRoutes.home);
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
    this.utility = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool emphasized;
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
        : widget.utility
        ? colors.secondary.withValues(alpha: 0.25)
        : Colors.white.withValues(alpha: 0.08);
    final foreground = widget.emphasized ? Colors.black : Colors.white;

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
              borderRadius: BorderRadius.circular(22),
            ),
          ),
          onPressed: widget.onTap,
          child: FittedBox(
            child: Text(
              widget.label,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
