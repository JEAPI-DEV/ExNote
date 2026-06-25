import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import '../models/canvas_image.dart';
import '../models/canvas_object.dart';
import '../controllers/drawing_canvas_controller.dart';
import 'fast_sketch_painter.dart';

class FastDrawingCanvas extends StatefulWidget {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final ValueNotifier<List<CanvasImage>> canvasImagesNotifier;
  final ValueNotifier<List<CanvasObject>> canvasObjectsNotifier;
  final ValueNotifier<String?> selectedImageIdNotifier;
  final ValueNotifier<String?> selectedObjectIdNotifier;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;
  final double scale;
  final bool shapeSnappingEnabled;
  final Function(UndoAction) onAction;
  final VoidCallback onContentChanged;
  final ValueChanged<bool>? onStrokeActivityChanged;
  final ValueChanged<Offset> onGraphPlacementRequested;

  const FastDrawingCanvas({
    super.key,
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.canvasImagesNotifier,
    required this.canvasObjectsNotifier,
    required this.selectedImageIdNotifier,
    required this.selectedObjectIdNotifier,
    this.currentColor = Colors.black,
    this.currentWidth = 2.0,
    this.currentTool = DrawingTool.pen,
    this.scale = 1.0,
    required this.shapeSnappingEnabled,
    required this.onAction,
    required this.onContentChanged,
    this.onStrokeActivityChanged,
    required this.onGraphPlacementRequested,
  });

  @override
  State<FastDrawingCanvas> createState() => FastDrawingCanvasState();
}

class FastDrawingCanvasState extends State<FastDrawingCanvas> {
  late DrawingCanvasController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DrawingCanvasController(
      sketchNotifier: widget.sketchNotifier,
      selectionNotifier: widget.selectionNotifier,
      canvasImagesNotifier: widget.canvasImagesNotifier,
      canvasObjectsNotifier: widget.canvasObjectsNotifier,
      selectedImageIdNotifier: widget.selectedImageIdNotifier,
      selectedObjectIdNotifier: widget.selectedObjectIdNotifier,
      onAction: widget.onAction,
      onContentChanged: widget.onContentChanged,
      onStrokeActivityChanged: widget.onStrokeActivityChanged,
      onGraphPlacementRequested: widget.onGraphPlacementRequested,
    );
    _updateController();
  }

  @override
  void didUpdateWidget(FastDrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateController();
  }

  void _updateController() {
    _controller
      ..currentColor = widget.currentColor
      ..currentWidth = widget.currentWidth
      ..currentTool = widget.currentTool
      ..scale = widget.scale
      ..shapeSnappingEnabled = widget.shapeSnappingEnabled;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    _controller.updateTheme(isDark);

    return Listener(
      onPointerDown: _controller.handlePointerDown,
      onPointerMove: _controller.handlePointerMove,
      onPointerUp: _controller.handlePointerUp,
      onPointerCancel: _controller.handlePointerCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return ValueListenableBuilder<Sketch>(
            valueListenable: widget.sketchNotifier,
            builder: (context, sketch, _) {
              return ValueListenableBuilder<List<SketchLine>>(
                valueListenable: widget.selectionNotifier,
                builder: (context, selectedLines, _) {
                  // Use the child parameter to prevent rebuilding the static layer
                  // on every pointer move event.
                  return ValueListenableBuilder<List<Point>?>(
                    valueListenable: _controller.currentLineNotifier,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        painter: StaticSketchPainter(
                          sketch: sketch,
                          isDark: isDark,
                          scale: widget.scale,
                          selectedLines: _controller.selectionForPainting,
                          selectedLinesToSkip:
                              _controller.selectionForSketchSkipping,
                          isDraggingSelection: _controller.isDraggingSelection,
                          isResizingSelection: _controller.isResizingSelection,
                          isRotatingSelection: _controller.isRotatingSelection,
                          cachedPicture: _controller.cachedSketchPicture,
                          onCacheUpdate: _controller.updateCache,
                        ),
                        child: Container(),
                      ),
                    ),
                    builder: (context, currentLinePoints, child) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          child!, // The static layer (cached widget)
                          CustomPaint(
                            painter: ActiveSketchPainter(
                              currentLinePoints: currentLinePoints,
                              currentColor: widget.currentColor,
                              currentWidth: widget.currentWidth,
                              currentTool: widget.currentTool,
                              selectedLines: selectedLines,
                              previewLines: _controller.selectionForPainting,
                              lassoPoints: _controller.lassoPoints,
                              dragOffset: _controller.currentDragOffset,
                              isDraggingSelection:
                                  _controller.isDraggingSelection,
                              isResizingSelection:
                                  _controller.isResizingSelection,
                              isRotatingSelection:
                                  _controller.isRotatingSelection,
                              isDark: isDark,
                              scale: widget.scale,
                              selectionRect: _controller.selectionBounds,
                              showHandles:
                                  widget.currentTool ==
                                  DrawingTool.editSelection,
                              showRotationHandle:
                                  widget.currentTool ==
                                      DrawingTool.editSelection &&
                                  selectedLines.isNotEmpty,
                              cachedPicture: _controller.cachedSketchPicture,
                            ),
                            child: Container(),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
