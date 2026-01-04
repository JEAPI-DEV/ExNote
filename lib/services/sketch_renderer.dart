import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

class SketchRenderer {
  /// Draws a single line on the canvas.
  void drawLine(
    Canvas canvas,
    List<Point> points,
    Color color,
    double width, {
    bool isEraserLine = false,
    bool isDark = false,
    double scale = 1.0,
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

  /// Renders the sketch into a Picture.
  ui.Picture renderSketch({
    required Sketch sketch,
    required bool isDark,
    required double scale,
    List<SketchLine> selectedLines = const [],
    bool skipSelectedLines = false,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // We only need saveLayer if there are erasers in the sketch
    bool hasErasers = sketch.lines.any((l) => l.color == 0);

    if (hasErasers) {
      canvas.saveLayer(null, Paint());
    }

    final selectedSet = selectedLines.toSet();

    for (final line in sketch.lines) {
      // If line is selected and we should skip it (e.g. being dragged), don't draw it in the cache
      if (selectedSet.contains(line) && skipSelectedLines) {
        continue;
      }
      drawLine(
        canvas,
        line.points,
        Color(line.color),
        line.width,
        isDark: isDark,
        scale: scale,
      );
    }

    if (hasErasers) {
      canvas.restore();
    }

    return recorder.endRecording();
  }
}
