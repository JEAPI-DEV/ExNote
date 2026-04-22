import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../../models/undo_action.dart';
import '../../utils/sketch_bounds.dart';

enum ResizeHandle {
  topLeft,
  topCenter,
  topRight,
  centerLeft,
  centerRight,
  bottomLeft,
  bottomCenter,
  bottomRight,
}

class ResizeHandler {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final void Function(UndoAction) onAction;
  final VoidCallback notifyListeners;
  final VoidCallback invalidateCache;

  ResizeHandle? _activeHandle;
  Rect? _resizeStartRect;
  Rect? _resizePreviewRect;
  List<SketchLine>? _resizeOriginalLines;
  List<SketchLine>? _resizePreviewLines;
  List<int>? _resizeSelectionIndices;

  bool get isResizingSelection => _activeHandle != null;

  Rect? get selectionBounds =>
      _resizePreviewRect ??
      _computeBounds(_resizePreviewLines ?? selectionNotifier.value);

  List<SketchLine> get selectionForPainting =>
      _resizePreviewLines ?? selectionNotifier.value;

  ResizeHandler({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
    required this.notifyListeners,
    required this.invalidateCache,
  });

  Rect? _computeBounds(List<SketchLine> lines) =>
      lines.isEmpty ? null : computeLineBounds(lines);

  ResizeHandle? hitTestHandle(Offset point, Rect bounds) {
    const handleSize = 16.0;

    final handles = {
      ResizeHandle.topLeft: Offset(bounds.left, bounds.top),
      ResizeHandle.topCenter: Offset(bounds.center.dx, bounds.top),
      ResizeHandle.topRight: Offset(bounds.right, bounds.top),
      ResizeHandle.centerLeft: Offset(bounds.left, bounds.center.dy),
      ResizeHandle.centerRight: Offset(bounds.right, bounds.center.dy),
      ResizeHandle.bottomLeft: Offset(bounds.left, bounds.bottom),
      ResizeHandle.bottomCenter: Offset(bounds.center.dx, bounds.bottom),
      ResizeHandle.bottomRight: Offset(bounds.right, bounds.bottom),
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

  void startResize(
    ResizeHandle handle,
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
    invalidateCache();
    notifyListeners();
  }

  void updatePreview(Offset position) {
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
      case ResizeHandle.topLeft:
        left = pointer.dx;
        top = pointer.dy;
      case ResizeHandle.topCenter:
        top = pointer.dy;
      case ResizeHandle.topRight:
        right = pointer.dx;
        top = pointer.dy;
      case ResizeHandle.centerLeft:
        left = pointer.dx;
      case ResizeHandle.centerRight:
        right = pointer.dx;
      case ResizeHandle.bottomLeft:
        left = pointer.dx;
        bottom = pointer.dy;
      case ResizeHandle.bottomCenter:
        bottom = pointer.dy;
      case ResizeHandle.bottomRight:
        right = pointer.dx;
        bottom = pointer.dy;
    }

    if ((right - left).abs() < minSize) {
      if (_activeHandle == ResizeHandle.topLeft ||
          _activeHandle == ResizeHandle.centerLeft ||
          _activeHandle == ResizeHandle.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }

    if ((bottom - top).abs() < minSize) {
      if (_activeHandle == ResizeHandle.topLeft ||
          _activeHandle == ResizeHandle.topCenter ||
          _activeHandle == ResizeHandle.topRight) {
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

  void commitResize() {
    if (_resizePreviewLines == null ||
        _resizeSelectionIndices == null ||
        _resizeOriginalLines == null) {
      resetState();
      return;
    }

    if (_resizeStartRect == _resizePreviewRect) {
      resetState();
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

    resetState();
    notifyListeners();
  }

  void resetState() {
    _activeHandle = null;
    _resizePreviewLines = null;
    _resizeOriginalLines = null;
    _resizePreviewRect = null;
    _resizeStartRect = null;
    _resizeSelectionIndices = null;
  }
}
