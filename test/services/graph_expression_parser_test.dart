import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/services/graph_expression_parser.dart';

void main() {
  test('parses and evaluates standard f(x) syntax', () {
    final parsed = GraphExpressionParser.parse('f(x)=x^2');

    expect(parsed.functionName, 'f');
    expect(parsed.variableName, 'x');
    expect(parsed.evaluate(3), 9);
  });

  test('supports arbitrary variable names and implicit multiplication', () {
    final parsed = GraphExpressionParser.parse('g(t)=2t+1');

    expect(parsed.functionName, 'g');
    expect(parsed.variableName, 't');
    expect(parsed.evaluate(4), 9);
  });

  test('supports uppercase function names and unary negatives', () {
    final parsed = GraphExpressionParser.parse('F(s)=-s');

    expect(parsed.functionName, 'F');
    expect(parsed.variableName, 's');
    expect(parsed.evaluate(4), -4);
  });

  test('returns validation errors for invalid equation syntax', () {
    expect(GraphExpressionParser.validate('x^2'), isNotNull);
    expect(GraphExpressionParser.validate('f(x)=x^2'), isNull);
  });
}
