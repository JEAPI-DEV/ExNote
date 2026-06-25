import 'package:flutter/foundation.dart';
import 'package:scribble/scribble.dart';
import '../models/canvas_object.dart';
import '../models/undo_action.dart';

class UndoRedoManager {
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];
  final ValueNotifier<int> historyNotifier = ValueNotifier(0);

  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<CanvasObject>>? objectsNotifier;
  final VoidCallback onStateChanged;

  UndoRedoManager({
    required this.sketchNotifier,
    this.objectsNotifier,
    required this.onStateChanged,
  });

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  void applyAction(UndoAction action) {
    _undoStack.add(action);
    _redoStack.clear();
    historyNotifier.value++;
    onStateChanged();
  }

  void undo() {
    if (_undoStack.isNotEmpty) {
      final action = _undoStack.removeLast();
      final currentLines = List<SketchLine>.from(sketchNotifier.value.lines);
      final currentObjects = List<CanvasObject>.from(
        objectsNotifier?.value ?? const <CanvasObject>[],
      );
      action.undo(UndoState(lines: currentLines, objects: currentObjects));
      sketchNotifier.value = Sketch(lines: currentLines);
      if (objectsNotifier != null) objectsNotifier!.value = currentObjects;
      _redoStack.add(action);
      historyNotifier.value++;
      onStateChanged();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final action = _redoStack.removeLast();
      final currentLines = List<SketchLine>.from(sketchNotifier.value.lines);
      final currentObjects = List<CanvasObject>.from(
        objectsNotifier?.value ?? const <CanvasObject>[],
      );
      action.redo(UndoState(lines: currentLines, objects: currentObjects));
      sketchNotifier.value = Sketch(lines: currentLines);
      if (objectsNotifier != null) objectsNotifier!.value = currentObjects;
      _undoStack.add(action);
      historyNotifier.value++;
      onStateChanged();
    }
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
    historyNotifier.value = 0;
  }

  void dispose() {
    historyNotifier.dispose();
  }
}
