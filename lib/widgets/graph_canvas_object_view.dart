import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/graph_canvas_object.dart';
import '../services/graph_expression_parser.dart';

class GraphCanvasObjectView extends StatelessWidget {
  final GraphCanvasObject graph;

  const GraphCanvasObjectView({super.key, required this.graph});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: GraphCanvasObjectPainter(
        graph: graph,
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
      size: Size(graph.width, graph.height),
    );
  }
}

class GraphCanvasObjectPainter extends CustomPainter {
  final GraphCanvasObject graph;
  final bool isDark;

  const GraphCanvasObjectPainter({required this.graph, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final foreground = isDark ? Colors.white70 : Colors.black87;
    final axisColor = foreground.withValues(alpha: 0.72);

    final plotRect = Rect.fromLTWH(34, 20, size.width - 68, size.height - 52);
    if (plotRect.width <= 0 || plotRect.height <= 0) return;

    if (!GraphExpressionParser.isFiniteRange(_xMin, _xMax) ||
        !GraphExpressionParser.isFiniteRange(_yMin, _yMax)) {
      _drawText(
        canvas,
        'Invalid graph range',
        const Offset(16, 20),
        TextStyle(color: foreground, fontSize: 12),
      );
      return;
    }

    canvas.save();
    canvas.clipRect(plotRect);
    _drawFunctions(canvas, plotRect);
    canvas.restore();

    _drawAxesAndTicks(canvas, size, plotRect, axisColor, foreground);
  }

  void _drawAxesAndTicks(
    Canvas canvas,
    Size size,
    Rect plotRect,
    Color axisColor,
    Color textColor,
  ) {
    final axisPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final tickPaint = Paint()
      ..color = axisColor
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    final labelStyle = TextStyle(
      color: textColor.withValues(alpha: 0.74),
      fontSize: 10,
    );
    final axisLabelStyle = TextStyle(
      color: textColor,
      fontSize: 12,
      fontWeight: FontWeight.w600,
    );

    final xAxisY = _axisY(plotRect);
    final yAxisX = _axisX(plotRect);

    canvas.drawLine(
      Offset(plotRect.left, xAxisY),
      Offset(plotRect.right, xAxisY),
      axisPaint,
    );
    canvas.drawLine(
      Offset(yAxisX, plotRect.bottom),
      Offset(yAxisX, plotRect.top),
      axisPaint,
    );
    _drawArrowHead(
      canvas,
      Offset(plotRect.right, xAxisY),
      Axis.horizontal,
      axisPaint,
    );
    _drawArrowHead(
      canvas,
      Offset(yAxisX, plotRect.top),
      Axis.vertical,
      axisPaint,
    );

    final xTicks = _ticks(_xMin, _xMax, graph.xTick).toList();
    final yTicks = _ticks(_yMin, _yMax, graph.yTick).toList();
    final xLabelStride = _labelStride(
      graph.xTick,
      _xMin,
      _xMax,
      plotRect.width,
      32,
    );
    final yLabelStride = _labelStride(
      graph.yTick,
      _yMin,
      _yMax,
      plotRect.height,
      22,
    );

    for (int i = 0; i < xTicks.length; i++) {
      final x = xTicks[i];
      final dx = _mapX(x, plotRect);
      if (dx < plotRect.left - 0.1 || dx > plotRect.right + 0.1) continue;
      canvas.drawLine(
        Offset(dx, xAxisY - 4),
        Offset(dx, xAxisY + 4),
        tickPaint,
      );

      if (i % xLabelStride == 0 && x.abs() > 1e-9) {
        final labelY = xAxisY + 7 <= size.height - 14
            ? xAxisY + 7
            : xAxisY - 19;
        _drawCenteredText(
          canvas,
          _formatTick(x),
          Offset(dx, labelY),
          labelStyle,
        );
      }
    }

    for (int i = 0; i < yTicks.length; i++) {
      final y = yTicks[i];
      final dy = _mapY(y, plotRect);
      if (dy < plotRect.top - 0.1 || dy > plotRect.bottom + 0.1) continue;
      canvas.drawLine(
        Offset(yAxisX - 4, dy),
        Offset(yAxisX + 4, dy),
        tickPaint,
      );

      if (i % yLabelStride == 0 && y.abs() > 1e-9) {
        final labelX = yAxisX - 8 >= 18 ? yAxisX - 8 : yAxisX + 8;
        _drawAxisSideText(
          canvas,
          _formatTick(y),
          Offset(labelX, dy - 6),
          labelStyle,
          alignRight: labelX < yAxisX,
        );
      }
    }

    _drawText(
      canvas,
      graph.xAxisLabel,
      Offset(plotRect.right + 8, xAxisY - 8),
      axisLabelStyle,
    );
    _drawText(
      canvas,
      graph.yAxisLabel,
      Offset(yAxisX + 8, math.max(0, plotRect.top - 18)),
      axisLabelStyle,
    );
  }

  void _drawFunctions(Canvas canvas, Rect plotRect) {
    for (final function in graph.functions) {
      ParsedGraphExpression parsed;
      try {
        parsed = GraphExpressionParser.parse(function.equation);
      } catch (_) {
        continue;
      }

      final paint = Paint()
        ..color = Color(function.color)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      var hasStarted = false;
      Offset? previous;
      final samples = math.max(80, plotRect.width.floor());

      for (int i = 0; i <= samples; i++) {
        final t = i / samples;
        final x = _xMin + (_xMax - _xMin) * t;
        final y = parsed.evaluate(x);
        if (y == null || y < _yMin || y > _yMax) {
          hasStarted = false;
          previous = null;
          continue;
        }

        final point = Offset(_mapX(x, plotRect), _mapY(y, plotRect));
        if (previous != null && (point - previous).distance > plotRect.height) {
          hasStarted = false;
        }

        if (!hasStarted) {
          path.moveTo(point.dx, point.dy);
          hasStarted = true;
        } else {
          path.lineTo(point.dx, point.dy);
        }
        previous = point;
      }

      canvas.drawPath(path, paint);
    }
  }

  Iterable<double> _ticks(double min, double max, double tick) sync* {
    if (!GraphExpressionParser.isFiniteRange(min, max) || tick <= 0) return;
    final first = (min / tick).ceil() * tick;
    const maxTicks = 1000;
    for (int i = 0; i < maxTicks; i++) {
      final value = first + i * tick;
      if (value > max + tick * 0.0001) break;
      yield value;
    }
  }

  double _mapX(double x, Rect plotRect) {
    return plotRect.left + ((x - _xMin) / (_xMax - _xMin)) * plotRect.width;
  }

  double _mapY(double y, Rect plotRect) {
    return plotRect.bottom - ((y - _yMin) / (_yMax - _yMin)) * plotRect.height;
  }

  double get _xMin => graph.xMin * graph.xTick;
  double get _xMax => graph.xMax * graph.xTick;
  double get _yMin => graph.yMin * graph.yTick;
  double get _yMax => graph.yMax * graph.yTick;

  String _formatTick(double value) {
    if (value.abs() < 1e-9) return '0';
    if (value == value.roundToDouble()) return value.round().toString();
    final precision = value.abs() < 1 ? 2 : 1;
    return value.toStringAsFixed(precision).replaceFirst(RegExp(r'\.0+$'), '');
  }

  double _axisX(Rect plotRect) {
    if (_xMin <= 0 && _xMax >= 0) return _mapX(0, plotRect);
    return _xMin > 0 ? plotRect.left : plotRect.right;
  }

  double _axisY(Rect plotRect) {
    if (_yMin <= 0 && _yMax >= 0) return _mapY(0, plotRect);
    return _yMin > 0 ? plotRect.bottom : plotRect.top;
  }

  int _labelStride(
    double tick,
    double min,
    double max,
    double pixelSpan,
    double minPixelSpacing,
  ) {
    if (tick <= 0 || pixelSpan <= 0 || max <= min) return 1;
    final tickPixels = pixelSpan * tick / (max - min);
    if (tickPixels >= minPixelSpacing) return 1;
    return (minPixelSpacing / math.max(tickPixels, 0.1)).ceil();
  }

  void _drawArrowHead(Canvas canvas, Offset tip, Axis axis, Paint paint) {
    const size = 7.0;
    final path = Path();
    if (axis == Axis.horizontal) {
      path
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - size, tip.dy - size * 0.55)
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - size, tip.dy + size * 0.55);
    } else {
      path
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx - size * 0.55, tip.dy + size)
        ..moveTo(tip.dx, tip.dy)
        ..lineTo(tip.dx + size * 0.55, tip.dy + size);
    }
    canvas.drawPath(path, paint);
  }

  void _drawCenteredText(
    Canvas canvas,
    String text,
    Offset centerTop,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 56);
    painter.paint(
      canvas,
      Offset(centerTop.dx - painter.width / 2, centerTop.dy),
    );
  }

  void _drawAxisSideText(
    Canvas canvas,
    String text,
    Offset offset,
    TextStyle style, {
    required bool alignRight,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 56);
    painter.paint(
      canvas,
      alignRight ? Offset(offset.dx - painter.width, offset.dy) : offset,
    );
  }

  void _drawText(Canvas canvas, String text, Offset offset, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(maxWidth: 64);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(GraphCanvasObjectPainter oldDelegate) {
    return oldDelegate.graph != graph || oldDelegate.isDark != isDark;
  }
}
