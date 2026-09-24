import 'dart:math' as math;

class CalculatorEngine {
  const CalculatorEngine();

  String normalizeExpression(String expression) {
    var s = expression
        .replaceAll(' ', '')
        .replaceAll('×', '*')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .replaceAll('÷', '/')
        .replaceAll('√', 'sqrt');

    final implicitMultRegex1 = RegExp(r'(\d|\)|π|e)(sin|cos|tan|asin|acos|atan|ln|log|sqrt|\(|π|e)');
    while (implicitMultRegex1.hasMatch(s)) {
      s = s.replaceAllMapped(implicitMultRegex1, (m) => '${m.group(1)}*${m.group(2)}');
    }

    final implicitMultRegex2 = RegExp(r'(\))(\d)');
    while (implicitMultRegex2.hasMatch(s)) {
      s = s.replaceAllMapped(implicitMultRegex2, (m) => '${m.group(1)}*${m.group(2)}');
    }

    return s;
  }

  double evaluate(String expression, {bool isRadMode = false}) {
    final normalized = normalizeExpression(expression);
    final parser = _ScientificParser(normalized, isRadMode: isRadMode);
    final value = parser.parseExpression();
    parser.skipWhitespace();

    if (!parser.isAtEnd) {
      throw const FormatException('Unexpected characters');
    }
    if (value.isNaN || value.isInfinite) {
      throw const FormatException('Invalid calculation');
    }

    return _cleanFloatingValue(value);
  }

  double _cleanFloatingValue(double val) {
    if (val.abs() < 1e-12) return 0.0;
    final nearest = val.roundToDouble();
    if ((val - nearest).abs() < 1e-11) {
      return nearest;
    }
    return val;
  }

  String format(double value) {
    final cleaned = _cleanFloatingValue(value);
    if (cleaned == cleaned.roundToDouble()) {
      return cleaned.toInt().toString();
    }

    final fixed = cleaned.toStringAsFixed(8);
    return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _ScientificParser {
  _ScientificParser(this.source, {required this.isRadMode});

  final String source;
  final bool isRadMode;
  int index = 0;

  bool get isAtEnd => index >= source.length;

  double parseExpression() {
    var value = parseTerm();
    while (true) {
      skipWhitespace();
      if (match('+')) {
        value += parseTerm();
      } else if (match('-')) {
        value -= parseTerm();
      } else {
        return value;
      }
    }
  }

  double parseTerm() {
    var value = parsePower();
    while (true) {
      skipWhitespace();
      if (match('*')) {
        value *= parsePower();
      } else if (match('/')) {
        final divisor = parsePower();
        if (divisor == 0) throw const FormatException('Cannot divide by zero');
        value /= divisor;
      } else if (match('%')) {
        final divisor = parsePower();
        if (divisor == 0) throw const FormatException('Cannot divide by zero');
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double parsePower() {
    var value = parseUnary();
    skipWhitespace();
    if (match('^')) {
      final exponent = parsePower();
      value = math.pow(value, exponent).toDouble();
    }
    return value;
  }

  double parseUnary() {
    skipWhitespace();
    if (match('+')) {
      return parseUnary();
    }
    if (match('-')) {
      return -parseUnary();
    }
    return parsePostfix();
  }

  double parsePostfix() {
    var value = parsePrimary();
    skipWhitespace();
    while (match('!')) {
      value = _factorial(value);
    }
    return value;
  }

  double _factorial(double n) {
    if (n < 0 || n != n.roundToDouble()) {
      throw const FormatException('Factorial requires non-negative integer');
    }
    final intN = n.toInt();
    if (intN > 170) return double.infinity;
    double result = 1.0;
    for (int i = 2; i <= intN; i++) {
      result *= i;
    }
    return result;
  }

  double parsePrimary() {
    skipWhitespace();

    if (match('(')) {
      final value = parseExpression();
      if (!match(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return value;
    }

    if (matchWord('asin')) {
      return _parseInverseTrig((x) => math.asin(x));
    }
    if (matchWord('acos')) {
      return _parseInverseTrig((x) => math.acos(x));
    }
    if (matchWord('atan')) {
      return _parseInverseTrig((x) => math.atan(x));
    }
    if (matchWord('sin')) {
      return _parseTrig((x) => math.sin(x));
    }
    if (matchWord('cos')) {
      return _parseTrig((x) => math.cos(x));
    }
    if (matchWord('tan')) {
      return _parseTrig((x) => math.tan(x));
    }
    if (matchWord('ln')) {
      final arg = _parseFunctionArg();
      if (arg <= 0) throw const FormatException('ln requires positive argument');
      return math.log(arg);
    }
    if (matchWord('log')) {
      final arg = _parseFunctionArg();
      if (arg <= 0) throw const FormatException('log requires positive argument');
      return math.log(arg) / math.ln10;
    }
    if (matchWord('sqrt')) {
      final arg = _parseFunctionArg();
      if (arg < 0) throw const FormatException('sqrt requires non-negative argument');
      return math.sqrt(arg);
    }

    if (matchWord('pi') || match('π')) {
      return math.pi;
    }
    if (match('e')) {
      return math.e;
    }

    return parseNumber();
  }

  double _parseTrig(double Function(double) trigFn) {
    final arg = _parseFunctionArg();
    final radians = isRadMode ? arg : (arg * math.pi / 180.0);
    return trigFn(radians);
  }

  double _parseInverseTrig(double Function(double) invTrigFn) {
    final arg = _parseFunctionArg();
    final radResult = invTrigFn(arg);
    return isRadMode ? radResult : (radResult * 180.0 / math.pi);
  }

  double _parseFunctionArg() {
    skipWhitespace();
    if (match('(')) {
      final val = parseExpression();
      if (!match(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return val;
    }
    return parseUnary();
  }

  double parseNumber() {
    skipWhitespace();
    final start = index;
    var hasDot = false;

    while (!isAtEnd) {
      final char = source[index];
      if (_isDigit(char)) {
        index++;
      } else if (char == '.' && !hasDot) {
        hasDot = true;
        index++;
      } else {
        break;
      }
    }

    if (start == index) {
      throw const FormatException('Expected number');
    }

    return double.parse(source.substring(start, index));
  }

  bool matchWord(String word) {
    skipWhitespace();
    if (index + word.length <= source.length &&
        source.substring(index, index + word.length) == word) {
      index += word.length;
      return true;
    }
    return false;
  }

  bool match(String expected) {
    skipWhitespace();
    if (isAtEnd || !source.startsWith(expected, index)) {
      return false;
    }
    index += expected.length;
    return true;
  }

  void skipWhitespace() {
    while (!isAtEnd && source[index].trim().isEmpty) {
      index++;
    }
  }

  bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 48 && code <= 57;
  }
}
