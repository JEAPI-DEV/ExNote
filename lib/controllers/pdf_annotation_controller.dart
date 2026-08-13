import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

import '../models/canvas_image.dart';
import '../models/drawing_tool.dart';
import '../models/pdf_annotation.dart';
import '../models/undo_action.dart';
import '../utils/undo_redo_manager.dart';
import 'drawing/eraser_handler.dart';
import 'drawing/pen_handler.dart';
import 'drawing/shape_snap_handler.dart';

/// Owns the ink-annotation session for a single exercise PDF.
///
/// Keeps one [Sketch] per page (in page-point coordinates), exposes the
/// notifiers the toolbar and overlay need, and reuses the existing pen and
/// stroke-eraser handlers plus the [UndoRedoManager] for editing.
///
/// Input methods work in page-point space; the widget layer is responsible for
/// translating screen positions and selecting the page before calling in.
class PdfAnnotationController extends ChangeNotifier {
  /// Committed sketches, keyed by zero-based page index.
  final Map<int, Sketch> annotations = {};

  /// Sketch of the currently active page, edited live by the handlers.
  final ValueNotifier<Sketch> activeSketch =
      ValueNotifier(const Sketch(lines: []));

  /// Pen color for new strokes.
  final ValueNotifier<Color> colorNotifier =
      ValueNotifier(Colors.redAccent);

  /// Pen width, in page-point units.
  final ValueNotifier<double> widthNotifier = ValueNotifier(2.5);

  /// Currently selected tool (pen or stroke eraser).
  final ValueNotifier<DrawingTool> toolNotifier =
      ValueNotifier(DrawingTool.pen);

  /// In-progress stroke points of the active page, in page-point coordinates.
  final ValueNotifier<List<Point>?> currentLineNotifier =
      ValueNotifier<List<Point>?>(null);

  /// Zero-based index of the page currently being edited.
  int activePageIndex = 0;

  /// Called whenever a stroke is committed, erased, undone, or redone so the
  /// owner can schedule persistence.
  final VoidCallback onContentChanged;

  late final UndoRedoManager _undoRedoManager;
  late final ShapeSnapHandler _shapeSnapHandler;
  late final PenHandler _penHandler;
  late final EraserHandler _eraserHandler;

  final ValueNotifier<List<SketchLine>> _selectionNotifier =
      ValueNotifier(const []);
  final ValueNotifier<String?> _selectedImageIdNotifier = ValueNotifier(null);

  // The eraser handler is reused only for its stroke-erasing behavior, so it
  // receives inert image notifiers that never contain anything.
  final ValueNotifier<List<CanvasImage>> _imagesNotifier =
      ValueNotifier(const []);

  PdfAnnotationController({required this.onContentChanged}) {
    _shapeSnapHandler = ShapeSnapHandler(
      currentLineNotifier: currentLineNotifier,
    );
    _penHandler = PenHandler(
      sketchNotifier: activeSketch,
      selectionNotifier: _selectionNotifier,
      currentLineNotifier: currentLineNotifier,
      onAction: _onAction,
      notifyListeners: notifyListeners,
      shapeSnapHandler: _shapeSnapHandler,
    );
    _eraserHandler = EraserHandler(
      sketchNotifier: activeSketch,
      canvasImagesNotifier: _imagesNotifier,
      selectedImageIdNotifier: _selectedImageIdNotifier,
      onAction: _onAction,
      onContentChanged: _markChanged,
    );

    _undoRedoManager = UndoRedoManager(
      sketchNotifier: activeSketch,
      onStateChanged: _markChanged,
    );

    activeSketch.addListener(_syncActivePage);
    currentLineNotifier.addListener(notifyListeners);
  }

  bool get canUndo => _undoRedoManager.canUndo;
  bool get canRedo => _undoRedoManager.canRedo;
  bool get hasActiveLine => currentLineNotifier.value?.isNotEmpty ?? false;

  /// Loads persisted annotations, replacing any current session state.
  void load(List<PdfAnnotation> persisted) {
    annotations.clear();
    for (final annotation in persisted) {
      final sketch = _decodeSketch(annotation.sketchJson);
      if (sketch != null && sketch.lines.isNotEmpty) {
        annotations[annotation.pageIndex] = sketch;
      }
    }
    activeSketch.value = annotations[activePageIndex] ?? const Sketch(lines: []);
    _undoRedoManager.clear();
    notifyListeners();
  }

  Sketch? _decodeSketch(String sketchJson) {
    try {
      final decoded = jsonDecode(sketchJson);
      if (decoded is! Map) return null;
      return Sketch.fromJson(decoded.cast<String, dynamic>());
    } catch (e) {
      debugPrint('Error decoding PDF annotation: $e');
      return null;
    }
  }

  /// Serializes the current session for persistence.
  List<PdfAnnotation> snapshot() {
    return [
      for (final entry in annotations.entries)
        if (entry.value.lines.isNotEmpty)
          PdfAnnotation(
            pageIndex: entry.key,
            sketchJson: jsonEncode(entry.value.toJson()),
          ),
    ];
  }

  /// Switches the active page, committing the current one and clearing undo.
  void setActivePage(int pageIndex) {
    if (pageIndex < 0) return;
    if (pageIndex == activePageIndex && currentLineNotifier.value == null) {
      return;
    }
    _cancelStroke();
    annotations[activePageIndex] = activeSketch.value;
    activePageIndex = pageIndex;
    activeSketch.value = annotations[pageIndex] ?? const Sketch(lines: []);
    _undoRedoManager.clear();
    notifyListeners();
  }

  /// Starts a stroke on [pageIndex] at a page-point [position].
  void beginStroke(int pageIndex, Offset position, {double pressure = 0.5}) {
    if (pageIndex != activePageIndex) {
      setActivePage(pageIndex);
    }

    if (toolNotifier.value == DrawingTool.strokeEraser) {
      _eraserHandler.handlePointerDown(position, widthNotifier.value);
      return;
    }

    _penHandler.handlePointerDown(
      position,
      pressure: pressure,
      currentColor: colorNotifier.value,
      currentWidth: widthNotifier.value,
      scale: 1.0,
      shapeSnappingEnabled: false,
    );
  }

  /// Continues the active stroke to a page-point [position].
  void extendStroke(Offset position) {
    if (toolNotifier.value == DrawingTool.strokeEraser) {
      _eraserHandler.handlePointerMove(position, widthNotifier.value);
      return;
    }

    _penHandler.handlePointerMove(
      position,
      scale: 1.0,
      shapeSnappingEnabled: false,
    );
  }

  /// Finishes the active stroke.
  void endStroke() {
    if (toolNotifier.value == DrawingTool.strokeEraser) {
      _eraserHandler.handlePointerUp();
      return;
    }

    _penHandler.handlePointerUp(
      currentColor: colorNotifier.value,
      currentWidth: widthNotifier.value,
      currentTool: toolNotifier.value,
    );
  }

  /// Cancels the active stroke without committing it.
  void cancelStroke() => _cancelStroke();

  void undo() => _undoRedoManager.undo();

  void redo() => _undoRedoManager.redo();

  void _onAction(UndoAction action) {
    _undoRedoManager.applyAction(action);
  }

  void _markChanged() {
    notifyListeners();
    onContentChanged();
  }

  void _syncActivePage() {
    annotations[activePageIndex] = activeSketch.value;
    notifyListeners();
  }

  void _cancelStroke() {
    _penHandler.handlePointerCancel();
    _eraserHandler.reset();
    currentLineNotifier.value = null;
  }

  @override
  void dispose() {
    activeSketch.removeListener(_syncActivePage);
    currentLineNotifier.removeListener(notifyListeners);
    _shapeSnapHandler.dispose();
    _undoRedoManager.dispose();
    activeSketch.dispose();
    currentLineNotifier.dispose();
    _selectionNotifier.dispose();
    _imagesNotifier.dispose();
    _selectedImageIdNotifier.dispose();
    colorNotifier.dispose();
    widthNotifier.dispose();
    toolNotifier.dispose();
    super.dispose();
  }
}
