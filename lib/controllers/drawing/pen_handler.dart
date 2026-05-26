import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:scribble/scribble.dart';
import '../../models/drawing_tool.dart';
import '../../models/undo_action.dart';
import 'shape_snap_handler.dart';

class PenHandler {
  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<SketchLine>> selectionNotifier;
  final ValueNotifier<List<Point>?> currentLineNotifier;
  final void Function(UndoAction) onAction;
  final VoidCallback notifyListeners;
  final ShapeSnapHandler shapeSnapHandler;

  bool _currentLineNotifyScheduled = false;

  PenHandler({
    required this.sketchNotifier,
    required this.selectionNotifier,
    required this.currentLineNotifier,
    required this.onAction,
    required this.notifyListeners,
    required this.shapeSnapHandler,
  });

  void handlePointerDown(
    PointerDownEvent event, {
    required Color currentColor,
    required double currentWidth,
    required double scale,
    required bool shapeSnappingEnabled,
  }) {
    if (selectionNotifier.value.isNotEmpty) {
      selectionNotifier.value = [];
    }

    shapeSnapHandler.reset();

    currentLineNotifier.value = [
      Point(
        event.localPosition.dx,
        event.localPosition.dy,
        pressure: event.pressure,
      ),
    ];

    if (shapeSnappingEnabled) {
      shapeSnapHandler.setLastPosition(event.localPosition);
      shapeSnapHandler.startTimer();
    }
  }

  void handlePointerMove(
    PointerMoveEvent event, {
    required double scale,
    required bool shapeSnappingEnabled,
  }) {
    if (currentLineNotifier.value == null) return;

    if (shapeSnappingEnabled && shapeSnapHandler.hasSnappedShape) {
      return;
    }

    final points = currentLineNotifier.value!;
    if (points.isEmpty) return;

    final lastPoint = points.last;
    final currentPoint = Point(
      event.localPosition.dx,
      event.localPosition.dy,
      pressure: event.pressure,
    );

    final dx = currentPoint.x - lastPoint.x;
    final dy = currentPoint.y - lastPoint.y;
    final distance = math.sqrt(dx * dx + dy * dy);

    final screenDistance = distance * scale;
    const double kThreshold = 2.0;

    if (screenDistance > kThreshold) {
      final int steps = (screenDistance / kThreshold).floor();
      for (int i = 1; i < steps; i++) {
        final t = i / steps;
        points.add(
          Point(
            lastPoint.x + dx * t,
            lastPoint.y + dy * t,
            pressure:
                lastPoint.pressure +
                (currentPoint.pressure - lastPoint.pressure) * t,
          ),
        );
      }
    }

    points.add(currentPoint);
    _scheduleCurrentLineNotify();

    if (shapeSnappingEnabled) {
      shapeSnapHandler.onPointerMove(event.localPosition);
    }
  }

  void _scheduleCurrentLineNotify() {
    if (_currentLineNotifyScheduled) return;

    _currentLineNotifyScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _currentLineNotifyScheduled = false;
      final points = currentLineNotifier.value;
      if (points == null) return;
      currentLineNotifier.value = List<Point>.of(points);
    });
  }

  void handlePointerUp({
    required Color currentColor,
    required double currentWidth,
    required DrawingTool currentTool,
  }) {
    final currentLinePoints = currentLineNotifier.value;
    if (currentLinePoints == null || currentLinePoints.isEmpty) return;

    final currentSketch = sketchNotifier.value;
    final newLine = SketchLine(
      points: currentLinePoints,
      color: currentTool == DrawingTool.pixelEraser ? 0 : currentColor.value,
      width: currentWidth,
    );

    sketchNotifier.value = Sketch(lines: [...currentSketch.lines, newLine]);
    onAction(AddLinesAction([newLine]));

    currentLineNotifier.value = null;
    shapeSnapHandler.reset();
  }

  void handlePointerCancel() {
    currentLineNotifier.value = null;
    shapeSnapHandler.reset();
  }
}
