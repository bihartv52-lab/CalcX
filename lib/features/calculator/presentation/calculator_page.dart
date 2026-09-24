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
import 'package:intl/intl.dart';

class CalculatorPage extends ConsumerWidget {
  const CalculatorPage({super.key});

  void _handleUnlock(BuildContext context, WidgetRef ref) {
    ref.read(calculatorUnlockedProvider.notifier).state = true;
    final targetRoute = NotificationService.pendingNotificationRoute;
    if (targetRoute != null && targetRoute.isNotEmpty) {
      NotificationService.pendingNotificationRoute = null;
      context.go(targetRoute);
    } else {
      if (kIsWeb) {
        final user = SupabaseService.clientOrNull?.auth.currentUser;
        if (user != null) {
          context.go(AppRoutes.home);
        } else {
          context.go(AppRoutes.auth);
        }
      } else {
        context.go(AppRoutes.webVault);
      }
    }
  }

  void _showHistorySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141414),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(calculatorControllerProvider);
            final controller = ref.read(calculatorControllerProvider.notifier);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Calculation History',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (state.history.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              controller.clearHistory();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                          ),
                      ],
                    ),
                    const Divider(color: Colors.white12),
                    if (state.history.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Text(
                          'No calculations yet',
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: state.history.length,
                          separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                          itemBuilder: (context, idx) {
                            final item = state.history[idx];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              title: Text(
                                item.expression,
                                style: const TextStyle(color: Colors.white70, fontSize: 15),
                              ),
                              subtitle: Text(
                                DateFormat('HH:mm:ss').format(item.timestamp),
                                style: const TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                              trailing: Text(
                                '= ',
                                style: const TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () {
                                controller.loadHistoryItem(item);
                                Navigator.pop(ctx);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static const _scientificKeys = [
    'sin',
    'cos',
    'tan',
    'ln',
    'log',
    '√',
    '^',
    '!',
    'π',
    'e',
    'x²',
  ];

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
          final keypadAspectRatio = compact ? 1.45 : 1.16;

          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(vertical: compact ? 6 : 14),
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
                          const SizedBox(width: 14),
                          // DEG / RAD Toggle
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              controller.toggleRadMode();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: state.isRadMode
                                    ? colors.primary.withValues(alpha: 0.2)
                                    : Colors.white10,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: state.isRadMode ? colors.primary : Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                state.isRadMode ? 'RAD' : 'DEG',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: state.isRadMode ? colors.primary : Colors.white70,
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // History Button
                          IconButton(
                            tooltip: 'Calculation History',
                            onPressed: () => _showHistorySheet(context, ref),
                            icon: const Icon(Icons.history_rounded, color: Colors.white70),
                          ),
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

                      SizedBox(height: compact ? 18 : 36),

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
                              fontSize: compact ? 36 : 46,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 0,
                            ),
                          ),
                        ),
                      ),

                      // Preview Result Display
                      SizedBox(
                        height: 32,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 150),
                            child: state.previewResult.isNotEmpty
                                ? Text(
                                    '= ',
                                    key: ValueKey(state.previewResult),
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w400,
                                      color: Color(0xFF00E5FF),
                                    ),
                                  )
                                : const SizedBox.shrink(),
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
                                  'Set your stealth passcode as a calculation and press =',
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

                      // Scientific Row (Horizontal Scroll)
                      SizedBox(
                        height: 42,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _scientificKeys.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemBuilder: (context, index) {
                            final key = _scientificKeys[index];
                            return _ScientificKeyChip(
                              label: key,
                              onTap: () => controller.press(key),
                            );
                          },
                        ),
                      ),

                      SizedBox(height: compact ? 10 : 16),

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

class _ScientificKeyChip extends StatelessWidget {
  const _ScientificKeyChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF00E5FF),
          ),
        ),
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
