import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

bool isLineHit(
  SketchLine line,
  Offset hitPoint,
  double radius,
  Map<SketchLine, Rect> boundsCache,
) {
  if (line.points.isEmpty) return false;

  final bounds = boundsCache.putIfAbsent(line, () {
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final p in line.points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  });

  if (hitPoint.dx < bounds.left - radius ||
      hitPoint.dx > bounds.right + radius ||
      hitPoint.dy < bounds.top - radius ||
      hitPoint.dy > bounds.bottom + radius) {
    return false;
  }

  for (int i = 0; i < line.points.length - 1; i++) {
    final p1 = Offset(line.points[i].x, line.points[i].y);
    final p2 = Offset(line.points[i + 1].x, line.points[i + 1].y);

    if (distanceToSegment(hitPoint, p1, p2) <= radius) {
      return true;
    }
  }

  return false;
}

double distanceToSegment(Offset p, Offset a, Offset b) {
  final pa = p - a;
  final ba = b - a;
  final denom = ba.dx * ba.dx + ba.dy * ba.dy;
  if (denom == 0) return (p - a).distance;
  final h = (pa.dx * ba.dx + pa.dy * ba.dy) / denom;
  final clampedH = h.clamp(0.0, 1.0);
  final closest = a + ba * clampedH;
  return (p - closest).distance;
}
