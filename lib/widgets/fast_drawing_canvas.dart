import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';

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
  final ValueNotifier<List<Point>?> _currentLineNotifier = ValueNotifier(null);

  // Caching
  ui.Picture? _cachedSketchPicture;
  Sketch? _lastSketch;
  bool? _lastIsDark;

  // Selection State
  List<Offset>? _lassoPoints;
  Offset? _dragStart;
  Offset _currentDragOffset = Offset.zero;
  bool _isDraggingSelection = false;

  @override
  void dispose() {
    _currentLineNotifier.dispose();
    _cachedSketchPicture?.dispose();
    super.dispose();
  }

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

    _currentLineNotifier.value = [
      Point(
        event.localPosition.dx,
        event.localPosition.dy,
        pressure: event.pressure,
      ),
    ];
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

    if (_currentLineNotifier.value == null) return;

    // Optimize: Add to existing list instead of creating new one every move
    final points = _currentLineNotifier.value!;
    points.add(
      Point(
        event.localPosition.dx,
        event.localPosition.dy,
        pressure: event.pressure,
      ),
    );
    _currentLineNotifier.value = List.from(points);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (widget.currentTool == DrawingTool.strokeEraser) {
      return;
    }

    if (widget.currentTool == DrawingTool.selection) {
      _handleSelectionUp();
      return;
    }

    final currentLinePoints = _currentLineNotifier.value;
    if (currentLinePoints == null || currentLinePoints.isEmpty) return;

    // Add the completed line to the sketch
    final currentSketch = widget.sketchNotifier.value;
    final newLine = SketchLine(
      points: currentLinePoints,
      color: widget.currentTool == DrawingTool.pixelEraser
          ? 0
          : widget.currentColor.value,
      width: widget.currentWidth,
    );

    widget.sketchNotifier.value = Sketch(
      lines: [...currentSketch.lines, newLine],
    );

    _currentLineNotifier.value = null;
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _currentLineNotifier.value = null;
    setState(() {
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Invalidate cache if sketch or theme changed
    final sketch = widget.sketchNotifier.value;
    if (_lastSketch != sketch || _lastIsDark != isDark) {
      _cachedSketchPicture = null;
      _lastSketch = sketch;
      _lastIsDark = isDark;
    }

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
              return ValueListenableBuilder<List<Point>?>(
                valueListenable: _currentLineNotifier,
                builder: (context, currentLinePoints, _) {
                  return CustomPaint(
                    painter: FastSketchPainter(
                      sketch: sketch,
                      currentLinePoints: currentLinePoints,
                      currentColor: widget.currentColor,
                      currentWidth: widget.currentWidth,
                      currentTool: widget.currentTool,
                      selectedLines: selectedLines,
                      lassoPoints: _lassoPoints,
                      dragOffset: _currentDragOffset,
                      isDark: isDark,
                      cachedPicture: _cachedSketchPicture,
                      onCacheUpdate: (picture) {
                        _cachedSketchPicture = picture;
                      },
                    ),
                    child: Container(),
                  );
                },
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
  final bool isDark;

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
