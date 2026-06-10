import 'package:calcx/features/calculator/data/passcode_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final calculatorControllerProvider =
    NotifierProvider<CalculatorController, CalculatorState>(
  CalculatorController.new,
);

enum CalculatorOutcome {
  none,
  passcodeCreated,
  unlocked,
}

class CalculatorState {
  const CalculatorState({
    this.expression = '',
    this.display = '0',
    this.error,
    this.showInstruction = false,
  });

  final String expression;
  final String display;
  final String? error;
  final bool showInstruction;

  CalculatorState copyWith({
    String? expression,
    String? display,
    String? error,
    bool? showInstruction,
    bool clearError = false,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      display: display ?? this.display,
      error: clearError ? null : error ?? this.error,
      showInstruction: showInstruction ?? this.showInstruction,
    );
  }
}

class CalculatorController extends Notifier<CalculatorState> {
  @override
  CalculatorState build() {
    _checkPasscodeStatus();
    return const CalculatorState();
  }

  Future<void> _checkPasscodeStatus() async {
    final repo = ref.read(passcodeRepositoryProvider);
    final hasPasscode = await repo.hasPasscode();
    if (!hasPasscode) {
      state = state.copyWith(showInstruction: true);
    }
  }

  Future<CalculatorOutcome> press(String key) async {
    switch (key) {
      case 'AC':
        state = const CalculatorState();
        return CalculatorOutcome.none;
      case 'DEL':
        final next = state.expression.isEmpty
            ? ''
            : state.expression.substring(0, state.expression.length - 1);
        state = state.copyWith(
          expression: next,
          display: next.isEmpty ? '0' : next,
          clearError: true,
        );
        return CalculatorOutcome.none;
      case '=':
        return _calculateAndCheckGate();
      case '()':
        return _handleParentheses();
      default:
        return _append(key);
    }
  }

  Future<CalculatorOutcome> _handleParentheses() async {
    final expr = state.expression;
    if (expr.isEmpty) {
      return _append('(');
    }

    var openCount = 0;
    var closeCount = 0;
    for (var i = 0; i < expr.length; i++) {
      if (expr[i] == '(') openCount++;
      if (expr[i] == ')') closeCount++;
    }

    final lastChar = expr.substring(expr.length - 1);
    final isLastDigitOrClose = RegExp(r'[0-9\)]').hasMatch(lastChar);

    if (openCount > closeCount && isLastDigitOrClose) {
      return _append(')');
    } else {
      return _append('(');
    }
  }

  Future<CalculatorOutcome> biometricUnlock() async {
    final repo = ref.read(passcodeRepositoryProvider);
    if (!await repo.hasPasscode()) {
      return CalculatorOutcome.none;
    }
    return CalculatorOutcome.unlocked;
  }

  Future<CalculatorOutcome> _append(String key) async {
    final value = key == 'x' ? '*' : key;
    final next = state.expression == '0' ? value : '${state.expression}$value';
    state = state.copyWith(
      expression: next,
      display: next,
      clearError: true,
    );
    return CalculatorOutcome.none;
  }

  Future<CalculatorOutcome> _calculateAndCheckGate() async {
    final expression = state.expression;
    if (expression.trim().isEmpty) {
      return CalculatorOutcome.none;
    }

    final engine = ref.read(calculatorEngineProvider);
    final repo = ref.read(passcodeRepositoryProvider);

    try {
      final value = engine.evaluate(expression);
      final display = engine.format(value);

      if (!await repo.hasPasscode()) {
        await repo.savePasscode(expression);
        state = state.copyWith(
          display: display,
          clearError: true,
          showInstruction: false,
        );
        return CalculatorOutcome.passcodeCreated;
      }

      if (await repo.matches(expression)) {
        state = state.copyWith(display: display, clearError: true);
        return CalculatorOutcome.unlocked;
      }

      // Fake calculator functionality - just show result
      state = CalculatorState(display: display, expression: display);
      return CalculatorOutcome.none;
    } on FormatException catch (error) {
      state = state.copyWith(error: error.message, display: 'Error');
      return CalculatorOutcome.none;
    }
  }
}
