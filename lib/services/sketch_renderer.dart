import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/grid_type.dart';

class SketchRenderer {
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
      // if (scale < 0.5) {
      //   paint.strokeWidth = width * 0.5;
      //   final path = Path();
      //   path.moveTo(points[0].x, points[0].y);
      //   for (int i = 1; i < points.length; i++) {
      //     path.lineTo(points[i].x, points[i].y);
      //   }
      //   canvas.drawPath(path, paint);
      // if zoom is 80% or less
      // } else if (scale < 0.8) {
      //   paint.strokeWidth = width * 0.8;
      //   final path = Path();
      //   path.moveTo(points[0].x, points[0].y);
      //   // Skip every other point to reduce drawing calls
      //   for (int i = 1; i < points.length; i += 2) {
      //     path.lineTo(points[i].x, points[i].y);
      //   }
      //   if (points.length > 1) {
      //     path.lineTo(points.last.x, points.last.y);
      //   }
      //   canvas.drawPath(path, paint);
      // } else {
      _drawSmoothLine(canvas, points, paint, width);
      // }
    }
  }

  void _drawSmoothLine(
    Canvas canvas,
    List<Point> points,
    Paint paint,
    double baseWidth,
  ) {
    if (points.length < 2) return;

    final vertices = <Offset>[];
    final indices = <int>[];

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final pressure = p.pressure;
      final radius = (baseWidth * (0.2 + pressure * 0.6)) / 2;

      // Calculate direction
      Offset dir;
      if (i == 0) {
        dir = Offset(points[1].x - p.x, points[1].y - p.y);
      } else if (i == points.length - 1) {
        dir = Offset(p.x - points[i - 1].x, p.y - points[i - 1].y);
      } else {
        // Average direction
        final prev = points[i - 1];
        final next = points[i + 1];
        dir = Offset(next.x - prev.x, next.y - prev.y);
      }

      final distance = dir.distance;
      if (distance == 0) {
        vertices.add(Offset(p.x, p.y));
        vertices.add(Offset(p.x, p.y));
        continue;
      }

      final normal = Offset(-dir.dy / distance, dir.dx / distance);

      vertices.add(Offset(p.x + normal.dx * radius, p.y + normal.dy * radius));
      vertices.add(Offset(p.x - normal.dx * radius, p.y - normal.dy * radius));
    }

    for (int i = 0; i < points.length - 1; i++) {
      final base = i * 2;
      indices.addAll([base, base + 1, base + 2, base + 1, base + 3, base + 2]);
    }

    final vertexMode = ui.VertexMode.triangles;
    final uiVertices = ui.Vertices(vertexMode, vertices, indices: indices);

    canvas.drawVertices(
      uiVertices,
      BlendMode.srcOver,
      paint..style = PaintingStyle.fill,
    );
  }

  ui.Picture renderSketch({
    required Sketch sketch,
    required bool isDark,
    required double scale,
    List<SketchLine> selectedLines = const [],
    bool skipSelectedLines = false,
  }) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    bool hasErasers = sketch.lines.any((l) => l.color == 0);

    if (hasErasers) {
      canvas.saveLayer(null, Paint());
    }

    final selectedSet = selectedLines.toSet();

    for (final line in sketch.lines) {
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

  Future<ui.Image> renderToImage(
    Sketch sketch, {
    required Size size,
    ui.Image? backgroundImage,
    Rect? backgroundRect,
    bool isDark = false,
    double sketchScale = 1.0,
    Offset offset = Offset.zero,
    double scale = 1.0,
    bool gridEnabled = false,
    GridType gridType = GridType.grid,
    double gridSpacing = 40.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Draw background color
    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF121212) : Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    // Draw grid
    if (gridEnabled) {
      final gridPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
        ..strokeWidth = 1.0 / scale; // Keep grid lines thin

      // Draw grid over a large enough area to cover the transformed view
      // For simplicity, we can just draw it based on the size and inverse transform
      // but here we can just draw a large enough grid or calculate bounds.
      // Let's just draw it relative to the content bounds if we have them,
      // or just a very large area.
      for (double x = -10000; x <= 10000; x += gridSpacing) {
        canvas.drawLine(Offset(x, -10000), Offset(x, 10000), gridPaint);
      }
      for (double y = -10000; y <= 10000; y += gridSpacing) {
        canvas.drawLine(Offset(-10000, y), Offset(10000, y), gridPaint);
      }
    }

    if (backgroundImage != null) {
      canvas.drawImageRect(
        backgroundImage,
        Rect.fromLTWH(
          0,
          0,
          backgroundImage.width.toDouble(),
          backgroundImage.height.toDouble(),
        ),
        backgroundRect ?? Rect.fromLTWH(0, 0, size.width, size.height),
        Paint(),
      );
    }

    if (sketchScale != 1.0) {
      canvas.save();
      canvas.scale(sketchScale);
    }

    final picture = renderSketch(sketch: sketch, isDark: isDark, scale: 1.0);
    canvas.drawPicture(picture);

    if (sketchScale != 1.0) {
      canvas.restore();
    }

    canvas.restore();

    final img = await recorder.endRecording().toImage(
      size.width.toInt(),
      size.height.toInt(),
    );
    return img;
  }
}
