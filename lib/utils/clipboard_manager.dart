import 'package:flutter/foundation.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import 'undo_redo_manager.dart';

class ClipboardManager {
  List<SketchLine> _clipboard = [];

  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;
  final UndoRedoManager undoRedoManager;
  final VoidCallback onCopy;

  ClipboardManager({
    required this.selectionNotifier,
    required this.sketchNotifier,
    required this.toolNotifier,
    required this.undoRedoManager,
    required this.onCopy,
  });

  bool get canPaste => _clipboard.isNotEmpty;

  void copy() {
    final selected = selectionNotifier.value;
    if (selected.isEmpty) return;

    _clipboard = selected
        .map(
          (line) => line.copyWith(
            points: line.points
                .map((p) => Point(p.x, p.y, pressure: p.pressure))
                .toList(),
          ),
        )
        .toList();

    onCopy();
  }

  void paste() {
    if (_clipboard.isEmpty) return;

    final currentSketch = sketchNotifier.value;
    const offset = 20.0;

    final pastedLines = _clipboard.map((line) {
      final newPoints = line.points
          .map((p) => Point(p.x + offset, p.y + offset, pressure: p.pressure))
          .toList();
      return line.copyWith(points: newPoints);
    }).toList();

    _clipboard = pastedLines;

    sketchNotifier.value = Sketch(
      lines: [...currentSketch.lines, ...pastedLines],
    );

    undoRedoManager.applyAction(AddLinesAction(pastedLines));

    selectionNotifier.value = pastedLines;
    toolNotifier.value = DrawingTool.selection;
  }

  void deleteSelection() {
    final selectedLines = selectionNotifier.value;
    if (selectedLines.isEmpty) return;

    final currentSketch = sketchNotifier.value;
    final remainingLines = <SketchLine>[];
    final removedLines = <SketchLine>[];
    final originalIndices = <int>[];

    for (int i = 0; i < currentSketch.lines.length; i++) {
      final line = currentSketch.lines[i];
      if (selectedLines.contains(line)) {
        removedLines.add(line);
        originalIndices.add(i);
      } else {
        remainingLines.add(line);
      }
    }

    sketchNotifier.value = Sketch(lines: remainingLines);
    undoRedoManager.applyAction(
      RemoveLinesAction(removedLines, originalIndices),
    );
    selectionNotifier.value = [];
  }
}
