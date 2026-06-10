class CalculatorEngine {
  const CalculatorEngine();

  String normalizeExpression(String expression) {
    return expression
        .replaceAll(' ', '')
        .replaceAll('x', '*')
        .replaceAll('X', '*')
        .replaceAll('×', '*')
        .replaceAll('÷', '/');
  }

  double evaluate(String expression) {
    final normalized = normalizeExpression(expression);
    final parser = _ExpressionParser(normalized);
    final value = parser.parseExpression();
    parser.skipWhitespace();

    if (!parser.isAtEnd) {
      throw const FormatException('Unexpected characters');
    }
    if (value.isNaN || value.isInfinite) {
      throw const FormatException('Invalid calculation');
    }

    return value;
  }

  String format(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    final fixed = value.toStringAsFixed(10);
    return fixed.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
}

class _ExpressionParser {
  _ExpressionParser(this.source);

  final String source;
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
    var value = parseFactor();

    while (true) {
      skipWhitespace();
      if (match('*')) {
        value *= parseFactor();
      } else if (match('/')) {
        final divisor = parseFactor();
        if (divisor == 0) {
          throw const FormatException('Cannot divide by zero');
        }
        value /= divisor;
      } else if (match('%')) {
        final divisor = parseFactor();
        if (divisor == 0) {
          throw const FormatException('Cannot divide by zero');
        }
        value %= divisor;
      } else {
        return value;
      }
    }
  }

  double parseFactor() {
    skipWhitespace();

    if (match('+')) {
      return parseFactor();
    }
    if (match('-')) {
      return -parseFactor();
    }
    if (match('(')) {
      final value = parseExpression();
      if (!match(')')) {
        throw const FormatException('Missing closing parenthesis');
      }
      return value;
    }

    return parseNumber();
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

  bool match(String expected) {
    skipWhitespace();
    if (isAtEnd || source[index] != expected) {
      return false;
    }
    index++;
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
