import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';

class FastSketchPainter extends CustomPainter {
  final Sketch sketch;
  final List<Point>? currentLinePoints;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;
  final List<SketchLine> selectedLines;
  final List<Offset>? lassoPoints;
  final Offset dragOffset;
  final bool isDark;
  final double scale;

  // Caching
  final ui.Picture? cachedPicture;
  final Function(ui.Picture) onCacheUpdate;

  FastSketchPainter({
    required this.sketch,
    this.currentLinePoints,
    required this.currentColor,
    required this.currentWidth,
    required this.currentTool,
    this.selectedLines = const [],
    this.lassoPoints,
    this.dragOffset = Offset.zero,
    this.isDark = false,
    this.scale = 1.0,
    this.cachedPicture,
    required this.onCacheUpdate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw cached sketch
    if (cachedPicture == null) {
      final recorder = ui.PictureRecorder();
      final recordingCanvas = Canvas(recorder);
      _drawSketch(recordingCanvas, size);
      final picture = recorder.endRecording();
      onCacheUpdate(picture);
      canvas.drawPicture(picture);
    } else {
      canvas.drawPicture(cachedPicture!);
    }

    // Draw active elements (current line, lasso, selection)
    _drawActiveElements(canvas, size);
  }

  void _drawSketch(Canvas canvas, Size size) {
    final selectedSet = selectedLines.toSet();

    // We only need saveLayer if there are erasers in the sketch
    bool hasErasers = sketch.lines.any((l) => l.color == 0);
    if (hasErasers) {
      canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    }

    for (final line in sketch.lines) {
      // If line is selected and being dragged, don't draw it in the cache
      if (selectedSet.contains(line) && dragOffset != Offset.zero) {
        continue;
      }
      _drawLine(canvas, line.points, Color(line.color), line.width);
    }

    if (hasErasers) {
      canvas.restore();
    }
  }

  void _drawActiveElements(Canvas canvas, Size size) {
    // Draw dragged lines
    if (dragOffset != Offset.zero) {
      for (final line in selectedLines) {
        canvas.save();
        canvas.translate(dragOffset.dx, dragOffset.dy);
        _drawLine(canvas, line.points, Color(line.color), line.width);
        canvas.restore();
      }
    }

    // Draw current line being drawn
    if (currentLinePoints != null && currentLinePoints!.isNotEmpty) {
      final isPixelEraser = currentTool == DrawingTool.pixelEraser;
      if (isPixelEraser) {
        canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
        if (cachedPicture != null) {
          canvas.drawPicture(cachedPicture!);
        }
      }

      _drawLine(
        canvas,
        currentLinePoints!,
        isPixelEraser ? const Color(0x00000000) : currentColor,
        currentWidth,
        isEraserLine: isPixelEraser,
      );

      if (isPixelEraser) {
        canvas.restore();
      }
    }

    // Draw Lasso
    if (lassoPoints != null && lassoPoints!.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final path = Path()..addPolygon(lassoPoints!, false);
      canvas.drawPath(path, paint);
    }

    // Draw Selection Bounds
    if (selectedLines.isNotEmpty) {
      _drawSelectionBounds(canvas, selectedLines);
    }
  }

  void _drawSelectionBounds(Canvas canvas, List<SketchLine> lines) {
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final line in lines) {
      for (final p in line.points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }

    if (minX == double.infinity) return;

    final rect = Rect.fromLTRB(minX, minY, maxX, maxY);
    final shiftedRect = rect.shift(dragOffset);

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, shiftedRect, paint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double distance = 0.0;

    for (final metric in path.computeMetrics()) {
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dashWidth),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  void _drawLine(
    Canvas canvas,
    List<Point> points,
    Color color,
    double width, {
    bool isEraserLine = false,
  }) {
    if (points.isEmpty) return;

    final isEraser = isEraserLine || color.value == 0;

    // Smart Color Inversion
    Color drawColor = color;
    if (!isEraser) {
      if (isDark && color.value == Colors.black.value) {
        drawColor = Colors.white;
      } else if (!isDark && color.value == Colors.white.value) {
        drawColor = Colors.black;
      }
    }

    final paint = Paint()
      ..color = isEraser ? Colors.black : drawColor
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

    if (points.length == 1) {
      final point = points[0];
      final pressure = point.pressure;
      final currentWidth = width * (0.4 + pressure * 0.6);
      canvas.drawCircle(
        Offset(point.x, point.y),
        currentWidth / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
      // Optimization: At low zoom levels, pressure variations are not visible.
      // Using drawPath is significantly faster than segment-by-segment drawing.
      if (scale < 0.5) {
        paint.strokeWidth = width * 0.7; // Use a fixed average width
        final path = Path();
        path.moveTo(points[0].x, points[0].y);
        for (int i = 1; i < points.length; i++) {
          path.lineTo(points[i].x, points[i].y);
        }
        canvas.drawPath(path, paint);
      } else {
        for (int i = 0; i < points.length - 1; i++) {
          final p1 = points[i];
          final p2 = points[i + 1];

          // Average pressure for the segment
          final pressure = (p1.pressure + p2.pressure) / 2;
          final currentWidth = width * (0.2 + pressure * 0.6);

          paint.strokeWidth = currentWidth;
          canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(FastSketchPainter oldDelegate) {
    return oldDelegate.sketch != sketch ||
        oldDelegate.currentLinePoints != currentLinePoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentWidth != currentWidth ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.selectedLines != selectedLines ||
        oldDelegate.lassoPoints != lassoPoints ||
        oldDelegate.dragOffset != dragOffset ||
        oldDelegate.isDark != isDark ||
        oldDelegate.cachedPicture != cachedPicture;
  }
}
