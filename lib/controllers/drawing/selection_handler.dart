import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../../models/undo_action.dart';
import '../../utils/sketch_bounds.dart';
import 'resize_handler.dart';

class SelectionHandler {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final void Function(UndoAction) onAction;
  final VoidCallback notifyListeners;
  final VoidCallback invalidateCache;
  final ResizeHandler resizeHandler;

  List<Offset>? lassoPoints;
  Offset? dragStart;
  Offset currentDragOffset = Offset.zero;
  bool isDraggingSelection = false;

  SelectionHandler({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
    required this.notifyListeners,
    required this.invalidateCache,
    required this.resizeHandler,
  });

  void handlePointerDown(Offset position, {required bool isEditMode}) {
    final selectedLines = selectionNotifier.value;
    final bounds = _computeBounds(selectedLines);

    if (isEditMode && selectedLines.isNotEmpty && bounds != null) {
      final handle = resizeHandler.hitTestHandle(position, bounds);
      if (handle != null) {
        resizeHandler.startResize(handle, bounds, selectedLines);
        return;
      }
    }

    if (selectedLines.isNotEmpty &&
        _isPointInSelectionBounds(position, selectedLines)) {
      isDraggingSelection = true;
      dragStart = position;
      currentDragOffset = Offset.zero;
      invalidateCache();
      notifyListeners();
    } else {
      selectionNotifier.value = [];
      lassoPoints = [position];
      isDraggingSelection = false;
      resizeHandler.resetState();
      notifyListeners();
    }
  }

  void handlePointerMove(Offset position) {
    if (isDraggingSelection) {
      currentDragOffset = position - dragStart!;
      notifyListeners();
    } else if (resizeHandler.isResizingSelection) {
      resizeHandler.updatePreview(position);
    } else if (lassoPoints != null) {
      lassoPoints = [...lassoPoints!, position];
      notifyListeners();
    }
  }

  void handlePointerUp() {
    if (isDraggingSelection) {
      _applyMoveToSelection();
      isDraggingSelection = false;
      currentDragOffset = Offset.zero;
      dragStart = null;
      notifyListeners();
    } else if (resizeHandler.isResizingSelection) {
      resizeHandler.commitResize();
    } else if (lassoPoints != null) {
      _findSelectedLines();
      lassoPoints = null;
      notifyListeners();
    }
  }

  void reset() {
    lassoPoints = null;
    isDraggingSelection = false;
    currentDragOffset = Offset.zero;
    resizeHandler.resetState();
  }

  Rect? _computeBounds(List<SketchLine> lines) =>
      lines.isEmpty ? null : computeLineBounds(lines);

  bool _isPointInSelectionBounds(Offset point, List<SketchLine> lines) {
    final rect = _computeBounds(lines);
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

    sketchNotifier.value = Sketch(lines: newLines);

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
}
