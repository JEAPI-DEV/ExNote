import 'dart:math' as math;

import 'package:math_expressions/math_expressions.dart';

class ParsedGraphExpression {
  final String functionName;
  final String variableName;
  final Expression expression;

  const ParsedGraphExpression({
    required this.functionName,
    required this.variableName,
    required this.expression,
  });

  double? evaluate(double variableValue) {
    final context = ContextModel()
      ..bindVariableName(variableName, Number(variableValue));
    final value = RealEvaluator(context).evaluate(expression).toDouble();
    return value.isFinite ? value : null;
  }
}

class GraphExpressionParser {
  static final _equationPattern = RegExp(
    r'^\s*([A-Za-z][A-Za-z0-9_]*)\s*\(\s*([A-Za-z][A-Za-z0-9_]*)\s*\)\s*=\s*(.+?)\s*$',
  );

  static ParsedGraphExpression parse(String equation) {
    final match = _equationPattern.firstMatch(equation);
    if (match == null) {
      throw const FormatException('Use format f(x) = x^2');
    }

    final functionName = match.group(1)!;
    final variableName = match.group(2)!;
    final expressionText = _normalizeImplicitMultiplication(
      match.group(3)!,
      variableName,
    );

    try {
      final parser = GrammarParser();
      final expression = parser.parse(expressionText);
      return ParsedGraphExpression(
        functionName: functionName,
        variableName: variableName,
        expression: expression,
      );
    } catch (e) {
      throw FormatException('Invalid expression: $e');
    }
  }

  static String? validate(String equation) {
    try {
      final parsed = parse(equation);
      parsed.evaluate(0);
      return null;
    } catch (e) {
      return e.toString().replaceFirst('FormatException: ', '');
    }
  }

  static String _normalizeImplicitMultiplication(
    String expression,
    String variableName,
  ) {
    var normalized = expression.replaceAll(RegExp(r'\s+'), '');

    normalized = normalized.replaceAllMapped(
      RegExp('(\\d(?:\\.\\d+)?)(?=($variableName|[A-Za-z]+\\())'),
      (match) => '${match.group(1)}*',
    );
    normalized = normalized.replaceAllMapped(
      RegExp('($variableName|\\))(?=(\\d|$variableName|\\())'),
      (match) => '${match.group(1)}*',
    );

    return normalized;
  }

  static bool isFiniteRange(double min, double max) {
    return min.isFinite && max.isFinite && min < max;
  }

  static double niceStep(double value) {
    if (!value.isFinite || value <= 0) return 1;
    final exponent = math.pow(10, (math.log(value) / math.ln10).floor());
    final fraction = value / exponent;
    if (fraction <= 1) return exponent.toDouble();
    if (fraction <= 2) return (2 * exponent).toDouble();
    if (fraction <= 5) return (5 * exponent).toDouble();
    return (10 * exponent).toDouble();
  }
}
