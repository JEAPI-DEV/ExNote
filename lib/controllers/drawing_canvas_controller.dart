import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import '../models/canvas_image.dart';
import '../models/canvas_object.dart';
import 'drawing/pen_handler.dart';
import 'drawing/selection_handler.dart';
import 'drawing/resize_handler.dart';
import 'drawing/eraser_handler.dart';
import 'drawing/shape_snap_handler.dart';

class DrawingCanvasController extends ChangeNotifier {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final ValueNotifier<List<CanvasImage>> canvasImagesNotifier;
  final ValueNotifier<List<CanvasObject>> canvasObjectsNotifier;
  final ValueNotifier<String?> selectedImageIdNotifier;
  final ValueNotifier<String?> selectedObjectIdNotifier;
  final Function(UndoAction) onAction;
  final VoidCallback onContentChanged;
  final ValueChanged<bool>? onStrokeActivityChanged;
  final void Function(Offset) onGraphPlacementRequested;

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
  bool _isDraggingObject = false;
  bool _isResizingObject = false;
  bool _isStrokeActive = false;
  Offset? _imageDragStart;
  CanvasImage? _imageStart;
  Offset? _objectDragStart;
  CanvasObject? _objectStart;
  Rect? _objectStartRect;
  ResizeHandle? _objectResizeHandle;

  DrawingCanvasController({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.canvasImagesNotifier,
    required this.canvasObjectsNotifier,
    required this.selectedImageIdNotifier,
    required this.selectedObjectIdNotifier,
    required this.onAction,
    required this.onContentChanged,
    this.onStrokeActivityChanged,
    required this.onGraphPlacementRequested,
  }) {
    sketchNotifier.addListener(_onSketchChanged);
    canvasImagesNotifier.addListener(notifyListeners);
    canvasObjectsNotifier.addListener(notifyListeners);
    selectedImageIdNotifier.addListener(notifyListeners);
    selectedObjectIdNotifier.addListener(notifyListeners);

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
    canvasObjectsNotifier.removeListener(notifyListeners);
    selectedImageIdNotifier.removeListener(notifyListeners);
    selectedObjectIdNotifier.removeListener(notifyListeners);
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
      selectedObjectRect ?? selectedImageRect ?? _resizeHandler.selectionBounds;
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

  Rect? get selectedObjectRect {
    final id = selectedObjectIdNotifier.value;
    if (id == null) return null;
    for (final object in canvasObjectsNotifier.value) {
      if (object.id == id) return object.bounds;
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
        selectedObjectIdNotifier.value = null;
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

  bool _handleObjectPointerDown(Offset position, {required bool isEditMode}) {
    final selectedRect = selectedObjectRect;
    if (isEditMode && selectedRect != null) {
      final handle = _resizeHandler.hitTestHandle(position, selectedRect);
      if (handle != null) {
        _isResizingObject = true;
        _objectResizeHandle = handle;
        _objectDragStart = position;
        _objectStart = _selectedObject;
        _objectStartRect = selectedRect;
        selectionNotifier.value = [];
        selectedImageIdNotifier.value = null;
        notifyListeners();
        return true;
      }
    }

    for (final object in canvasObjectsNotifier.value.reversed) {
      if (object.bounds.inflate(4).contains(position)) {
        selectedObjectIdNotifier.value = object.id;
        selectedImageIdNotifier.value = null;
        selectionNotifier.value = [];
        _isDraggingObject = true;
        _objectDragStart = position;
        _objectStart = object;
        _objectStartRect = object.bounds;
        notifyListeners();
        return true;
      }
    }

    selectedObjectIdNotifier.value = null;
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

  CanvasObject? get _selectedObject {
    final id = selectedObjectIdNotifier.value;
    if (id == null) return null;
    for (final object in canvasObjectsNotifier.value) {
      if (object.id == id) return object;
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

  void _updateSelectedObject(CanvasObject updated) {
    canvasObjectsNotifier.value = [
      for (final object in canvasObjectsNotifier.value)
        if (object.id == updated.id) updated else object,
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

  void _handleObjectPointerMove(Offset position) {
    final start = _objectStart;
    final dragStart = _objectDragStart;
    if (start == null || dragStart == null) return;

    if (_isDraggingObject) {
      _updateSelectedObject(start.moveBy(position - dragStart));
    } else if (_isResizingObject && _objectStartRect != null) {
      final rect = _computeResizedObjectRect(position);
      _updateSelectedObject(
        start.copyWithBounds(
          left: rect.left,
          top: rect.top,
          width: rect.width,
          height: rect.height,
        ),
      );
    }
  }

  void _finishObjectInteraction() {
    if (_isDraggingObject || _isResizingObject) {
      final start = _objectStart;
      final current = _selectedObject;
      if (start != null && current != null && start.bounds != current.bounds) {
        onAction(ReplaceObjectAction(start, current));
      } else {
        onContentChanged();
      }
    }
    _isDraggingObject = false;
    _isResizingObject = false;
    _objectDragStart = null;
    _objectStart = null;
    _objectStartRect = null;
    _objectResizeHandle = null;
    notifyListeners();
  }

  Rect _computeResizedObjectRect(Offset pointer) {
    final start = _objectStartRect!;
    var left = start.left;
    var right = start.right;
    var top = start.top;
    var bottom = start.bottom;
    const minSize = 48.0;

    switch (_objectResizeHandle!) {
      case ResizeHandle.topLeft:
        left = pointer.dx;
        top = pointer.dy;
      case ResizeHandle.topCenter:
        top = pointer.dy;
      case ResizeHandle.topRight:
        right = pointer.dx;
        top = pointer.dy;
      case ResizeHandle.centerLeft:
        left = pointer.dx;
      case ResizeHandle.centerRight:
        right = pointer.dx;
      case ResizeHandle.bottomLeft:
        left = pointer.dx;
        bottom = pointer.dy;
      case ResizeHandle.bottomCenter:
        bottom = pointer.dy;
      case ResizeHandle.bottomRight:
        right = pointer.dx;
        bottom = pointer.dy;
    }

    if ((right - left).abs() < minSize) {
      if (_objectResizeHandle == ResizeHandle.topLeft ||
          _objectResizeHandle == ResizeHandle.centerLeft ||
          _objectResizeHandle == ResizeHandle.bottomLeft) {
        left = right - minSize;
      } else {
        right = left + minSize;
      }
    }

    if ((bottom - top).abs() < minSize) {
      if (_objectResizeHandle == ResizeHandle.topLeft ||
          _objectResizeHandle == ResizeHandle.topCenter ||
          _objectResizeHandle == ResizeHandle.topRight) {
        top = bottom - minSize;
      } else {
        bottom = top + minSize;
      }
    }

    if (left > right) {
      final temp = left;
      left = right;
      right = temp;
    }
    if (top > bottom) {
      final temp = top;
      top = bottom;
      bottom = temp;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  void _selectObjectFromLasso(List<Offset>? lasso) {
    if (lasso == null ||
        lasso.length < 3 ||
        selectionNotifier.value.isNotEmpty) {
      return;
    }
    final path = Path()..addPolygon(lasso, true);
    for (final object in canvasObjectsNotifier.value.reversed) {
      final bounds = object.bounds;
      final points = [
        bounds.center,
        bounds.topLeft,
        bounds.topRight,
        bounds.bottomLeft,
        bounds.bottomRight,
      ];
      if (points.any(path.contains)) {
        selectedObjectIdNotifier.value = object.id;
        selectedImageIdNotifier.value = null;
        return;
      }
    }
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

    if (currentTool == DrawingTool.graphPlacement) {
      onGraphPlacementRequested(event.localPosition);
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      _setStrokeActivity(true);
      if (_handleObjectPointerDown(
        event.localPosition,
        isEditMode: currentTool == DrawingTool.editSelection,
      )) {
        return;
      }
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
      event.localPosition,
      pressure: event.pressure,
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

    if (currentTool == DrawingTool.graphPlacement) {
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      if (_isDraggingObject || _isResizingObject) {
        _handleObjectPointerMove(event.localPosition);
        return;
      }
      if (_isDraggingImage || _isResizingImage) {
        _handleImagePointerMove(event.localPosition);
        return;
      }
      _selectionHandler.handlePointerMove(event.localPosition);
      return;
    }

    _penHandler.handlePointerMove(
      event.localPosition,
      pressure: event.pressure,
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

    if (currentTool == DrawingTool.graphPlacement) {
      return;
    }

    if (currentTool == DrawingTool.selection ||
        currentTool == DrawingTool.editSelection) {
      if (_isDraggingObject || _isResizingObject) {
        _finishObjectInteraction();
        _setStrokeActivity(false);
        return;
      }
      if (_isDraggingImage || _isResizingImage) {
        _finishImageInteraction();
        _setStrokeActivity(false);
        return;
      }
      final lasso = _selectionHandler.lassoPoints == null
          ? null
          : List<Offset>.from(_selectionHandler.lassoPoints!);
      _selectionHandler.handlePointerUp();
      _selectObjectFromLasso(lasso);
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
    _finishObjectInteraction();
    _eraserHandler.reset();
    _setStrokeActivity(false);
    notifyListeners();
  }
}
