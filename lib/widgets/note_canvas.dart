import 'dart:io';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../models/drawing_tool.dart';
import '../models/grid_type.dart';
import '../models/selection.dart';
import '../models/undo_action.dart';
import 'fast_drawing_canvas.dart';
import 'grid_painter.dart';

class NoteCanvas extends StatelessWidget {
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
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        if (details.pointerCount < 2) {
          // Prevent single finger gesture
        }
      },
      child: RepaintBoundary(
        key: exportKey,
        child: InteractiveViewer(
          constrained: false,
          transformationController: transformationController,
          minScale: 0.01,
          maxScale: 4.0,
          panEnabled: false,
          scaleEnabled: true,
          boundaryMargin: const EdgeInsets.all(50000.0),
          child: ColoredBox(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SizedBox(
              width: 100000.0,
              height: 100000.0,
              child: Stack(
                children: [
                  if (gridEnabled)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: GridPainter(
                          matrix: transformationController.value,
                          gridType: gridType,
                          spacing: gridSpacing,
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    left: 0,
                    child:
                        selection?.screenshotPath != null &&
                            screenshotSize != null
                        ? Image.file(
                            File(selection!.screenshotPath!),
                            width: screenshotSize!.width,
                            height: screenshotSize!.height,
                            fit: BoxFit.contain,
                          )
                        : selection?.screenshotPath != null
                        ? Image.file(
                            File(selection!.screenshotPath!),
                            width: 400,
                            fit: BoxFit.contain,
                          )
                        : const SizedBox.shrink(),
                  ),
                  SizedBox.expand(
                    child: ValueListenableBuilder<Color>(
                      valueListenable: colorNotifier,
                      builder: (context, color, _) {
                        return ValueListenableBuilder<double>(
                          valueListenable: widthNotifier,
                          builder: (context, width, _) {
                            return ValueListenableBuilder<DrawingTool>(
                              valueListenable: toolNotifier,
                              builder: (context, tool, _) {
                                return FastDrawingCanvas(
                                  sketchNotifier: sketchNotifier,
                                  selectionNotifier: selectionNotifier,
                                  currentColor: color,
                                  currentWidth: width,
                                  currentTool: tool,
                                  scale: transformationController.value
                                      .getMaxScaleOnAxis(),
                                  onAction: onAction,
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
      ),
    );
  }
}
