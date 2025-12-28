import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import 'fast_drawing_toolbar.dart';

class FastDrawingCanvas extends StatefulWidget {
  final ValueNotifier<Sketch> sketchNotifier;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;

  const FastDrawingCanvas({
    super.key,
    required this.sketchNotifier,
    this.currentColor = Colors.black,
    this.currentWidth = 2.0,
    this.currentTool = DrawingTool.pen,
  });

  @override
  State<FastDrawingCanvas> createState() => FastDrawingCanvasState();
}

class FastDrawingCanvasState extends State<FastDrawingCanvas> {
  List<Point>? _currentLinePoints;

  void _handlePointerDown(PointerDownEvent event) {
    // Only handle stylus/pen events
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (widget.currentTool == DrawingTool.strokeEraser) {
      _handleStrokeEraser(event.localPosition);
      return;
    }

    setState(() {
      _currentLinePoints = [
        Point(
          event.localPosition.dx,
          event.localPosition.dy,
          pressure: event.pressure,
        ),
      ];
    });
  }

  void _handlePointerMove(PointerMoveEvent event) {
    // Only handle stylus/pen events
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (widget.currentTool == DrawingTool.strokeEraser) {
      _handleStrokeEraser(event.localPosition);
      return;
    }

    if (_currentLinePoints == null) return;

    setState(() {
      // IMPORTANT: Create a NEW list instance to ensure CustomPainter detects the change
      // and repaints immediately during the drag.
      _currentLinePoints = [
        ..._currentLinePoints!,
        Point(
          event.localPosition.dx,
          event.localPosition.dy,
          pressure: event.pressure,
        ),
      ];
    });
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (widget.currentTool == DrawingTool.strokeEraser) {
      return;
    }

    if (_currentLinePoints == null || _currentLinePoints!.isEmpty) return;

    // Add the completed line to the sketch
    final currentSketch = widget.sketchNotifier.value;
    final newLine = SketchLine(
      points: _currentLinePoints!,
      color: widget.currentTool == DrawingTool.pixelEraser
          ? 0
          : widget.currentColor.value,
      width: widget.currentWidth,
    );

    widget.sketchNotifier.value = Sketch(
      lines: [...currentSketch.lines, newLine],
    );

    setState(() {
      _currentLinePoints = null;
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    setState(() {
      _currentLinePoints = null;
    });
  }

  void _handleStrokeEraser(Offset position) {
    final currentSketch = widget.sketchNotifier.value;
    final eraserRadius =
        widget.currentWidth * 2; // Eraser is slightly larger than stroke width

    final linesToRemove = <SketchLine>{};

    for (final line in currentSketch.lines) {
      if (_isLineHit(line, position, eraserRadius)) {
        linesToRemove.add(line);
      }
    }

    if (linesToRemove.isNotEmpty) {
      final newLines = currentSketch.lines
          .where((l) => !linesToRemove.contains(l))
          .toList();
      widget.sketchNotifier.value = Sketch(lines: newLines);
    }
  }

  bool _isLineHit(SketchLine line, Offset hitPoint, double radius) {
    if (line.points.isEmpty) return false;

    // Simple bounding box check first for performance
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final p in line.points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    // Expand bounds by radius
    if (hitPoint.dx < minX - radius ||
        hitPoint.dx > maxX + radius ||
        hitPoint.dy < minY - radius ||
        hitPoint.dy > maxY + radius) {
      return false;
    }

    // Detailed segment check
    for (int i = 0; i < line.points.length - 1; i++) {
      final p1 = Offset(line.points[i].x, line.points[i].y);
      final p2 = Offset(line.points[i + 1].x, line.points[i + 1].y);

      if (_distanceToSegment(hitPoint, p1, p2) <= radius) {
        return true;
      }
    }

    return false;
  }

  double _distanceToSegment(Offset p, Offset a, Offset b) {
    final pa = p - a;
    final ba = b - a;
    final h = (pa.dx * ba.dx + pa.dy * ba.dy) / (ba.dx * ba.dx + ba.dy * ba.dy);
    final clampedH = h.clamp(0.0, 1.0);
    final closest = a + ba * clampedH;
    return (p - closest).distance;
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      behavior: HitTestBehavior.opaque,
      child: ValueListenableBuilder<Sketch>(
        valueListenable: widget.sketchNotifier,
        builder: (context, sketch, _) {
          return CustomPaint(
            painter: FastSketchPainter(
              sketch: sketch,
              currentLinePoints: _currentLinePoints,
              currentColor: widget.currentColor,
              currentWidth: widget.currentWidth,
              currentTool: widget.currentTool,
            ),
            child: Container(),
          );
        },
      ),
    );
  }
}

class FastSketchPainter extends CustomPainter {
  final Sketch sketch;
  final List<Point>? currentLinePoints;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;

  FastSketchPainter({
    required this.sketch,
    this.currentLinePoints,
    required this.currentColor,
    required this.currentWidth,
    required this.currentTool,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Save layer to ensure blend modes work correctly within the canvas
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Draw all completed lines
    for (final line in sketch.lines) {
      _drawLine(canvas, line.points, Color(line.color), line.width);
    }

    // Draw current line being drawn
    if (currentLinePoints != null && currentLinePoints!.isNotEmpty) {
      _drawLine(
        canvas,
        currentLinePoints!,
        currentTool == DrawingTool.pixelEraser
            ? const Color(0x00000000)
            : currentColor,
        currentWidth,
        isEraserLine: currentTool == DrawingTool.pixelEraser,
      );
    }

    canvas.restore();
  }

  void _drawLine(
    Canvas canvas,
    List<Point> points,
    Color color,
    double width, {
    bool isEraserLine = false,
  }) {
    if (points.isEmpty) return;

    // Check if line is an eraser line (color 0) or explicitly marked
    final isEraser = isEraserLine || color.value == 0;

    final paint = Paint()
      ..color = isEraser ? Colors.black : color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

    if (points.length == 1) {
      // Single point - draw a dot
      final point = points[0];
      canvas.drawCircle(
        Offset(point.x, point.y),
        width / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      // Multiple points - draw path
      final path = Path();
      final firstPoint = points[0];
      path.moveTo(firstPoint.x, firstPoint.y);

      for (int i = 1; i < points.length; i++) {
        final point = points[i];
        path.lineTo(point.x, point.y);
      }

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(FastSketchPainter oldDelegate) {
    // Always repaint if current line points are present (dragging)
    // The list reference check might fail if we mutated in place, but we fixed that in State.
    // Still, safer to be explicit.
    if (currentLinePoints != null) return true;

    return oldDelegate.sketch != sketch ||
        oldDelegate.currentLinePoints != currentLinePoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentWidth != currentWidth ||
        oldDelegate.currentTool != currentTool;
  }
}
