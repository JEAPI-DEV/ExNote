import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import '../services/sketch_renderer.dart';

class DrawingCanvasController extends ChangeNotifier {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Function(UndoAction) onAction;

  // Configuration
  Color currentColor = Colors.black;
  double currentWidth = 2.0;
  DrawingTool currentTool = DrawingTool.pen;
  double scale = 1.0;
  bool isDark = false;

  // Transient State
  final ValueNotifier<List<Point>?> currentLineNotifier = ValueNotifier(null);
  List<Offset>? lassoPoints;
  Offset? dragStart;
  Offset currentDragOffset = Offset.zero;
  bool isDraggingSelection = false;

  // Eraser State
  final Set<SketchLine> _erasedLinesInSession = {};
  final List<int> _erasedIndicesInSession = [];
  List<SketchLine>? _initialLinesInSession;

  // Cache
  ui.Picture? cachedSketchPicture;
  final Map<SketchLine, Rect> _lineBoundsCache = {};
  final SketchRenderer _renderer = SketchRenderer();
  Sketch? _lastSketch;

  DrawingCanvasController({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
  }) {
    sketchNotifier.addListener(_onSketchChanged);
    _lastSketch = sketchNotifier.value;
  }

  @override
  void dispose() {
    sketchNotifier.removeListener(_onSketchChanged);
    currentLineNotifier.dispose();
    cachedSketchPicture?.dispose();
    super.dispose();
  }

  void _onSketchChanged() {
    final newSketch = sketchNotifier.value;

    // Check for incremental update (append)
    if (_canIncrementalUpdate(_lastSketch, newSketch)) {
      _incrementalUpdate(newSketch.lines.last);
    } else {
      _invalidateCache();
    }
    _lastSketch = newSketch;
    // We don't notifyListeners here because the widget listens to sketchNotifier
  }

  bool _canIncrementalUpdate(Sketch? oldSketch, Sketch newSketch) {
    if (oldSketch == null || cachedSketchPicture == null) return false;
    // Only support incremental update if one line was added
    if (newSketch.lines.length != oldSketch.lines.length + 1) return false;

    // Verify prefix matches (optimization: just check length and assume append for now)
    // A safer check would be:
    // if (newSketch.lines.sublist(0, oldSketch.lines.length) != oldSketch.lines) return false;
    // But list comparison is expensive.
    // Given Scribble architecture, it's usually safe.
    return true;
  }

  void _incrementalUpdate(SketchLine newLine) {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (cachedSketchPicture != null) {
      canvas.drawPicture(cachedSketchPicture!);
    }
    _renderer.drawLine(
      canvas,
      newLine.points,
      Color(newLine.color),
      newLine.width,
      isDark: isDark,
      scale: scale,
    );
    cachedSketchPicture = recorder.endRecording();
  }

  void updateTheme(bool newIsDark) {
    if (isDark != newIsDark) {
      isDark = newIsDark;
      _invalidateCache();
      notifyListeners();
    }
  }

  void _invalidateCache() {
    cachedSketchPicture?.dispose();
    cachedSketchPicture = null;
  }

  void updateCache(ui.Picture picture) {
    cachedSketchPicture = picture;
  }

  // --- Input Handling ---

  void handlePointerDown(PointerDownEvent event) {
    // Only handle stylus/pen events
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (currentTool == DrawingTool.strokeEraser) {
      _initialLinesInSession = List.from(sketchNotifier.value.lines);
      _handleStrokeEraser(event.localPosition);
      return;
    }

    if (currentTool == DrawingTool.selection) {
      _handleSelectionDown(event.localPosition);
      return;
    }

    // Clear selection if drawing with other tools
    if (selectionNotifier.value.isNotEmpty) {
      selectionNotifier.value = [];
    }

    currentLineNotifier.value = [
      Point(
        event.localPosition.dx,
        event.localPosition.dy,
        pressure: event.pressure,
      ),
    ];
  }

  void handlePointerMove(PointerMoveEvent event) {
    // Only handle stylus/pen events
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (currentTool == DrawingTool.strokeEraser) {
      _handleStrokeEraser(event.localPosition);
      return;
    }

    if (currentTool == DrawingTool.selection) {
      _handleSelectionMove(event.localPosition);
      return;
    }

    if (currentLineNotifier.value == null) return;

    // Optimize: Add to existing list instead of creating new one every move
    final points = currentLineNotifier.value!;
    points.add(
      Point(
        event.localPosition.dx,
        event.localPosition.dy,
        pressure: event.pressure,
      ),
    );
    currentLineNotifier.value = List.from(points);
  }

  void handlePointerUp(PointerUpEvent event) {
    if (currentTool == DrawingTool.strokeEraser) {
      if (_erasedLinesInSession.isNotEmpty) {
        onAction(
          RemoveLinesAction(
            _erasedLinesInSession.toList(),
            _erasedIndicesInSession.toList(),
          ),
        );
        _erasedLinesInSession.clear();
        _erasedIndicesInSession.clear();
        _initialLinesInSession = null;
      }
      return;
    }

    if (currentTool == DrawingTool.selection) {
      _handleSelectionUp();
      return;
    }

    final currentLinePoints = currentLineNotifier.value;
    if (currentLinePoints == null || currentLinePoints.isEmpty) return;

    // Add the completed line to the sketch
    final currentSketch = sketchNotifier.value;
    final newLine = SketchLine(
      points: currentLinePoints,
      color: currentTool == DrawingTool.pixelEraser ? 0 : currentColor.value,
      width: currentWidth,
    );

    sketchNotifier.value = Sketch(lines: [...currentSketch.lines, newLine]);
    onAction(AddLinesAction([newLine]));

    currentLineNotifier.value = null;
  }

  void handlePointerCancel(PointerCancelEvent event) {
    currentLineNotifier.value = null;
    lassoPoints = null;
    isDraggingSelection = false;
    currentDragOffset = Offset.zero;
    _initialLinesInSession = null;
    notifyListeners();
  }

  // --- Selection Logic ---

  void _handleSelectionDown(Offset position) {
    final selectedLines = selectionNotifier.value;

    // Check if tapping inside existing selection to start drag
    if (selectedLines.isNotEmpty &&
        _isPointInSelectionBounds(position, selectedLines)) {
      isDraggingSelection = true;
      dragStart = position;
      currentDragOffset = Offset.zero;
      _invalidateCache(); // Invalidate to hide selected lines in static sketch
      notifyListeners();
    } else {
      // Start new lasso selection
      selectionNotifier.value = []; // Clear previous
      lassoPoints = [position];
      isDraggingSelection = false;
      notifyListeners();
    }
  }

  void _handleSelectionMove(Offset position) {
    if (isDraggingSelection) {
      currentDragOffset = position - dragStart!;
      notifyListeners();
    } else if (lassoPoints != null) {
      lassoPoints = [...lassoPoints!, position];
      notifyListeners();
    }
  }

  void _handleSelectionUp() {
    if (isDraggingSelection) {
      // Apply move to selected lines
      _applyMoveToSelection();
      isDraggingSelection = false;
      currentDragOffset = Offset.zero;
      dragStart = null;
      notifyListeners();
    } else if (lassoPoints != null) {
      // Close lasso and find selected lines
      _findSelectedLines();
      lassoPoints = null;
      notifyListeners();
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
    if (lassoPoints == null || lassoPoints!.length < 3) return;

    final currentSketch = sketchNotifier.value;
    final selected = <SketchLine>[];
    final path = Path()..addPolygon(lassoPoints!, true);

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

    selectionNotifier.value = selected;
  }

  void _applyMoveToSelection() {
    if (currentDragOffset == Offset.zero) return;

    final currentSketch = sketchNotifier.value;
    final selectedLines = selectionNotifier.value;
    final selectedSet = selectedLines.toSet();

    final newLines = currentSketch.lines.map((line) {
      if (selectedSet.contains(line)) {
        // Move this line
        final newPoints = line.points
            .map(
              (p) => Point(
                p.x + currentDragOffset.dx,
                p.y + currentDragOffset.dy,
                pressure: p.pressure,
              ),
            )
            .toList();
        return line.copyWith(points: newPoints);
      }
      return line;
    }).toList();

    // Update sketch
    sketchNotifier.value = Sketch(lines: newLines);

    // Update selection to point to new lines
    final newSelectedLines = <SketchLine>[];
    final oldSelectedLines = <SketchLine>[];
    final indices = <int>[];

    for (int i = 0; i < currentSketch.lines.length; i++) {
      if (selectedSet.contains(currentSketch.lines[i])) {
        newSelectedLines.add(newLines[i]);
        oldSelectedLines.add(currentSketch.lines[i]);
        indices.add(i);
      }
    }
    selectionNotifier.value = newSelectedLines;
    onAction(MoveLinesAction(oldSelectedLines, newSelectedLines, indices));
  }

  // --- Eraser Logic ---

  void _handleStrokeEraser(Offset position) {
    final currentSketch = sketchNotifier.value;
    final eraserRadius = currentWidth * 2;

    final linesToRemove = <SketchLine>{};

    for (final line in currentSketch.lines) {
      if (_isLineHit(line, position, eraserRadius)) {
        linesToRemove.add(line);
      }
    }

    if (linesToRemove.isNotEmpty) {
      for (final line in linesToRemove) {
        if (!_erasedLinesInSession.contains(line)) {
          _erasedLinesInSession.add(line);
          final index =
              _initialLinesInSession?.indexOf(line) ??
              currentSketch.lines.indexOf(line);
          _erasedIndicesInSession.add(index);
        }
      }

      final newLines = currentSketch.lines
          .where((l) => !linesToRemove.contains(l))
          .toList();
      sketchNotifier.value = Sketch(lines: newLines);
    }
  }

  bool _isLineHit(SketchLine line, Offset hitPoint, double radius) {
    if (line.points.isEmpty) return false;

    final bounds = _lineBoundsCache.putIfAbsent(line, () {
      double minX = double.infinity, maxX = double.negativeInfinity;
      double minY = double.infinity, maxY = double.negativeInfinity;

      for (final p in line.points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY);
    });

    if (hitPoint.dx < bounds.left - radius ||
        hitPoint.dx > bounds.right + radius ||
        hitPoint.dy < bounds.top - radius ||
        hitPoint.dy > bounds.bottom + radius) {
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
}
