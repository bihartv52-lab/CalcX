import 'package:calcx/features/calculator/domain/calculator_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CalculatorEngine();

  test('evaluates operator precedence', () {
    expect(engine.evaluate('2+3*4'), 14);
  });

  test('evaluates parentheses', () {
    expect(engine.evaluate('(2+3)*4'), 20);
  });

  test('formats integers without decimal noise', () {
    expect(engine.format(engine.evaluate('10/2')), '5');
  });

  test('throws on divide by zero', () {
    expect(() => engine.evaluate('1/0'), throwsFormatException);
  });
}
