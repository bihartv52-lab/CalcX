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

class CalculationRecord {
  const CalculationRecord({
    required this.expression,
    required this.result,
    required this.timestamp,
  });

  final String expression;
  final String result;
  final DateTime timestamp;
}

class CalculatorState {
  const CalculatorState({
    this.expression = '',
    this.display = '0',
    this.previewResult = '',
    this.error,
    this.showInstruction = false,
    this.isRadMode = false,
    this.isScientificExpanded = false,
    this.history = const [],
  });

  final String expression;
  final String display;
  final String previewResult;
  final String? error;
  final bool showInstruction;
  final bool isRadMode;
  final bool isScientificExpanded;
  final List<CalculationRecord> history;

  CalculatorState copyWith({
    String? expression,
    String? display,
    String? previewResult,
    String? error,
    bool? showInstruction,
    bool? isRadMode,
    bool? isScientificExpanded,
    List<CalculationRecord>? history,
    bool clearError = false,
    bool clearPreview = false,
  }) {
    return CalculatorState(
      expression: expression ?? this.expression,
      display: display ?? this.display,
      previewResult: clearPreview ? '' : previewResult ?? this.previewResult,
      error: clearError ? null : error ?? this.error,
      showInstruction: showInstruction ?? this.showInstruction,
      isRadMode: isRadMode ?? this.isRadMode,
      isScientificExpanded: isScientificExpanded ?? this.isScientificExpanded,
      history: history ?? this.history,
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

  void toggleRadMode() {
    final next = !state.isRadMode;
    state = state.copyWith(isRadMode: next);
    _updatePreview(state.expression);
  }

  void toggleScientificExpanded() {
    state = state.copyWith(isScientificExpanded: !state.isScientificExpanded);
  }

  void clearHistory() {
    state = state.copyWith(history: []);
  }

  void loadHistoryItem(CalculationRecord item) {
    state = state.copyWith(
      expression: item.expression,
      display: item.expression,
      previewResult: item.result,
      clearError: true,
    );
  }

  Future<CalculatorOutcome> press(String key) async {
    switch (key) {
      case 'AC':
        state = state.copyWith(
          expression: '',
          display: '0',
          clearPreview: true,
          clearError: true,
        );
        return CalculatorOutcome.none;
      case 'DEL':
      case '⌫':
        var next = state.expression;
        if (next.isNotEmpty) {
          final fns = ['asin(', 'acos(', 'atan(', 'sin(', 'cos(', 'tan(', 'log(', 'ln(', 'sqrt('];
          var deletedFn = false;
          for (final fn in fns) {
            if (next.endsWith(fn)) {
              next = next.substring(0, next.length - fn.length);
              deletedFn = true;
              break;
            }
          }
          if (!deletedFn) {
            next = next.substring(0, next.length - 1);
          }
        }
        state = state.copyWith(
          expression: next,
          display: next.isEmpty ? '0' : next,
          clearError: true,
        );
        _updatePreview(next);
        return CalculatorOutcome.none;
      case '=':
        return _calculateAndCheckGate();
      case '()':
        return _handleParentheses();
      case 'sin':
      case 'cos':
      case 'tan':
      case 'asin':
      case 'acos':
      case 'atan':
      case 'ln':
      case 'log':
      case 'sqrt':
      case '√':
        final fnName = key == '√' ? 'sqrt(' : '$key(';
        return _append(fnName);
      case 'x²':
        return _append('^2');
      case 'xʸ':
      case '^':
        return _append('^');
      case 'π':
        return _append('π');
      case 'e':
        return _append('e');
      case '!':
        return _append('!');
      case 'RAD':
      case 'DEG':
        toggleRadMode();
        return CalculatorOutcome.none;
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
    final isLastDigitOrClose = RegExp(r'[0-9\)\π\e\!]').hasMatch(lastChar);

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
    final value = key == 'x' ? '*' : (key == '÷' ? '/' : key);
    final current = state.expression;
    final next = (current == '0' && !RegExp(r'[\+\-\*\/\%\^\.\!]').hasMatch(value))
        ? value
        : '$current$value';
    state = state.copyWith(
      expression: next,
      display: next,
      clearError: true,
    );
    _updatePreview(next);
    return CalculatorOutcome.none;
  }

  void _updatePreview(String expr) {
    if (expr.trim().isEmpty) {
      state = state.copyWith(clearPreview: true);
      return;
    }
    try {
      final engine = ref.read(calculatorEngineProvider);
      final val = engine.evaluate(expr, isRadMode: state.isRadMode);
      final formatted = engine.format(val);
      state = state.copyWith(previewResult: formatted);
    } catch (_) {
      state = state.copyWith(clearPreview: true);
    }
  }

  Future<CalculatorOutcome> _calculateAndCheckGate() async {
    final expression = state.expression;
    if (expression.trim().isEmpty) {
      return CalculatorOutcome.none;
    }

    final engine = ref.read(calculatorEngineProvider);
    final repo = ref.read(passcodeRepositoryProvider);

    try {
      final value = engine.evaluate(expression, isRadMode: state.isRadMode);
      final display = engine.format(value);

      if (!await repo.hasPasscode()) {
        await repo.savePasscode(expression);
        state = state.copyWith(
          display: display,
          clearError: true,
          showInstruction: false,
          clearPreview: true,
        );
        return CalculatorOutcome.passcodeCreated;
      }

      if (await repo.matches(expression)) {
        state = state.copyWith(display: display, clearError: true, clearPreview: true);
        return CalculatorOutcome.unlocked;
      }

      // Add to local calculation history
      final newRecord = CalculationRecord(
        expression: expression,
        result: display,
        timestamp: DateTime.now(),
      );
      final updatedHistory = [newRecord, ...state.history];
      if (updatedHistory.length > 50) updatedHistory.removeLast();

      // Normal scientific calculator functionality - show result and store in history
      state = state.copyWith(
        display: display,
        expression: display,
        clearPreview: true,
        history: updatedHistory,
        clearError: true,
      );
      return CalculatorOutcome.none;
    } on FormatException catch (error) {
      state = state.copyWith(error: error.message, display: 'Error');
      return CalculatorOutcome.none;
    } catch (_) {
      state = state.copyWith(error: 'Invalid calculation', display: 'Error');
      return CalculatorOutcome.none;
    }
  }
}
