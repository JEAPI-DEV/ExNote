import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../controllers/drawing/resize_handler.dart';
import '../models/drawing_tool.dart';
import '../services/sketch_renderer.dart';

class StaticSketchPainter extends CustomPainter {
  final Sketch sketch;
  final bool isDark;
  final double scale;
  final List<SketchLine> selectedLines;
  final List<SketchLine>? selectedLinesToSkip;
  final bool isDraggingSelection;
  final bool isResizingSelection;
  final bool isRotatingSelection;

  // Caching
  final ui.Picture? cachedPicture;
  final Function(ui.Picture) onCacheUpdate;

  final SketchRenderer _renderer = SketchRenderer();

  StaticSketchPainter({
    required this.sketch,
    required this.isDark,
    required this.scale,
    this.selectedLines = const [],
    this.selectedLinesToSkip,
    this.isDraggingSelection = false,
    this.isResizingSelection = false,
    this.isRotatingSelection = false,
    this.cachedPicture,
    required this.onCacheUpdate,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (cachedPicture == null) {
      final picture = _renderer.renderSketch(
        sketch: sketch,
        isDark: isDark,
        scale: scale,
        selectedLines: selectedLinesToSkip ?? selectedLines,
        skipSelectedLines:
            isDraggingSelection || isResizingSelection || isRotatingSelection,
      );
      onCacheUpdate(picture);
      canvas.drawPicture(picture);
    } else {
      canvas.drawPicture(cachedPicture!);
    }
  }

  @override
  bool shouldRepaint(StaticSketchPainter oldDelegate) {
    return oldDelegate.sketch != sketch ||
        oldDelegate.isDark != isDark ||
        oldDelegate.scale != scale ||
        oldDelegate.selectedLines != selectedLines ||
        oldDelegate.selectedLinesToSkip != selectedLinesToSkip ||
        oldDelegate.isDraggingSelection != isDraggingSelection ||
        oldDelegate.isResizingSelection != isResizingSelection ||
        oldDelegate.isRotatingSelection != isRotatingSelection ||
        oldDelegate.cachedPicture != cachedPicture;
  }
}

class ActiveSketchPainter extends CustomPainter {
  final List<Point>? currentLinePoints;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;
  final List<SketchLine> selectedLines;
  final List<SketchLine>? previewLines;
  final List<Offset>? lassoPoints;
  final Offset dragOffset;
  final bool isDraggingSelection;
  final bool isResizingSelection;
  final bool isRotatingSelection;
  final bool isDark;
  final double scale;
  final Rect? selectionRect;
  final bool showHandles;
  final bool showRotationHandle;

  // Needed for pixel eraser masking
  final ui.Picture? cachedPicture;

  final SketchRenderer _renderer = SketchRenderer();

  ActiveSketchPainter({
    this.currentLinePoints,
    required this.currentColor,
    required this.currentWidth,
    required this.currentTool,
    this.selectedLines = const [],
    this.previewLines,
    this.lassoPoints,
    this.dragOffset = Offset.zero,
    this.isDraggingSelection = false,
    this.isResizingSelection = false,
    this.isRotatingSelection = false,
    this.isDark = false,
    this.scale = 1.0,
    this.selectionRect,
    this.showHandles = false,
    this.showRotationHandle = false,
    this.cachedPicture,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final linesToDraw = previewLines ?? selectedLines;

    // Draw dragged or resized lines
    if (isDraggingSelection ||
        dragOffset != Offset.zero ||
        isResizingSelection ||
        isRotatingSelection) {
      for (final line in linesToDraw) {
        canvas.save();
        canvas.translate(dragOffset.dx, dragOffset.dy);
        _renderer.drawLine(
          canvas,
          line.points,
          Color(line.color),
          line.width,
          isDark: isDark,
          scale: scale,
        );
        canvas.restore();
      }
    }

    // Draw current line being drawn
    if (currentLinePoints != null && currentLinePoints!.isNotEmpty) {
      final isPixelEraser = currentTool == DrawingTool.pixelEraser;
      if (isPixelEraser) {
        canvas.saveLayer(
          _lineBounds(
            currentLinePoints!,
            currentWidth,
          ).intersect(Offset.zero & size),
          Paint(),
        );
        if (cachedPicture != null) {
          canvas.drawPicture(cachedPicture!);
        }
      }

      _renderer.drawLine(
        canvas,
        currentLinePoints!,
        isPixelEraser ? const Color(0x00000000) : currentColor,
        currentWidth,
        isEraserLine: isPixelEraser,
        isDark: isDark,
        scale: scale,
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
    if (selectionRect != null) {
      _drawSelectionBounds(canvas, selectionRect!);
    }
  }

  Rect _lineBounds(List<Point> points, double width) {
    double minX = double.infinity;
    double minY = double.infinity;
    double maxX = double.negativeInfinity;
    double maxY = double.negativeInfinity;

    for (final point in points) {
      if (point.x < minX) minX = point.x;
      if (point.y < minY) minY = point.y;
      if (point.x > maxX) maxX = point.x;
      if (point.y > maxY) maxY = point.y;
    }

    return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(width * 2);
  }

  void _drawSelectionBounds(Canvas canvas, Rect rect) {
    final shiftedRect = rect.shift(dragOffset);

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    _drawDashedRect(canvas, shiftedRect, paint);

    if (showHandles) {
      _drawHandles(canvas, shiftedRect);
    }

    if (showRotationHandle) {
      _drawRotationHandle(canvas, shiftedRect);
    }
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

  void _drawHandles(Canvas canvas, Rect rect) {
    const double size = 10.0;
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;

    final handles = [
      rect.topLeft,
      Offset(rect.center.dx, rect.top),
      rect.topRight,
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
      rect.bottomLeft,
      Offset(rect.center.dx, rect.bottom),
      rect.bottomRight,
    ];

    for (final center in handles) {
      canvas.drawRect(
        Rect.fromCenter(center: center, width: size, height: size),
        handlePaint,
      );
    }
  }

  void _drawRotationHandle(Canvas canvas, Rect rect) {
    const double handleRadius = 6.0;

    final connectorPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final handlePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];
    final handles = ResizeHandler.rotationHandleCenters(rect);

    for (int i = 0; i < handles.length; i++) {
      canvas.drawLine(corners[i], handles[i], connectorPaint);
      canvas.drawCircle(handles[i], handleRadius, handlePaint);
    }
  }

  @override
  bool shouldRepaint(ActiveSketchPainter oldDelegate) {
    return oldDelegate.currentLinePoints != currentLinePoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentWidth != currentWidth ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.selectedLines != selectedLines ||
        oldDelegate.previewLines != previewLines ||
        oldDelegate.lassoPoints != lassoPoints ||
        oldDelegate.dragOffset != dragOffset ||
        oldDelegate.isDraggingSelection != isDraggingSelection ||
        oldDelegate.isResizingSelection != isResizingSelection ||
        oldDelegate.isRotatingSelection != isRotatingSelection ||
        oldDelegate.selectionRect != selectionRect ||
        oldDelegate.showHandles != showHandles ||
        oldDelegate.showRotationHandle != showRotationHandle ||
        oldDelegate.isDark != isDark ||
        oldDelegate.scale != scale ||
        oldDelegate.cachedPicture != cachedPicture;
  }
}
