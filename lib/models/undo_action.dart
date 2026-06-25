import 'package:scribble/scribble.dart';
import 'canvas_object.dart';

class UndoState {
  final List<SketchLine> lines;
  final List<CanvasObject> objects;

  UndoState({required this.lines, required this.objects});
}

abstract class UndoAction {
  void undo(UndoState state);
  void redo(UndoState state);
}

class AddLinesAction extends UndoAction {
  final List<SketchLine> lines;

  AddLinesAction(this.lines);

  @override
  void undo(UndoState state) {
    for (final line in lines) {
      state.lines.remove(line);
    }
  }

  @override
  void redo(UndoState state) {
    state.lines.addAll(lines);
  }
}

class RemoveLinesAction extends UndoAction {
  final List<SketchLine> removedLines;
  final List<int> originalIndices;

  RemoveLinesAction(this.removedLines, this.originalIndices);

  @override
  void undo(UndoState state) {
    final indexedLines = <_IndexedLine>[];
    for (int i = 0; i < removedLines.length; i++) {
      indexedLines.add(_IndexedLine(originalIndices[i], removedLines[i]));
    }

    indexedLines.sort((a, b) => a.index.compareTo(b.index));

    for (final item in indexedLines) {
      final index = item.index.clamp(0, state.lines.length);
      state.lines.insert(index, item.line);
    }
  }

  @override
  void redo(UndoState state) {
    for (final line in removedLines) {
      state.lines.remove(line);
    }
  }
}

class _IndexedLine {
  final int index;
  final SketchLine line;
  _IndexedLine(this.index, this.line);
}

/// Replaces lines at specific indices in the sketch.
/// Used for move, transform, and style-change operations.
class ReplaceLinesAction extends UndoAction {
  final List<SketchLine> oldLines;
  final List<SketchLine> newLines;
  final List<int> indices;

  ReplaceLinesAction(this.oldLines, this.newLines, this.indices);

  @override
  void undo(UndoState state) {
    for (int i = 0; i < indices.length; i++) {
      state.lines[indices[i]] = oldLines[i];
    }
  }

  @override
  void redo(UndoState state) {
    for (int i = 0; i < indices.length; i++) {
      state.lines[indices[i]] = newLines[i];
    }
  }
}

class AddObjectAction extends UndoAction {
  final CanvasObject object;

  AddObjectAction(this.object);

  @override
  void undo(UndoState state) {
    state.objects.removeWhere((item) => item.id == object.id);
  }

  @override
  void redo(UndoState state) {
    state.objects.add(object);
  }
}

class RemoveObjectAction extends UndoAction {
  final CanvasObject object;
  final int originalIndex;

  RemoveObjectAction(this.object, this.originalIndex);

  @override
  void undo(UndoState state) {
    final index = originalIndex.clamp(0, state.objects.length);
    state.objects.insert(index, object);
  }

  @override
  void redo(UndoState state) {
    state.objects.removeWhere((item) => item.id == object.id);
  }
}

class ReplaceObjectAction extends UndoAction {
  final CanvasObject oldObject;
  final CanvasObject newObject;

  ReplaceObjectAction(this.oldObject, this.newObject);

  @override
  void undo(UndoState state) {
    _replace(state.objects, oldObject);
  }

  @override
  void redo(UndoState state) {
    _replace(state.objects, newObject);
  }

  void _replace(List<CanvasObject> objects, CanvasObject replacement) {
    final index = objects.indexWhere((item) => item.id == replacement.id);
    if (index == -1) return;
    objects[index] = replacement;
  }
}

// Aliases for backwards compatibility
typedef MoveLinesAction = ReplaceLinesAction;
typedef TransformLinesAction = ReplaceLinesAction;
