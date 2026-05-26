import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/undo_action.dart';
import '../utils/sketch_bounds.dart';

class SelectionEditController {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final void Function(UndoAction) onAction;

  SelectionEditController({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
  });

  void applyStyle({Color? color, double? strokeWidth}) {
    final selected = selectionNotifier.value;
    if (selected.isEmpty) return;

    final sketch = sketchNotifier.value;
    final selectedSet = selected.toSet();
    final updatedLines = [...sketch.lines];
    final oldLines = <SketchLine>[];
    final newLines = <SketchLine>[];
    final indices = <int>[];

    for (int i = 0; i < sketch.lines.length; i++) {
      final line = sketch.lines[i];
      if (!selectedSet.contains(line)) continue;

      oldLines.add(line);
      final updated = line.copyWith(
        color: color?.toARGB32() ?? line.color,
        width: strokeWidth ?? line.width,
      );
      newLines.add(updated);
      updatedLines[i] = updated;
      indices.add(i);
    }

    _commit(updatedLines, oldLines, newLines, indices);
  }

  void mirror({required bool mirrorOverXAxis}) {
    final selected = selectionNotifier.value;
    if (selected.isEmpty) return;

    final bounds = computeLineBounds(selected);
    if (bounds == Rect.zero) return;

    final sketch = sketchNotifier.value;
    final selectedSet = selected.toSet();
    final updatedLines = [...sketch.lines];
    final oldLines = <SketchLine>[];
    final newLines = <SketchLine>[];
    final indices = <int>[];

    for (int i = 0; i < sketch.lines.length; i++) {
      final line = sketch.lines[i];
      if (!selectedSet.contains(line)) continue;

      oldLines.add(line);
      final updated = line.copyWith(
        points: line.points.map((p) {
          if (mirrorOverXAxis) {
            return Point(
              p.x,
              bounds.center.dy - (p.y - bounds.center.dy),
              pressure: p.pressure,
            );
          }

          return Point(
            bounds.center.dx - (p.x - bounds.center.dx),
            p.y,
            pressure: p.pressure,
          );
        }).toList(),
      );
      newLines.add(updated);
      updatedLines[i] = updated;
      indices.add(i);
    }

    _commit(updatedLines, oldLines, newLines, indices);
  }

  void _commit(
    List<SketchLine> updatedLines,
    List<SketchLine> oldLines,
    List<SketchLine> newLines,
    List<int> indices,
  ) {
    if (newLines.isEmpty) return;

    sketchNotifier.value = Sketch(lines: updatedLines);
    selectionNotifier.value = newLines;
    onAction(TransformLinesAction(oldLines, newLines, indices));
  }
}
