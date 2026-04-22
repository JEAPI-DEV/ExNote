import 'dart:ui';
import 'package:scribble/scribble.dart';

/// Extension methods for computing [Sketch] bounds.
extension SketchBounds on Sketch {
  /// Returns the bounding [Rect] that encloses all points in this sketch.
  /// Returns [Rect.zero] if the sketch is empty.
  Rect get bounds => _computeLineBounds(lines);
}

/// Computes the bounding [Rect] for a list of [SketchLine]s.
/// Returns [Rect.zero] if the list is empty.
Rect computeLineBounds(List<SketchLine> lines) => _computeLineBounds(lines);

Rect _computeLineBounds(List<SketchLine> lines) {
  if (lines.isEmpty) return Rect.zero;

  double minX = double.infinity, maxX = double.negativeInfinity;
  double minY = double.infinity, maxY = double.negativeInfinity;

  for (final line in lines) {
    for (final p in line.points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
  }

  if (minX == double.infinity) return Rect.zero;
  return Rect.fromLTRB(minX, minY, maxX, maxY);
}
