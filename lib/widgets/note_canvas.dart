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
  final String? waifuImageUrl;
  final double? waifuImageWidth;
  final Size? screenshotSize;
  final GlobalKey exportKey;
  final ValueNotifier<Color> colorNotifier;
  final ValueNotifier<double> widthNotifier;
  final ValueNotifier<DrawingTool> toolNotifier;
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final Function(UndoAction) onAction;

  const NoteCanvas({
    super.key,
    required this.transformationController,
    required this.gridEnabled,
    required this.gridType,
    required this.gridSpacing,
    this.selection,
    this.waifuImageUrl,
    this.waifuImageWidth,
    this.screenshotSize,
    required this.exportKey,
    required this.colorNotifier,
    required this.widthNotifier,
    required this.toolNotifier,
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.onAction,
  });

  @override
  State<NoteCanvas> createState() => _NoteCanvasState();
}

class _NoteCanvasState extends State<NoteCanvas> {
  @override
  Widget build(BuildContext context) {
    return ZoomableCanvasWrapper(
      transformationController: widget.transformationController,
      child: RepaintBoundary(
        key: widget.exportKey,
        child: ListenableBuilder(
          listenable: widget.transformationController,
          builder: (context, _) {
            return Transform(
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
                              matrix: widget.transformationController.value,
                              gridType: widget.gridType,
                              spacing: widget.gridSpacing,
                            ),
                          ),
                        ),
                      if (widget.waifuImageUrl != null)
                        Positioned(
                          top: widget.screenshotSize?.height ?? 0,
                          left: 0,
                          child: Opacity(
                            opacity: 0.3,
                            child: Image.network(
                              widget.waifuImageUrl!,
                              width: widget.waifuImageWidth,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return const SizedBox.shrink();
                              },
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
                                return ValueListenableBuilder<DrawingTool>(
                                  valueListenable: widget.toolNotifier,
                                  builder: (context, tool, _) {
                                    return FastDrawingCanvas(
                                      sketchNotifier: widget.sketchNotifier,
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
            );
          },
        ),
      ),
    );
  }
}
