import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';

enum _ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class DrawingCanvasController extends ChangeNotifier {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Function(UndoAction) onAction;

  // Configuration
  Color currentColor = Colors.black;
  double currentWidth = 2.0;
  DrawingTool currentTool = DrawingTool.pen;

  double _scale = 1.0;
  double get scale => _scale;
  set scale(double value) {
    if (_scale == value) return;
    final oldLod = _getLodLevel(_scale);
    final newLod = _getLodLevel(value);
    _scale = value;

    if (oldLod != newLod) {
      _invalidateCache();
      notifyListeners();
    }
  }

  bool isDark = false;

  int _getLodLevel(double s) {
    if (s < 0.5) return 0;
    if (s < 0.8) return 1;
    return 2;
  }

  // Transient State
  final ValueNotifier<List<Point>?> currentLineNotifier = ValueNotifier(null);
  List<Offset>? lassoPoints;
  Offset? dragStart;
  Offset currentDragOffset = Offset.zero;
  bool isDraggingSelection = false;
  bool isResizingSelection = false;

  // Resize helpers
  _ResizeHandle? _activeHandle;
  Rect? _resizeStartRect;
  Rect? _resizePreviewRect;
  List<SketchLine>? _resizeOriginalLines;
  List<SketchLine>? _resizePreviewLines;
  List<int>? _resizeSelectionIndices;

  // Eraser State
  final Set<SketchLine> _erasedLinesInSession = {};
  final List<int> _erasedIndicesInSession = [];
  List<SketchLine>? _initialLinesInSession;

  // Cache
  ui.Picture? cachedSketchPicture;
  final Map<SketchLine, Rect> _lineBoundsCache = {};

  DrawingCanvasController({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
  }) {
    sketchNotifier.addListener(_onSketchChanged);
  }

  @override
  void dispose() {
    sketchNotifier.removeListener(_onSketchChanged);
    currentLineNotifier.dispose();
    cachedSketchPicture?.dispose();
    super.dispose();
  }

  void _onSketchChanged() {
    // Always invalidate cache on sketch change to prevent picture nesting depth issues.
    // While incremental updates are faster for a single frame, they create a chain of
    // nested pictures that degrades performance over time (O(N) depth).
    // Since we use RepaintBoundary for the static layer, the cost of redrawing the
    // full sketch on PointerUp is acceptable and keeps the rendering tree flat.
    _invalidateCache();

    // We don't notifyListeners here because the widget listens to sketchNotifier
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

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
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

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      _handleSelectionMove(event.localPosition);
      return;
    }

    if (currentLineNotifier.value == null) return;

    final points = currentLineNotifier.value!;
    if (points.isEmpty) return;

    final lastPoint = points.last;
    final currentPoint = Point(
      event.localPosition.dx,
      event.localPosition.dy,
      pressure: event.pressure,
    );

    // Calculate distance in canvas coordinates
    final dx = currentPoint.x - lastPoint.x;
    final dy = currentPoint.y - lastPoint.y;
    final distance = math.sqrt(dx * dx + dy * dy);

    // Interpolate points if the distance in screen coordinates is too large.
    // This ensures high quality drawing even when zoomed out.
    final screenDistance = distance * _scale;
    const double kThreshold = 2.0; // 2 screen pixels

    if (screenDistance > kThreshold) {
      final int steps = (screenDistance / kThreshold).floor();
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        points.add(
          Point(
            lastPoint.x + dx * t,
            lastPoint.y + dy * t,
            pressure:
                lastPoint.pressure +
                (currentPoint.pressure - lastPoint.pressure) * t,
          ),
        );
      }
    }

    points.add(currentPoint);
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

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
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
    isResizingSelection = false;
    currentDragOffset = Offset.zero;
    _activeHandle = null;
    _resizePreviewLines = null;
    _resizeOriginalLines = null;
    _resizePreviewRect = null;
    _resizeStartRect = null;
    _resizeSelectionIndices = null;
    _initialLinesInSession = null;
    notifyListeners();
  }

  // --- Selection Logic ---

  void _handleSelectionDown(Offset position) {
    final selectedLines = selectionNotifier.value;
    final bounds = _computeSelectionBounds(selectedLines);

    if (currentTool == DrawingTool.editSelection &&
        selectedLines.isNotEmpty &&
        bounds != null) {
      final handle = _hitTestHandle(position, bounds);
      if (handle != null) {
        _startResize(handle, bounds, selectedLines);
        return;
      }
    }

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
      isResizingSelection = false;
      _activeHandle = null;
      notifyListeners();
    }
  }

  void _handleSelectionMove(Offset position) {
    if (isDraggingSelection) {
      currentDragOffset = position - dragStart!;
      notifyListeners();
    } else if (isResizingSelection &&
        _activeHandle != null &&
        _resizeStartRect != null &&
        _resizeOriginalLines != null) {
      _updateResizePreview(position);
    } else if (lassoPoints != null) {
      lassoPoints = [...lassoPoints!, position];
      notifyListeners();
    }
  }

  void _handleSelectionUp() {
    if (isDraggingSelection) {
      _applyMoveToSelection();
      isDraggingSelection = false;
      currentDragOffset = Offset.zero;
      dragStart = null;
      notifyListeners();
    } else if (isResizingSelection &&
        _resizePreviewLines != null &&
        _resizeSelectionIndices != null &&
        _resizeOriginalLines != null) {
      _commitResize();
    } else if (lassoPoints != null) {
      _findSelectedLines();
      lassoPoints = null;
      notifyListeners();
    }
  }

  Rect? _computeSelectionBounds(List<SketchLine> lines) {
    if (lines.isEmpty) return null;

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

    if (minX == double.infinity) return null;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  Rect? get selectionBounds =>
      _resizePreviewRect ??
      _computeSelectionBounds(_resizePreviewLines ?? selectionNotifier.value);

  List<SketchLine> get selectionForPainting =>
      _resizePreviewLines ?? selectionNotifier.value;

  bool _isPointInSelectionBounds(Offset point, List<SketchLine> lines) {
    final rect = _computeSelectionBounds(lines);
    if (rect == null) return false;

    const padding = 20.0;
    final padded = rect.inflate(padding);
    return padded.contains(point);
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

  void _startResize(
    _ResizeHandle handle,
    Rect bounds,
    List<SketchLine> selectedLines,
  ) {
    final sketch = sketchNotifier.value;
    final selectedSet = selectedLines.toSet();
    final indices = <int>[];
    final originals = <SketchLine>[];

    for (int i = 0; i < sketch.lines.length; i++) {
      if (selectedSet.contains(sketch.lines[i])) {
        indices.add(i);
        originals.add(sketch.lines[i]);
      }
    }

    _resizeSelectionIndices = indices;
    _resizeOriginalLines = originals
        .map(
          (line) => line.copyWith(
            points: line.points
                .map((p) => Point(p.x, p.y, pressure: p.pressure))
                .toList(),
          ),
        )
        .toList();
    _resizePreviewLines = _resizeOriginalLines
        ?.map(
          (line) => line.copyWith(
            points: line.points
                .map((p) => Point(p.x, p.y, pressure: p.pressure))
                .toList(),
          ),
        )
        .toList();
    _resizeStartRect = bounds;
    _resizePreviewRect = bounds;
    _activeHandle = handle;
    isResizingSelection = true;
    dragStart = null;
    currentDragOffset = Offset.zero;
    _invalidateCache();
    notifyListeners();
  }

  void _updateResizePreview(Offset position) {
    if (_activeHandle == null ||
        _resizeStartRect == null ||
        _resizeOriginalLines == null)
      return;

    final newRect = _computeResizedRect(position);
    _resizePreviewRect = newRect;
    _resizePreviewLines = _applyResizeToLines(
      _resizeOriginalLines!,
      _resizeStartRect!,
      newRect,
    );
    notifyListeners();
  }

  Rect _computeResizedRect(Offset pointer) {
    double left = _resizeStartRect!.left;
    double right = _resizeStartRect!.right;
    double top = _resizeStartRect!.top;
    double bottom = _resizeStartRect!.bottom;
    const minSize = 8.0;

    switch (_activeHandle!) {
      case _ResizeHandle.topLeft:
        left = pointer.dx;
        top = pointer.dy;
        break;
      case _ResizeHandle.topCenter:
        top = pointer.dy;
        break;
      case _ResizeHandle.topRight:
        right = pointer.dx;
        top = pointer.dy;
        break;
      case _ResizeHandle.centerLeft:
        left = pointer.dx;
        break;
      case _ResizeHandle.centerRight:
        right = pointer.dx;
        break;
      case _ResizeHandle.bottomLeft:
        left = pointer.dx;
        bottom = pointer.dy;
        break;
      case _ResizeHandle.bottomCenter:
        bottom = pointer.dy;
        break;
      case _ResizeHandle.bottomRight:
        right = pointer.dx;
        bottom = pointer.dy;
        break;
    }

    if ((right - left).abs() < minSize) {
      if (_activeHandle == _ResizeHandle.topLeft ||
          _activeHandle == _ResizeHandle.centerLeft ||
          _activeHandle == _ResizeHandle.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }

    if ((bottom - top).abs() < minSize) {
      if (_activeHandle == _ResizeHandle.topLeft ||
          _activeHandle == _ResizeHandle.topCenter ||
          _activeHandle == _ResizeHandle.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    if (left > right) {
      final temp = left;
      left = right;
      right = temp;
    }

    if (top > bottom) {
      final temp = top;
      top = bottom;
      bottom = temp;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  List<SketchLine> _applyResizeToLines(
    List<SketchLine> lines,
    Rect from,
    Rect to,
  ) {
    final width = from.width == 0 ? 0.0001 : from.width;
    final height = from.height == 0 ? 0.0001 : from.height;

    return lines
        .map(
          (line) => line.copyWith(
            points: line.points
                .map(
                  (p) => Point(
                    to.left + ((p.x - from.left) / width) * to.width,
                    to.top + ((p.y - from.top) / height) * to.height,
                    pressure: p.pressure,
                  ),
                )
                .toList(),
          ),
        )
        .toList();
  }

  void _commitResize() {
    if (_resizePreviewLines == null ||
        _resizeSelectionIndices == null ||
        _resizeOriginalLines == null) {
      _resetResizeState();
      return;
    }

    if (_resizeStartRect == _resizePreviewRect) {
      _resetResizeState();
      notifyListeners();
      return;
    }

    final sketch = sketchNotifier.value;
    final updatedLines = [...sketch.lines];

    for (int i = 0; i < _resizeSelectionIndices!.length; i++) {
      updatedLines[_resizeSelectionIndices![i]] = _resizePreviewLines![i];
    }

    sketchNotifier.value = Sketch(lines: updatedLines);
    selectionNotifier.value = _resizePreviewLines!;

    onAction(
      TransformLinesAction(
        _resizeOriginalLines!,
        _resizePreviewLines!,
        _resizeSelectionIndices!,
      ),
    );

    _resetResizeState();
    notifyListeners();
  }

  void _resetResizeState() {
    isResizingSelection = false;
    _activeHandle = null;
    _resizePreviewLines = null;
    _resizeOriginalLines = null;
    _resizePreviewRect = null;
    _resizeStartRect = null;
    _resizeSelectionIndices = null;
  }

  _ResizeHandle? _hitTestHandle(Offset point, Rect bounds) {
    const handleSize = 16.0;

    final handles = {
      _ResizeHandle.topLeft: Offset(bounds.left, bounds.top),
      _ResizeHandle.topCenter: Offset(bounds.center.dx, bounds.top),
      _ResizeHandle.topRight: Offset(bounds.right, bounds.top),
      _ResizeHandle.centerLeft: Offset(bounds.left, bounds.center.dy),
      _ResizeHandle.centerRight: Offset(bounds.right, bounds.center.dy),
      _ResizeHandle.bottomLeft: Offset(bounds.left, bounds.bottom),
      _ResizeHandle.bottomCenter: Offset(bounds.center.dx, bounds.bottom),
      _ResizeHandle.bottomRight: Offset(bounds.right, bounds.bottom),
    };

    for (final entry in handles.entries) {
      final rect = Rect.fromCenter(
        center: entry.value,
        width: handleSize,
        height: handleSize,
      );
      if (rect.contains(point)) {
        return entry.key;
      }
    }

    return null;
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
