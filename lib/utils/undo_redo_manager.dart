import 'package:flutter/foundation.dart';
import 'package:scribble/scribble.dart';
import '../models/undo_action.dart';

class UndoRedoManager {
  final List<UndoAction> _undoStack = [];
  final List<UndoAction> _redoStack = [];
  final ValueNotifier<int> historyNotifier = ValueNotifier(0);

  final ValueNotifier<Sketch> sketchNotifier;
  final VoidCallback onStateChanged;

  UndoRedoManager({required this.sketchNotifier, required this.onStateChanged});

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
      action.undo(currentLines);
      sketchNotifier.value = Sketch(lines: currentLines);
      _redoStack.add(action);
      historyNotifier.value++;
      onStateChanged();
    }
  }

  void redo() {
    if (_redoStack.isNotEmpty) {
      final action = _redoStack.removeLast();
      final currentLines = List<SketchLine>.from(sketchNotifier.value.lines);
      action.redo(currentLines);
      sketchNotifier.value = Sketch(lines: currentLines);
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
