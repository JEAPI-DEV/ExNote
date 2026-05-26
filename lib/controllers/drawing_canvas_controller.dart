import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import '../models/canvas_image.dart';
import 'drawing/pen_handler.dart';
import 'drawing/selection_handler.dart';
import 'drawing/resize_handler.dart';
import 'drawing/eraser_handler.dart';
import 'drawing/shape_snap_handler.dart';

class DrawingCanvasController extends ChangeNotifier {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final ValueNotifier<List<CanvasImage>> canvasImagesNotifier;
  final ValueNotifier<String?> selectedImageIdNotifier;
  final Function(UndoAction) onAction;
  final VoidCallback onContentChanged;
  final ValueChanged<bool>? onStrokeActivityChanged;

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

  bool _isDraggingImage = false;
  bool _isResizingImage = false;
  bool _isStrokeActive = false;
  Offset? _imageDragStart;
  CanvasImage? _imageStart;

  DrawingCanvasController({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.canvasImagesNotifier,
    required this.selectedImageIdNotifier,
    required this.onAction,
    required this.onContentChanged,
    this.onStrokeActivityChanged,
  }) {
    sketchNotifier.addListener(_onSketchChanged);
    canvasImagesNotifier.addListener(notifyListeners);
    selectedImageIdNotifier.addListener(notifyListeners);

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
      canvasImagesNotifier: canvasImagesNotifier,
      selectedImageIdNotifier: selectedImageIdNotifier,
      onAction: onAction,
      onContentChanged: onContentChanged,
    );
  }

  @override
  void dispose() {
    sketchNotifier.removeListener(_onSketchChanged);
    canvasImagesNotifier.removeListener(notifyListeners);
    selectedImageIdNotifier.removeListener(notifyListeners);
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

  void _setStrokeActivity(bool active) {
    if (_isStrokeActive == active) return;
    _isStrokeActive = active;
    onStrokeActivityChanged?.call(active);
  }

  List<SketchLine> get selectionForPainting =>
      _resizeHandler.selectionForPainting;
  List<SketchLine> get selectionForSketchSkipping =>
      _resizeHandler.selectionForSketchSkipping;
  Rect? get selectionBounds =>
      selectedImageRect ?? _resizeHandler.selectionBounds;
  bool get isDraggingSelection => _selectionHandler.isDraggingSelection;
  bool get isResizingSelection => _resizeHandler.isResizingSelection;
  bool get isRotatingSelection => _resizeHandler.isRotatingSelection;
  Rect? get selectedImageRect {
    final id = selectedImageIdNotifier.value;
    if (id == null) return null;
    for (final image in canvasImagesNotifier.value) {
      if (image.id == id) {
        return Rect.fromLTWH(image.left, image.top, image.width, image.height);
      }
    }
    return null;
  }

  List<Offset>? get lassoPoints => _selectionHandler.lassoPoints;
  Offset get currentDragOffset => _selectionHandler.currentDragOffset;

  bool _handleImagePointerDown(Offset position, {required bool isEditMode}) {
    final selectedRect = selectedImageRect;
    if (isEditMode &&
        selectedRect != null &&
        _isPointInResizeHandle(position, selectedRect)) {
      _isResizingImage = true;
      _imageDragStart = position;
      _imageStart = _selectedImage;
      selectionNotifier.value = [];
      notifyListeners();
      return true;
    }

    for (final image in canvasImagesNotifier.value.reversed) {
      final rect = Rect.fromLTWH(
        image.left,
        image.top,
        image.width,
        image.height,
      );
      if (rect.contains(position)) {
        selectedImageIdNotifier.value = image.id;
        selectionNotifier.value = [];
        _isDraggingImage = true;
        _imageDragStart = position;
        _imageStart = image;
        notifyListeners();
        return true;
      }
    }

    selectedImageIdNotifier.value = null;
    return false;
  }

  CanvasImage? get _selectedImage {
    final id = selectedImageIdNotifier.value;
    if (id == null) return null;
    for (final image in canvasImagesNotifier.value) {
      if (image.id == id) return image;
    }
    return null;
  }

  bool _isPointInResizeHandle(Offset point, Rect rect) {
    const size = 24.0;
    final handle = Rect.fromCenter(
      center: rect.bottomRight,
      width: size,
      height: size,
    );
    return handle.contains(point);
  }

  void _updateSelectedImage(CanvasImage updated) {
    canvasImagesNotifier.value = [
      for (final image in canvasImagesNotifier.value)
        if (image.id == updated.id) updated else image,
    ];
  }

  void _handleImagePointerMove(Offset position) {
    final start = _imageStart;
    final dragStart = _imageDragStart;
    if (start == null || dragStart == null) return;

    final delta = position - dragStart;
    if (_isDraggingImage) {
      _updateSelectedImage(
        start.copyWith(left: start.left + delta.dx, top: start.top + delta.dy),
      );
    } else if (_isResizingImage) {
      const minSize = 32.0;
      final newWidth = (start.width + delta.dx)
          .clamp(minSize, 100000.0)
          .toDouble();
      final aspect = start.width == 0 ? 1.0 : start.height / start.width;
      _updateSelectedImage(
        start.copyWith(width: newWidth, height: newWidth * aspect),
      );
    }
  }

  void _finishImageInteraction() {
    if (_isDraggingImage || _isResizingImage) {
      onContentChanged();
    }
    _isDraggingImage = false;
    _isResizingImage = false;
    _imageDragStart = null;
    _imageStart = null;
    notifyListeners();
  }

  void handlePointerDown(PointerDownEvent event) {
    if (event.kind != ui.PointerDeviceKind.stylus &&
        event.kind != ui.PointerDeviceKind.invertedStylus) {
      return;
    }

    if (currentTool == DrawingTool.strokeEraser) {
      _setStrokeActivity(true);
      _eraserHandler.handlePointerDown(event.localPosition, currentWidth);
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      _setStrokeActivity(true);
      if (_handleImagePointerDown(
        event.localPosition,
        isEditMode: currentTool == DrawingTool.editSelection,
      )) {
        return;
      }
      _selectionHandler.handlePointerDown(
        event.localPosition,
        isEditMode: currentTool == DrawingTool.editSelection,
      );
      return;
    }

    _setStrokeActivity(true);
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
      if (_isDraggingImage || _isResizingImage) {
        _handleImagePointerMove(event.localPosition);
        return;
      }
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
      _setStrokeActivity(false);
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      if (_isDraggingImage || _isResizingImage) {
        _finishImageInteraction();
        _setStrokeActivity(false);
        return;
      }
      _selectionHandler.handlePointerUp();
      _setStrokeActivity(false);
      return;
    }

    _penHandler.handlePointerUp(
      currentColor: currentColor,
      currentWidth: currentWidth,
      currentTool: currentTool,
    );
    _setStrokeActivity(false);
  }

  void handlePointerCancel(PointerCancelEvent event) {
    _penHandler.handlePointerCancel();
    _selectionHandler.reset();
    _finishImageInteraction();
    _eraserHandler.reset();
    _setStrokeActivity(false);
    notifyListeners();
  }
}
