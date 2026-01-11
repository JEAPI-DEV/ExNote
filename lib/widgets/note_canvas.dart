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

enum _InteractionMode { none, panning, zooming }

class _NoteCanvasState extends State<NoteCanvas> {
  // Gesture state management
  _InteractionMode _currentMode = _InteractionMode.none;
  double _baseScale = 1.0;
  int _lastPointerCount = 0;

  // For manual panning to avoid jitter
  Matrix4 _initialMatrix = Matrix4.identity();
  Offset _initialFocalPoint = Offset.zero;

  // Zoom locking and popup state
  Timer? _zoomPopupTimer;
  bool _showZoomPopup = false;
  bool _isZoomLocked = false;

  void _showZoomPopupAction() {
    setState(() {
      _showZoomPopup = true;
    });
    _zoomPopupTimer?.cancel();
    _zoomPopupTimer = Timer(const Duration(seconds: 5), () {
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
        RepaintBoundary(
          key: widget.exportKey,
          child: InteractiveViewer(
            constrained: false,
            transformationController: widget.transformationController,
            minScale: _isZoomLocked
                ? widget.transformationController.value.getMaxScaleOnAxis()
                : 0.1,
            maxScale: _isZoomLocked
                ? widget.transformationController.value.getMaxScaleOnAxis()
                : 10.0,
            panEnabled: false, // Disable single-finger panning to allow drawing
            scaleEnabled: true, // Enabled to capture 2-finger gestures
            panAxis: PanAxis.free,
            clipBehavior: Clip.hardEdge,
            boundaryMargin: const EdgeInsets.fromLTRB(0, 0, 2000.0, 2000.0),
            onInteractionStart: (details) {
              _lastPointerCount = details.pointerCount;

              if (details.pointerCount == 2) {
                _currentMode = _InteractionMode.none;
                _baseScale = widget.transformationController.value
                    .getMaxScaleOnAxis();
                _initialMatrix = widget.transformationController.value.clone();
                _initialFocalPoint = details.localFocalPoint;
              }
            },
            onInteractionUpdate: (details) {
              if (details.pointerCount == 2) {
                // 1. Detect switch to 2 fingers
                if (_lastPointerCount != 2) {
                  _currentMode = _InteractionMode.none;
                  _baseScale = widget.transformationController.value
                      .getMaxScaleOnAxis();
                  _initialMatrix = widget.transformationController.value
                      .clone();
                  _initialFocalPoint = details.localFocalPoint;
                }

                // 2. Handle Decision & Locking
                if (_currentMode == _InteractionMode.none) {
                  final double currentScale = widget
                      .transformationController
                      .value
                      .getMaxScaleOnAxis();

                  // Trigger popup on interaction start/update if locked or close to zooming
                  _showZoomPopupAction();

                  final double scaleDeviation =
                      (currentScale / _baseScale - 1.0).abs();
                  final double panDistance =
                      (details.localFocalPoint - _initialFocalPoint).distance;

                  // Normalized scores (1.0 = threshold reached)
                  // Lower Zoom threshold (0.10) for better responsiveness
                  // Pan threshold (20px) to lock pan
                  final double zoomScore = scaleDeviation / 0.02;
                  final double panScore = panDistance / 20.0;

                  if (zoomScore > 1.0 &&
                      zoomScore > panScore &&
                      !_isZoomLocked) {
                    _currentMode = _InteractionMode.zooming;
                  } else if (panScore > 1.0 && panScore > zoomScore) {
                    _currentMode = _InteractionMode.panning;
                  }
                }

                // 3. Apply Behavior based on Mode
                if (_currentMode == _InteractionMode.zooming) {
                  _showZoomPopupAction(); // Keep popup alive while zooming
                  // Let InteractiveViewer handle it naturally
                } else {
                  // Determine translation delta
                  // Note: IF we just locked to Panning, we continue this block
                  // IF we are None, we also use this block (default to stable pan until decision)

                  final Offset delta =
                      details.localFocalPoint - _initialFocalPoint;

                  // Manual Matrix Update:
                  // Use the initial matrix (locked scale) + translation
                  final Matrix4 newMatrix = _initialMatrix.clone();
                  newMatrix[12] += delta.dx;
                  newMatrix[13] += delta.dy;

                  // Clamp to boundaries (Left/Top = 0.0)
                  // Prevents dragging into the void at the top/left edges
                  if (newMatrix[12] > 0) newMatrix[12] = 0;
                  if (newMatrix[13] > 0) newMatrix[13] = 0;

                  widget.transformationController.value = newMatrix;
                }
              }
              _lastPointerCount = details.pointerCount;
            },
            onInteractionEnd: (details) {},
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SizedBox(
                width: 100000.0,
                height: 100000.0,
                child: Stack(
                  children: [
                    if (widget.gridEnabled)
                      Positioned.fill(
                        child: ListenableBuilder(
                          listenable: widget.transformationController,
                          builder: (context, _) => CustomPaint(
                            painter: GridPainter(
                              matrix: widget.transformationController.value,
                              gridType: widget.gridType,
                              spacing: widget.gridSpacing,
                            ),
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
                                    selectionNotifier: widget.selectionNotifier,
                                    currentColor: color,
                                    currentWidth: width,
                                    currentTool: tool,
                                    scale: widget.transformationController.value
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
                        return Text(
                          '${(value.getMaxScaleOnAxis() * 100).toInt()}%',
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
