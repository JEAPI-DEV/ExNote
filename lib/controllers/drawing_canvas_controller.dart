import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import 'drawing/pen_handler.dart';
import 'drawing/selection_handler.dart';
import 'drawing/resize_handler.dart';
import 'drawing/eraser_handler.dart';
import 'drawing/shape_snap_handler.dart';

class DrawingCanvasController extends ChangeNotifier {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Function(UndoAction) onAction;

  Color currentColor = Colors.black;
  double currentWidth = 2.0;
  DrawingTool currentTool = DrawingTool.pen;
  bool shapeSnappingEnabled = true;

  double _scale = 1.0;
  double get scale => _scale;
  set scale(double value) {
    if (_scale == value) return;
    final oldLod = _getLodLevel(_scale);
    final newLod = _getLodLevel(value);
    _scale = value;

    if (oldLod != newLod) {
      _invalidateCache();
      notifyListeners();
    }
  }

  bool isDark = false;

  int _getLodLevel(double s) {
    if (s < 0.5) return 0;
    if (s < 0.8) return 1;
    return 2;
  }

  final ValueNotifier<List<Point>?> currentLineNotifier = ValueNotifier(null);

  late final ShapeSnapHandler _shapeSnapHandler;
  late final PenHandler _penHandler;
  late final ResizeHandler _resizeHandler;
  late final SelectionHandler _selectionHandler;
  late final EraserHandler _eraserHandler;

  ui.Picture? cachedSketchPicture;

  DrawingCanvasController({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
  }) {
    sketchNotifier.addListener(_onSketchChanged);

    _shapeSnapHandler = ShapeSnapHandler(
      currentLineNotifier: currentLineNotifier,
    );
    _resizeHandler = ResizeHandler(
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      onAction: onAction,
      notifyListeners: notifyListeners,
      invalidateCache: _invalidateCache,
    );
    _selectionHandler = SelectionHandler(
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      onAction: onAction,
      notifyListeners: notifyListeners,
      invalidateCache: _invalidateCache,
      resizeHandler: _resizeHandler,
    );
    _penHandler = PenHandler(
      sketchNotifier: sketchNotifier,
      selectionNotifier: selectionNotifier,
      currentLineNotifier: currentLineNotifier,
      onAction: onAction,
      notifyListeners: notifyListeners,
      shapeSnapHandler: _shapeSnapHandler,
    );
    _eraserHandler = EraserHandler(
      sketchNotifier: sketchNotifier,
      onAction: onAction,
    );
  }

  @override
  void dispose() {
    sketchNotifier.removeListener(_onSketchChanged);
    _shapeSnapHandler.dispose();
    currentLineNotifier.dispose();
    cachedSketchPicture?.dispose();
    super.dispose();
  }

  void _onSketchChanged() {
    _invalidateCache();
  }

  void updateTheme(bool newIsDark) {
    if (isDark != newIsDark) {
      isDark = newIsDark;
      _invalidateCache();
      notifyListeners();
    }
  }

  void _invalidateCache() {
    cachedSketchPicture?.dispose();
    cachedSketchPicture = null;
  }

  void updateCache(ui.Picture picture) {
    cachedSketchPicture = picture;
  }

  List<SketchLine> get selectionForPainting =>
      _resizeHandler.selectionForPainting;
  Rect? get selectionBounds => _resizeHandler.selectionBounds;
  bool get isDraggingSelection => _selectionHandler.isDraggingSelection;
  bool get isResizingSelection => _resizeHandler.isResizingSelection;
  List<Offset>? get lassoPoints => _selectionHandler.lassoPoints;
  Offset get currentDragOffset => _selectionHandler.currentDragOffset;

  void handlePointerDown(PointerDownEvent event) {
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (currentTool == DrawingTool.strokeEraser) {
      _eraserHandler.handlePointerDown(event.localPosition, currentWidth);
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      _selectionHandler.handlePointerDown(
        event.localPosition,
        isEditMode: currentTool == DrawingTool.editSelection,
      );
      return;
    }

    _penHandler.handlePointerDown(
      event,
      currentColor: currentColor,
      currentWidth: currentWidth,
      scale: _scale,
      shapeSnappingEnabled: shapeSnappingEnabled,
    );
  }

  void handlePointerMove(PointerMoveEvent event) {
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (currentTool == DrawingTool.strokeEraser) {
      _eraserHandler.handlePointerMove(event.localPosition, currentWidth);
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      _selectionHandler.handlePointerMove(event.localPosition);
      return;
    }

    _penHandler.handlePointerMove(
      event,
      scale: _scale,
      shapeSnappingEnabled: shapeSnappingEnabled,
    );
  }

  void handlePointerUp(PointerUpEvent event) {
    if (currentTool == DrawingTool.strokeEraser) {
      _eraserHandler.handlePointerUp();
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      _selectionHandler.handlePointerUp();
      return;
    }

    _penHandler.handlePointerUp(
      currentColor: currentColor,
      currentWidth: currentWidth,
      currentTool: currentTool,
    );
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _penHandler.handlePointerCancel();
    _selectionHandler.reset();
    _eraserHandler.reset();
    notifyListeners();
  }
}
