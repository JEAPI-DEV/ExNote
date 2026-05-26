import 'dart:math' as math;

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
  static const double rotationHandleOffset = 26.0;

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
  bool _isRotatingSelection = false;
  Offset? _rotationCenter;
  double _rotationStartAngle = 0.0;
  double _rotationCurrentAngle = 0.0;

  bool get isResizingSelection => _activeHandle != null;
  bool get isRotatingSelection => _isRotatingSelection;

  Rect? get selectionBounds =>
      _resizePreviewRect ??
      _computeBounds(_resizePreviewLines ?? selectionNotifier.value);

  List<SketchLine> get selectionForPainting =>
      _resizePreviewLines ?? selectionNotifier.value;

  List<SketchLine> get selectionForSketchSkipping {
    final indices = _resizeSelectionIndices;
    if (indices == null) return selectionNotifier.value;

    final sketchLines = sketchNotifier.value.lines;
    return [
      for (final index in indices)
        if (index >= 0 && index < sketchLines.length) sketchLines[index],
    ];
  }

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

  bool hitTestRotationHandle(Offset point, Rect bounds) {
    const handleSize = 24.0;
    for (final center in rotationHandleCenters(bounds)) {
      final handle = Rect.fromCenter(
        center: center,
        width: handleSize,
        height: handleSize,
      );
      if (handle.contains(point)) return true;
    }
    return false;
  }

  static List<Offset> rotationHandleCenters(Rect bounds) => [
    bounds.topLeft - const Offset(rotationHandleOffset, rotationHandleOffset),
    bounds.topRight + const Offset(rotationHandleOffset, -rotationHandleOffset),
    bounds.bottomLeft +
        const Offset(-rotationHandleOffset, rotationHandleOffset),
    bounds.bottomRight +
        const Offset(rotationHandleOffset, rotationHandleOffset),
  ];

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

  void startRotation(
    Rect bounds,
    List<SketchLine> selectedLines,
    Offset pointer,
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
    _rotationCenter = bounds.center;
    _rotationStartAngle = _angleFromCenter(pointer, _rotationCenter!);
    _rotationCurrentAngle = 0.0;
    _isRotatingSelection = true;
    invalidateCache();
    notifyListeners();
  }

  void updatePreview(Offset position) {
    if (_activeHandle == null ||
        _resizeStartRect == null ||
        _resizeOriginalLines == null) {
      return;
    }

    final newRect = _computeResizedRect(position);
    _resizePreviewRect = newRect;
    _resizePreviewLines = _applyResizeToLines(
      _resizeOriginalLines!,
      _resizeStartRect!,
      newRect,
    );
    notifyListeners();
  }

  void updateRotationPreview(Offset position) {
    if (!_isRotatingSelection ||
        _rotationCenter == null ||
        _resizeOriginalLines == null) {
      return;
    }

    final currentAngle = _angleFromCenter(position, _rotationCenter!);
    _rotationCurrentAngle = _normalizeAngle(currentAngle - _rotationStartAngle);
    _resizePreviewLines = _applyRotationToLines(
      _resizeOriginalLines!,
      _rotationCenter!,
      _rotationCurrentAngle,
    );
    _resizePreviewRect = _computeBounds(_resizePreviewLines!);
    notifyListeners();
  }

  double _angleFromCenter(Offset point, Offset center) =>
      math.atan2(point.dy - center.dy, point.dx - center.dx);

  double _normalizeAngle(double angle) {
    var normalized = angle;
    while (normalized <= -math.pi) {
      normalized += math.pi * 2;
    }
    while (normalized > math.pi) {
      normalized -= math.pi * 2;
    }
    return normalized;
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
    const minScalableDimension = 1.0;
    final canScaleX = from.width.abs() >= minScalableDimension;
    final canScaleY = from.height.abs() >= minScalableDimension;
    final xDelta = to.center.dx - from.center.dx;
    final yDelta = to.center.dy - from.center.dy;

    return lines
        .map(
          (line) => line.copyWith(
            points: line.points.map((p) {
              final x = canScaleX
                  ? to.left + ((p.x - from.left) / from.width) * to.width
                  : p.x + xDelta;
              final y = canScaleY
                  ? to.top + ((p.y - from.top) / from.height) * to.height
                  : p.y + yDelta;

              return Point(x, y, pressure: p.pressure);
            }).toList(),
          ),
        )
        .toList();
  }

  List<SketchLine> _applyRotationToLines(
    List<SketchLine> lines,
    Offset center,
    double angle,
  ) {
    final cosAngle = math.cos(angle);
    final sinAngle = math.sin(angle);

    return lines
        .map(
          (line) => line.copyWith(
            points: line.points.map((p) {
              final dx = p.x - center.dx;
              final dy = p.y - center.dy;
              return Point(
                center.dx + dx * cosAngle - dy * sinAngle,
                center.dy + dx * sinAngle + dy * cosAngle,
                pressure: p.pressure,
              );
            }).toList(),
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

  void commitRotation() {
    if (_resizePreviewLines == null ||
        _resizeSelectionIndices == null ||
        _resizeOriginalLines == null) {
      resetState();
      return;
    }

    if (_rotationCurrentAngle.abs() < 0.001) {
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
    _isRotatingSelection = false;
    _rotationCenter = null;
    _rotationStartAngle = 0.0;
    _rotationCurrentAngle = 0.0;
  }
}
