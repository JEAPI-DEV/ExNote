import 'package:scribble/scribble.dart';

abstract class UndoAction {
  void undo(List<SketchLine> lines);
  void redo(List<SketchLine> lines);
}

class AddLinesAction extends UndoAction {
  final List<SketchLine> lines;

  AddLinesAction(this.lines);

  @override
  void undo(List<SketchLine> currentLines) {
    for (final line in lines) {
      currentLines.remove(line);
    }
  }

  @override
  void redo(List<SketchLine> currentLines) {
    currentLines.addAll(lines);
  }
}

class RemoveLinesAction extends UndoAction {
  final List<SketchLine> removedLines;
  final List<int> originalIndices;

  RemoveLinesAction(this.removedLines, this.originalIndices);

  @override
  void undo(List<SketchLine> lines) {
    // Create a list of pairs (index, line) and sort by index
    final indexedLines = <_IndexedLine>[];
    for (int i = 0; i < removedLines.length; i++) {
      indexedLines.add(_IndexedLine(originalIndices[i], removedLines[i]));
    }

    // Sort ascending by index to ensure that when we insert,
    // we don't shift the positions of lines we haven't inserted yet.
    indexedLines.sort((a, b) => a.index.compareTo(b.index));

    for (final item in indexedLines) {
      // Ensure we don't insert out of bounds (shouldn't happen with correct indices)
      final index = item.index.clamp(0, lines.length);
      lines.insert(index, item.line);
    }
  }

  @override
  void redo(List<SketchLine> lines) {
    for (final line in removedLines) {
      lines.remove(line);
    }
  }
}

class _IndexedLine {
  final int index;
  final SketchLine line;
  _IndexedLine(this.index, this.line);
}

class MoveLinesAction extends UndoAction {
  final List<SketchLine> oldLines;
  final List<SketchLine> newLines;
  final List<int> indices;

  MoveLinesAction(this.oldLines, this.newLines, this.indices);

  @override
  void undo(List<SketchLine> lines) {
    for (int i = 0; i < indices.length; i++) {
      lines[indices[i]] = oldLines[i];
    }
  }

  @override
  void redo(List<SketchLine> lines) {
    for (int i = 0; i < indices.length; i++) {
      lines[indices[i]] = newLines[i];
    }
  }
}
