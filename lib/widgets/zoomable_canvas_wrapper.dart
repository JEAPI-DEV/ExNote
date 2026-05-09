import 'dart:ui';
import 'package:flutter/material.dart';

class ZoomableCanvasWrapper extends StatefulWidget {
  final Widget child;
  final TransformationController transformationController;
  final double minScale;
  final double maxScale;
  final bool isZoomLocked;
  final VoidCallback? onInteraction;

  const ZoomableCanvasWrapper({
    super.key,
    required this.child,
    required this.transformationController,
    this.minScale = 0.1,
    this.maxScale = 10.0,
    this.isZoomLocked = false,
    this.onInteraction,
  });

  @override
  State<ZoomableCanvasWrapper> createState() => _ZoomableCanvasWrapperState();
}

class _ZoomableCanvasWrapperState extends State<ZoomableCanvasWrapper> {
  // Active fingers tracking
  final Map<int, Offset> _pointers = {};

  // State for gesture calculation
  Matrix4? _startMatrix;
  Offset? _startFocalPoint;
  double? _startScaleDistance;
  double? _baseScaleOnStart; // Scale factor at start of gesture

  bool _zoomActive = false;
  static const double _zoomThreshold =
      40.0; // Pixels distance change needed to unlock zoom

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerUp,
      behavior: HitTestBehavior
          .translucent, // Allow events to pass through if we don't consume/block
      child: widget.child,
    );
  }

  void _onPointerDown(PointerDownEvent event) {
    // Ignore stylus inputs for zoom/pan calculations (let them pass through for drawing)
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return;
    }

    _pointers[event.pointer] = event.position;
    _checkGestureStart();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return;
    }

    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.position;

    if (_pointers.length >= 2) {
      _updateGesture();
    }
  }

  void _onPointerUp(PointerEvent event) {
    if (event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus) {
      return;
    }

    _pointers.remove(event.pointer);

    // Reset state if we drop below 2 fingers
    if (_pointers.length < 2) {
      _startMatrix = null;
      _startFocalPoint = null;
      _startScaleDistance = null;
      _zoomActive = false;
    } else {
      // If we still have 2+ fingers (e.g. went from 3 to 2), re-snapshot to avoid jumps
      _checkGestureStart();
    }
  }

  void _checkGestureStart() {
    if (_pointers.length >= 2 && _startMatrix == null) {
      // Initialize Gesture State
      _startMatrix = widget.transformationController.value.clone();
      _startFocalPoint = _calculateFocalPoint();
      _startScaleDistance = _calculateScaleDistance();
      _baseScaleOnStart = widget.transformationController.value
          .getMaxScaleOnAxis();
      _zoomActive = false; // Reset lock
    } else if (_pointers.length >= 2 && _startMatrix != null) {
      // If pointers changed (e.g. 3rd finger added), re-sync to prevent jumps
      // But keep zoom active state if it was already active
      _startMatrix = widget.transformationController.value.clone();
      _startFocalPoint = _calculateFocalPoint();
      _startScaleDistance = _calculateScaleDistance();
    }
  }

  void _updateGesture() {
    // Notify parent of interaction
    widget.onInteraction?.call();

    if (_startMatrix == null || _startFocalPoint == null) return;

    final Offset currentFocalPoint = _calculateFocalPoint();
    final double currentScaleDistance = _calculateScaleDistance();

    // 1. Calculate Panning (Translation)
    final Offset translationDelta = currentFocalPoint - _startFocalPoint!;

    // 2. Calculate Zoom (Scale)
    double scaleRatio = 1.0;

    // "Sticky Zoom" Logic
    if (!_zoomActive && !widget.isZoomLocked) {
      // Check threshold
      final double distDiff = (currentScaleDistance - _startScaleDistance!)
          .abs();
      if (distDiff > _zoomThreshold) {
        _zoomActive = true;
        // Optionally re-sync start distance here to prevent "pop" when unlocking?
        // For now, let's just unlock. The sudden scale might be tiny if threshold is small.
        // Better feel: Reset baseline so zoom starts from *now* to avoid jump
        _startScaleDistance = currentScaleDistance;
        _startMatrix = widget.transformationController.value.clone();
        _startFocalPoint = currentFocalPoint;
        return; // Skip this frame, start transforming next frame
      }
    }

    if (_zoomActive && !widget.isZoomLocked) {
      scaleRatio = currentScaleDistance / _startScaleDistance!;
    }

    // 3. Apply Limit Constraints (Min/Max Scale)
    // Predict new scale to check bounds
    // We can just use the controller's current scale vs proposed change
    // But since we are rebuilding from _startMatrix, we need _baseScaleOnStart
    final double proposedTotalScale = (_baseScaleOnStart ?? 1.0) * scaleRatio;

    if (proposedTotalScale < widget.minScale) {
      scaleRatio = widget.minScale / (_baseScaleOnStart ?? 1.0);
    } else if (proposedTotalScale > widget.maxScale) {
      scaleRatio = widget.maxScale / (_baseScaleOnStart ?? 1.0);
    }

    // 4. Construct Transformation
    // We want to scale around the START focal point (relative to the content),
    // then translate by the finger movement.

    // Matrix Math:
    // Start with the matrix as it was when gesture began.
    // Translate so the focal point is at (0,0).
    // Scale.
    // Translate back.
    // Apply the finger drag translation.

    // Actually, simpler:
    // The content was at `_startMatrix`.
    // We want to pivot around `_startFocalPoint` (in viewport coordinates).
    // Then shift by `translationDelta`.

    // Viewport pivot relative to the transformed local space is hard.
    // Standard approach:
    // Translate(-focal), Scale, Translate(focal), Translate(delta).

    // But `_startMatrix` is the full transform.
    // We apply the delta to the viewport (post-multiply).

    final Matrix4 translation = Matrix4.translationValues(
      translationDelta.dx,
      translationDelta.dy,
      0.0,
    );

    final Matrix4 pivot = Matrix4.translationValues(
      _startFocalPoint!.dx,
      _startFocalPoint!.dy,
      0.0,
    );
    final Matrix4 pivotInv = Matrix4.translationValues(
      -_startFocalPoint!.dx,
      -_startFocalPoint!.dy,
      0.0,
    );
    final Matrix4 scale = Matrix4.diagonal3Values(scaleRatio, scaleRatio, 1.0);

    // Order: InvPivot -> Scale -> Pivot -> Translation -> Original
    // Correct Order for post-multiplication (applying to the whole view):
    // New = Translation * Pivot * Scale * PivotInv * Old

    final Matrix4 newMatrix =
        translation * pivot * scale * pivotInv * _startMatrix!;

    // 5. Clamp Boundaries
    // We want to prevent dragging top-left corner into positive space (void).
    // Matrix cells [12] (x) and [13] (y) represent the global translation.
    if (newMatrix[12] > 0) newMatrix[12] = 0;
    if (newMatrix[13] > 0) newMatrix[13] = 0;

    widget.transformationController.value = newMatrix;
  }

  Offset _calculateFocalPoint() {
    // Average of all active pointers
    double sx = 0, sy = 0;
    for (final pos in _pointers.values) {
      sx += pos.dx;
      sy += pos.dy;
    }
    return Offset(sx / _pointers.length, sy / _pointers.length);
  }

  double _calculateScaleDistance() {
    // Average distance from focal point? Or just distance between first 2?
    // Most standard is average span.
    // Let's settle for distance between the first 2 returned by map (stable enough for mult-touch)
    if (_pointers.length < 2) return 1.0;

    final points = _pointers.values.toList();
    final p1 = points[0];
    final p2 = points[1];

    return (p1 - p2).distance;
  }
}
