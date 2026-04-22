import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/grid_type.dart';
import '../models/selection.dart';
import '../models/undo_action.dart';
import 'fast_drawing_canvas.dart';
import 'grid_painter.dart';
import 'zoomable_canvas_wrapper.dart';

class NoteCanvas extends StatefulWidget {
  final TransformationController transformationController;
  final bool gridEnabled;
  final GridType gridType;
  final double gridSpacing;
  final Selection? selection;
  final Size? screenshotSize;
  final GlobalKey exportKey;
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final bool shapeSnappingEnabled;
  final Function(UndoAction) onAction;

  const NoteCanvas({
    super.key,
    required this.transformationController,
    required this.gridEnabled,
    required this.gridType,
    required this.gridSpacing,
    this.selection,
    this.screenshotSize,
    required this.exportKey,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.shapeSnappingEnabled,
    required this.onAction,
  });

  @override
  State<NoteCanvas> createState() => _NoteCanvasState();
}

class _NoteCanvasState extends State<NoteCanvas> {
  // Zoom locking and popup state
  Timer? _zoomPopupTimer;
  bool _showZoomPopup = false;
  bool _isZoomLocked = false;

  void _showZoomPopupAction() {
    setState(() {
      _showZoomPopup = true;
    });
    _zoomPopupTimer?.cancel();
    _zoomPopupTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _showZoomPopup = false;
        });
      }
    });
  }

  void _toggleZoomLock() {
    setState(() {
      _isZoomLocked = !_isZoomLocked;
    });
  }

  @override
  void dispose() {
    _zoomPopupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ZoomableCanvasWrapper(
          transformationController: widget.transformationController,
          isZoomLocked: _isZoomLocked,
          onInteraction: _showZoomPopupAction,
          child: RepaintBoundary(
            key: widget.exportKey,
            child: ListenableBuilder(
              listenable: widget.transformationController,
              builder: (context, _) {
                return OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: 100000.0,
                  maxWidth: 100000.0,
                  minHeight: 100000.0,
                  maxHeight: 100000.0,
                  child: Transform(
                    transform: widget.transformationController.value,
                    child: ColoredBox(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: SizedBox(
                        width: 100000.0,
                        height: 100000.0,
                        child: Stack(
                          children: [
                            if (widget.gridEnabled)
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: GridPainter(
                                    matrix:
                                        widget.transformationController.value,
                                    gridType: widget.gridType,
                                    spacing: widget.gridSpacing,
                                  ),
                                ),
                              ),
                            Positioned(
                              top: 0,
                              left: 0,
                              child:
                                  widget.selection?.screenshotPath != null &&
                                      widget.screenshotSize != null
                                  ? Image.file(
                                      File(widget.selection!.screenshotPath!),
                                      width: widget.screenshotSize!.width,
                                      height: widget.screenshotSize!.height,
                                      fit: BoxFit.contain,
                                    )
                                  : widget.selection?.screenshotPath != null
                                  ? Image.file(
                                      File(widget.selection!.screenshotPath!),
                                      width: 400,
                                      fit: BoxFit.contain,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox.expand(
                              child: ValueListenableBuilder<Color>(
                                valueListenable: widget.colorNotifier,
                                builder: (context, color, _) {
                                  return ValueListenableBuilder<double>(
                                    valueListenable: widget.widthNotifier,
                                    builder: (context, width, _) {
                                      return ValueListenableBuilder<
                                        DrawingTool
                                      >(
                                        valueListenable: widget.toolNotifier,
                                        builder: (context, tool, _) {
                                          return FastDrawingCanvas(
                                            sketchNotifier:
                                                widget.sketchNotifier,
                                            selectionNotifier:
                                                widget.selectionNotifier,
                                            currentColor: color,
                                            currentWidth: width,
                                            currentTool: tool,
                                            scale: widget
                                                .transformationController
                                                .value
                                                .getMaxScaleOnAxis(),
                                            onAction: widget.onAction,
                                            shapeSnappingEnabled:
                                                widget.shapeSnappingEnabled,
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_showZoomPopup)
          Positioned(
            top: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _toggleZoomLock,
                      child: Icon(
                        _isZoomLocked ? Icons.lock : Icons.lock_open,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ValueListenableBuilder(
                      valueListenable: widget.transformationController,
                      builder: (context, Matrix4 value, _) {
                        final scale = value.entry(0, 0);
                        return Text(
                          '${(scale * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
