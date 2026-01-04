import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/undo_action.dart';
import '../controllers/drawing_canvas_controller.dart';
import 'fast_sketch_painter.dart';

/// High-performance custom drawing widget that's compatible with Scribble's
/// Sketch format but uses raw Listener for immediate pointer event processing.
class FastDrawingCanvas extends StatefulWidget {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Color currentColor;
  final double currentWidth;
  final DrawingTool currentTool;
  final double scale;
  final Function(UndoAction) onAction;

  const FastDrawingCanvas({
    super.key,
    required this.sketchNotifier,
    required this.selectionNotifier,
    this.currentColor = Colors.black,
    this.currentWidth = 2.0,
    this.currentTool = DrawingTool.pen,
    this.scale = 1.0,
    required this.onAction,
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
      onAction: widget.onAction,
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
      ..scale = widget.scale;
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
                  return ValueListenableBuilder<List<Point>?>(
                    valueListenable: _controller.currentLineNotifier,
                    builder: (context, currentLinePoints, _) {
                      return CustomPaint(
                        painter: FastSketchPainter(
                          sketch: sketch,
                          currentLinePoints: currentLinePoints,
                          currentColor: widget.currentColor,
                          currentWidth: widget.currentWidth,
                          currentTool: widget.currentTool,
                          selectedLines: selectedLines,
                          lassoPoints: _controller.lassoPoints,
                          dragOffset: _controller.currentDragOffset,
                          isDraggingSelection: _controller.isDraggingSelection,
                          isDark: isDark,
                          scale: widget.scale,
                          cachedPicture: _controller.cachedSketchPicture,
                          onCacheUpdate: _controller.updateCache,
                        ),
                        child: Container(),
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
