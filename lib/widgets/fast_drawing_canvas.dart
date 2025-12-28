import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import 'fast_drawing_toolbar.dart'; // For DrawingTool enum

/// High-performance custom drawing widget that's compatible with Scribble's
/// Sketch format but uses raw Listener for immediate pointer event processing.
class FastDrawingCanvas extends StatefulWidget {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;

  const FastDrawingCanvas({
    super.key,
    required this.sketchNotifier,
    required this.selectionNotifier,
    this.currentColor = Colors.black,
    this.currentWidth = 2.0,
    this.currentTool = DrawingTool.pen,
  });

  @override
  State<FastDrawingCanvas> createState() => FastDrawingCanvasState();
}

class FastDrawingCanvasState extends State<FastDrawingCanvas> {
  List<Point>? _currentLinePoints;

  // Selection State
  List<Offset>? _lassoPoints;
  Offset? _dragStart;
  Offset _currentDragOffset = Offset.zero;
  bool _isDraggingSelection = false;

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

    if (widget.currentTool == DrawingTool.selection) {
      _handleSelectionDown(event.localPosition);
      return;
    }

    // Clear selection if drawing with other tools
    if (widget.selectionNotifier.value.isNotEmpty) {
      widget.selectionNotifier.value = [];
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

    if (widget.currentTool == DrawingTool.selection) {
      _handleSelectionMove(event.localPosition);
      return;
    }

    if (_currentLinePoints == null) return;

    setState(() {
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

    if (widget.currentTool == DrawingTool.selection) {
      _handleSelectionUp();
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
      _lassoPoints = null;
      _isDraggingSelection = false;
      _currentDragOffset = Offset.zero;
    });
  }

  // --- Selection Logic ---

  void _handleSelectionDown(Offset position) {
    final selectedLines = widget.selectionNotifier.value;

    // Check if tapping inside existing selection to start drag
    if (selectedLines.isNotEmpty &&
        _isPointInSelectionBounds(position, selectedLines)) {
      setState(() {
        _isDraggingSelection = true;
        _dragStart = position;
        _currentDragOffset = Offset.zero;
      });
    } else {
      // Start new lasso selection
      widget.selectionNotifier.value = []; // Clear previous
      setState(() {
        _lassoPoints = [position];
        _isDraggingSelection = false;
      });
    }
  }

  void _handleSelectionMove(Offset position) {
    if (_isDraggingSelection) {
      setState(() {
        _currentDragOffset = position - _dragStart!;
      });
    } else if (_lassoPoints != null) {
      setState(() {
        _lassoPoints = [..._lassoPoints!, position];
      });
    }
  }

  void _handleSelectionUp() {
    if (_isDraggingSelection) {
      // Apply move to selected lines
      _applyMoveToSelection();
      setState(() {
        _isDraggingSelection = false;
        _currentDragOffset = Offset.zero;
        _dragStart = null;
      });
    } else if (_lassoPoints != null) {
      // Close lasso and find selected lines
      _findSelectedLines();
      setState(() {
        _lassoPoints = null;
      });
    }
  }

  bool _isPointInSelectionBounds(Offset point, List<SketchLine> lines) {
    if (lines.isEmpty) return false;

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

    // Add some padding
    const padding = 20.0;
    return point.dx >= minX - padding &&
        point.dx <= maxX + padding &&
        point.dy >= minY - padding &&
        point.dy <= maxY + padding;
  }

  void _findSelectedLines() {
    if (_lassoPoints == null || _lassoPoints!.length < 3) return;

    final currentSketch = widget.sketchNotifier.value;
    final selected = <SketchLine>[];
    final path = Path()..addPolygon(_lassoPoints!, true);

    for (final line in currentSketch.lines) {
      // Check if any point of the line is inside the lasso polygon
      // For better performance, we could just check bounding box or first point
      // But checking all points ensures accuracy
      bool isSelected = false;
      for (final p in line.points) {
        if (path.contains(Offset(p.x, p.y))) {
          isSelected = true;
          break;
        }
      }
      if (isSelected) {
        selected.add(line);
      }
    }

    widget.selectionNotifier.value = selected;
  }

  void _applyMoveToSelection() {
    if (_currentDragOffset == Offset.zero) return;

    final currentSketch = widget.sketchNotifier.value;
    final selectedLines = widget.selectionNotifier.value;
    final selectedSet = selectedLines.toSet();

    final newLines = currentSketch.lines.map((line) {
      if (selectedSet.contains(line)) {
        // Move this line
        final newPoints = line.points
            .map(
              (p) => Point(
                p.x + _currentDragOffset.dx,
                p.y + _currentDragOffset.dy,
                pressure: p.pressure,
              ),
            )
            .toList();
        return line.copyWith(points: newPoints);
      }
      return line;
    }).toList();

    // Update sketch
    widget.sketchNotifier.value = Sketch(lines: newLines);

    // Update selection to point to new lines
    final newSelectedLines = <SketchLine>[];
    for (int i = 0; i < currentSketch.lines.length; i++) {
      if (selectedSet.contains(currentSketch.lines[i])) {
        newSelectedLines.add(newLines[i]);
      }
    }
    widget.selectionNotifier.value = newSelectedLines;
  }

  // --- Eraser Logic ---

  void _handleStrokeEraser(Offset position) {
    final currentSketch = widget.sketchNotifier.value;
    final eraserRadius = widget.currentWidth * 2;

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

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final p in line.points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }

    if (hitPoint.dx < minX - radius ||
        hitPoint.dx > maxX + radius ||
        hitPoint.dy < minY - radius ||
        hitPoint.dy > maxY + radius) {
      return false;
    }

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
          return ValueListenableBuilder<List<SketchLine>>(
            valueListenable: widget.selectionNotifier,
            builder: (context, selectedLines, _) {
              return CustomPaint(
                painter: FastSketchPainter(
                  sketch: sketch,
                  currentLinePoints: _currentLinePoints,
                  currentColor: widget.currentColor,
                  currentWidth: widget.currentWidth,
                  currentTool: widget.currentTool,
                  selectedLines: selectedLines,
                  lassoPoints: _lassoPoints,
                  dragOffset: _currentDragOffset,
                ),
                child: Container(),
              );
            },
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
  final List<SketchLine> selectedLines;
  final List<Offset>? lassoPoints;
  final Offset dragOffset;

  FastSketchPainter({
    required this.sketch,
    this.currentLinePoints,
    required this.currentColor,
    required this.currentWidth,
    required this.currentTool,
    this.selectedLines = const [],
    this.lassoPoints,
    this.dragOffset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final selectedSet = selectedLines.toSet();

    // Draw all completed lines
    for (final line in sketch.lines) {
      // If line is selected and being dragged, draw it at offset position
      if (selectedSet.contains(line)) {
        if (dragOffset != Offset.zero) {
          canvas.save();
          canvas.translate(dragOffset.dx, dragOffset.dy);
          _drawLine(canvas, line.points, Color(line.color), line.width);
          canvas.restore();
        } else {
          _drawLine(canvas, line.points, Color(line.color), line.width);
        }
      } else {
        _drawLine(canvas, line.points, Color(line.color), line.width);
      }
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

    // Draw Lasso
    if (lassoPoints != null && lassoPoints!.isNotEmpty) {
      final paint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke;

      final path = Path()..addPolygon(lassoPoints!, false);
      // Draw dashed line manually or just solid for now
      canvas.drawPath(path, paint);
    }

    // Draw Selection Bounds
    if (selectedLines.isNotEmpty) {
      _drawSelectionBounds(canvas, selectedLines);
    }

    canvas.restore();
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

    // Draw dashed rectangle
    _drawDashedRect(canvas, shiftedRect, paint);
  }

  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    // Simple dashed implementation
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

    final paint = Paint()
      ..color = isEraser ? Colors.black : color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..blendMode = isEraser ? BlendMode.clear : BlendMode.srcOver;

    if (points.length == 1) {
      final point = points[0];
      canvas.drawCircle(
        Offset(point.x, point.y),
        width / 2,
        paint..style = PaintingStyle.fill,
      );
    } else {
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
    if (currentLinePoints != null ||
        lassoPoints != null ||
        dragOffset != Offset.zero)
      return true;

    return oldDelegate.sketch != sketch ||
        oldDelegate.currentLinePoints != currentLinePoints ||
        oldDelegate.currentColor != currentColor ||
        oldDelegate.currentWidth != currentWidth ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.selectedLines != selectedLines ||
        oldDelegate.lassoPoints != lassoPoints ||
        oldDelegate.dragOffset != dragOffset;
  }
}
