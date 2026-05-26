import 'dart:async';
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';
import '../../utils/shape_recognizer.dart';

class ShapeSnapHandler {
  final ValueNotifier<List<Point>?> currentLineNotifier;

  Timer? _shapeSnapTimer;
  Offset? _lastPointerPosition;
  bool _hasSnappedShape = false;

  bool get hasSnappedShape => _hasSnappedShape;

  ShapeSnapHandler({required this.currentLineNotifier});

  void onPointerMove(Offset position) {
    final lastPos = _lastPointerPosition;
    if (lastPos != null) {
      final dist = (position - lastPos).distance;
      if (dist > 5.0) {
        _lastPointerPosition = position;
        startTimer();
      }
    }
  }

  void startTimer() {
    if (_hasSnappedShape) return;

    _shapeSnapTimer?.cancel();
    _shapeSnapTimer = Timer(
      const Duration(milliseconds: 700),
      _triggerShapeSnap,
    );
  }

  void cancelTimer() {
    _shapeSnapTimer?.cancel();
    _shapeSnapTimer = null;
  }

  void setLastPosition(Offset position) {
    _lastPointerPosition = position;
  }

  void _triggerShapeSnap() {
    _shapeSnapTimer = null;

    final points = currentLineNotifier.value;
    if (points == null || points.length < 5) return;

    final recognized = ShapeRecognizer.recognize(points);
    if (recognized != null) {
      currentLineNotifier.value = recognized.points;
      _hasSnappedShape = true;
    }
  }

  void reset() {
    cancelTimer();
    _lastPointerPosition = null;
    _hasSnappedShape = false;
  }

  void dispose() {
    reset();
  }
}
