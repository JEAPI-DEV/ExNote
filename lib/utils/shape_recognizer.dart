import 'dart:math' as math;
import 'dart:ui';
import 'package:scribble/scribble.dart';

enum ShapeType {
  circle,
  ellipse,
  triangle,
  square,
  rectangle,
  pentagon,
  hexagon,
  line,
}

class RecognizedShape {
  final ShapeType type;
  final List<Point> points;

  RecognizedShape({required this.type, required this.points});
}

class ShapeRecognizer {
  static RecognizedShape? recognize(List<Point> points) {
    if (points.length < 5) {
      print("[ShapeRecognizer] Too few points: ${points.length}");
      return null;
    }

    final rect = _getBoundingBox(points);
    final center = rect.center;
    final width = rect.width;
    final height = rect.height;

    // 1. Check for Circle/Ellipse
    final circularity = _calculateCircularity(points, rect);
    print("[ShapeRecognizer] Circularity: $circularity, Rect: $rect");
    if (circularity > 0.8) {
      // For circles/ellipses, we also want to ensure it's somewhat closed
      if (!_isClosed(points, rect, threshold: 0.4)) {
        print("[ShapeRecognizer] Circle/Ellipse rejected: Not closed enough");
      } else {
        if ((width - height).abs() / math.max(width, height) < 0.2) {
          print("[ShapeRecognizer] Detected Circle");
          return RecognizedShape(
            type: ShapeType.circle,
            points: _generateEllipsePoints(
              center,
              math.max(width, height) / 2,
              math.max(width, height) / 2,
            ),
          );
        } else {
          print("[ShapeRecognizer] Detected Ellipse");
          return RecognizedShape(
            type: ShapeType.ellipse,
            points: _generateEllipsePoints(center, width / 2, height / 2),
          );
        }
      }
    }

    // 2. Corner Detection for Polygons
    final corners = _detectCorners(points, rect);
    print("[ShapeRecognizer] Detected ${corners.length} corners: $corners");

    if (corners.length == 2) {
      print("[ShapeRecognizer] Detected Line");
      return RecognizedShape(
        type: ShapeType.line,
        points: _generatePolygonPoints(corners),
      );
    }

    // Fuzzy corner count for polygons
    int cornerCount = corners.length;
    List<Offset> refinedCorners = corners;

    // If we have 4 or 5 corners, check if one side is very short (likely a triangle with a hook or extra point)
    if (cornerCount == 4 || cornerCount == 5) {
      final sides = <double>[];
      for (int i = 0; i < cornerCount; i++) {
        sides.add(
          (refinedCorners[i] - refinedCorners[(i + 1) % cornerCount]).distance,
        );
      }
      final maxSide = sides.reduce(math.max);
      final minSideIdx = sides.indexOf(sides.reduce(math.min));

      if (sides[minSideIdx] < maxSide * 0.15) {
        print(
          "[ShapeRecognizer] One side is very short (${sides[minSideIdx]}), merging corners.",
        );
        refinedCorners = List.from(refinedCorners)
          ..removeAt((minSideIdx + 1) % cornerCount);
        cornerCount = refinedCorners.length;
      }
    }

    if (cornerCount == 3) {
      if (!_isClosed(points, rect)) {
        print("[ShapeRecognizer] Triangle rejected: Not closed");
        return null;
      }
      print("[ShapeRecognizer] Detected Triangle");
      return RecognizedShape(
        type: ShapeType.triangle,
        points: _generatePolygonPoints(refinedCorners),
      );
    } else if (cornerCount == 4) {
      if (!_isClosed(points, rect)) {
        print("[ShapeRecognizer] Rectangle/Square rejected: Not closed");
        return null;
      }
      // Check if it's a square or rectangle
      final side1 = (refinedCorners[0] - refinedCorners[1]).distance;
      final side2 = (refinedCorners[1] - refinedCorners[2]).distance;
      final side3 = (refinedCorners[2] - refinedCorners[3]).distance;
      final side4 = (refinedCorners[3] - refinedCorners[0]).distance;

      final avgSide = (side1 + side2 + side3 + side4) / 4;
      final sideVariance =
          [
            side1,
            side2,
            side3,
            side4,
          ].fold(0.0, (sum, s) => sum + (s - avgSide).abs()) /
          4;
      final ratio = side1 / (side2 == 0 ? 0.001 : side2);

      print(
        "[ShapeRecognizer] 4 corners, avgSide: $avgSide, variance: $sideVariance, ratio: $ratio",
      );

      // Tightened threshold from 0.25 to 0.12 for square detection
      if (sideVariance / avgSide < 0.12 && (ratio - 1.0).abs() < 0.15) {
        print("[ShapeRecognizer] Detected Square");
        return RecognizedShape(
          type: ShapeType.square,
          points: _generateRectanglePoints(rect, isSquare: true),
        );
      } else {
        print("[ShapeRecognizer] Detected Rectangle");
        return RecognizedShape(
          type: ShapeType.rectangle,
          points: _generateRectanglePoints(rect),
        );
      }
    } else if (cornerCount == 5) {
      if (!_isClosed(points, rect)) {
        print("[ShapeRecognizer] Pentagon rejected: Not closed");
        return null;
      }
      print("[ShapeRecognizer] Detected Pentagon");
      return RecognizedShape(
        type: ShapeType.pentagon,
        points: _generatePolygonPoints(refinedCorners),
      );
    } else if (cornerCount == 6) {
      if (!_isClosed(points, rect)) {
        print("[ShapeRecognizer] Hexagon rejected: Not closed");
        return null;
      }
      print("[ShapeRecognizer] Detected Hexagon");
      return RecognizedShape(
        type: ShapeType.hexagon,
        points: _generatePolygonPoints(refinedCorners),
      );
    }

    print("[ShapeRecognizer] No shape recognized");
    return null;
  }

  static Rect _getBoundingBox(List<Point> points) {
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (final p in points) {
      if (p.x < minX) minX = p.x;
      if (p.x > maxX) maxX = p.x;
      if (p.y < minY) minY = p.y;
      if (p.y > maxY) maxY = p.y;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  static double _calculateCircularity(List<Point> points, Rect rect) {
    final center = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;
    if (rx == 0 || ry == 0) return 0;

    double totalError = 0;
    double maxError = 0;
    for (final p in points) {
      final dx = (p.x - center.dx) / rx;
      final dy = (p.y - center.dy) / ry;
      final dist = math.sqrt(dx * dx + dy * dy);
      final error = (dist - 1.0).abs();
      totalError += error;
      if (error > maxError) maxError = error;
    }
    final avgError = totalError / points.length;

    // For a circle, avgError should be very low (< 0.1)
    // and maxError should also be relatively low (< 0.2)
    print("[ShapeRecognizer] avgError: $avgError, maxError: $maxError");
    if (avgError < 0.12 && maxError < 0.3) {
      return 1.0 - avgError;
    }
    return 0;
  }

  static List<Offset> _detectCorners(List<Point> points, Rect rect) {
    if (points.length < 10) return [];

    // Use a relative epsilon for RDP
    final epsilon = math.max(rect.width, rect.height) * 0.08;
    print("[ShapeRecognizer] Using epsilon: $epsilon for RDP");

    final simplified = _simplifyPoints(points, epsilon);
    print("[ShapeRecognizer] Simplified to ${simplified.length} points");

    // Post-process: merge points that are too close
    final merged = <Offset>[];
    if (simplified.isNotEmpty) {
      merged.add(simplified.first);
      final minCornerDist = math.max(rect.width, rect.height) * 0.15;
      for (int i = 1; i < simplified.length; i++) {
        if ((simplified[i] - merged.last).distance > minCornerDist) {
          merged.add(simplified[i]);
        }
      }
    }
    print("[ShapeRecognizer] Merged by distance to ${merged.length} corners");

    // Post-process: merge nearly collinear points
    if (merged.length > 2) {
      final collinearMerged = <Offset>[merged.first];
      for (int i = 1; i < merged.length - 1; i++) {
        final p1 = merged[i - 1];
        final p2 = merged[i];
        final p3 = merged[i + 1];

        final v1 = p2 - p1;
        final v2 = p3 - p2;

        if (v1.distance == 0 || v2.distance == 0) continue;

        final angle =
            (v1.dx * v2.dx + v1.dy * v2.dy) / (v1.distance * v2.distance);
        // If angle is close to 1 (cos(0) = 1), they are collinear
        if (angle < 0.95) {
          // Roughly 18 degrees
          collinearMerged.add(p2);
        } else {
          print("[ShapeRecognizer] Merging nearly collinear points at $p2");
        }
      }
      collinearMerged.add(merged.last);
      merged.clear();
      merged.addAll(collinearMerged);
    }
    print(
      "[ShapeRecognizer] Merged by collinearity to ${merged.length} corners",
    );

    // Further refine: if it's a closed shape, the first and last points should be the same
    if (merged.length > 2) {
      final dist = (merged.first - merged.last).distance;
      // Tightened closure threshold for corner detection to avoid accidental closure
      if (dist < math.max(rect.width, rect.height) * 0.25) {
        print("[ShapeRecognizer] Closing shape (dist: $dist)");
        merged.removeLast();
      }
    }

    return merged;
  }

  static List<Offset> _simplifyPoints(List<Point> points, double epsilon) {
    if (points.length < 3) return points.map((p) => Offset(p.x, p.y)).toList();

    List<Offset> offsets = points.map((p) => Offset(p.x, p.y)).toList();
    return _rdp(offsets, epsilon);
  }

  static List<Offset> _rdp(List<Offset> points, double epsilon) {
    if (points.length < 3) return points;

    int index = -1;
    double maxDist = 0;

    for (int i = 1; i < points.length - 1; i++) {
      double dist = _perpendicularDistance(
        points[i],
        points.first,
        points.last,
      );
      if (dist > maxDist) {
        index = i;
        maxDist = dist;
      }
    }

    if (maxDist > epsilon) {
      final left = _rdp(points.sublist(0, index + 1), epsilon);
      final right = _rdp(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    } else {
      return [points.first, points.last];
    }
  }

  static double _perpendicularDistance(Offset p, Offset a, Offset b) {
    final num = ((b.dx - a.dx) * (a.dy - p.dy) - (a.dx - p.dx) * (b.dy - a.dy))
        .abs();
    final den = math.sqrt(math.pow(b.dx - a.dx, 2) + math.pow(b.dy - a.dy, 2));
    if (den == 0) return (p - a).distance;
    return num / den;
  }

  static bool _isClosed(
    List<Point> points,
    Rect rect, {
    double threshold = 0.3,
  }) {
    if (points.length < 2) return false;
    final start = Offset(points.first.x, points.first.y);
    final end = Offset(points.last.x, points.last.y);
    final dist = (start - end).distance;
    final maxDim = math.max(rect.width, rect.height);
    if (maxDim == 0) return false;
    return dist < maxDim * threshold;
  }

  static List<Point> _generateEllipsePoints(
    Offset center,
    double rx,
    double ry,
  ) {
    final points = <Point>[];
    const int count = 100;
    for (int i = 0; i <= count; i++) {
      final angle = 2 * math.pi * i / count;
      points.add(
        Point(
          center.dx + rx * math.cos(angle),
          center.dy + ry * math.sin(angle),
          pressure: 1.0,
        ),
      );
    }
    return points;
  }

  static List<Point> _generateRectanglePoints(
    Rect rect, {
    bool isSquare = false,
  }) {
    double left = rect.left;
    double top = rect.top;
    double right = rect.right;
    double bottom = rect.bottom;

    if (isSquare) {
      final size = math.max(rect.width, rect.height);
      final center = rect.center;
      left = center.dx - size / 2;
      right = center.dx + size / 2;
      top = center.dy - size / 2;
      bottom = center.dy + size / 2;
    }

    final corners = [
      Offset(left, top),
      Offset(right, top),
      Offset(right, bottom),
      Offset(left, bottom),
      Offset(left, top),
    ];
    return _generatePolygonPoints(corners);
  }

  static List<Point> _generatePolygonPoints(List<Offset> corners) {
    final points = <Point>[];
    // Ensure it's closed
    final closedCorners = List<Offset>.from(corners);
    if ((closedCorners.first - closedCorners.last).distance > 1.0) {
      closedCorners.add(closedCorners.first);
    }

    for (int i = 0; i < closedCorners.length - 1; i++) {
      final start = closedCorners[i];
      final end = closedCorners[i + 1];
      final dist = (end - start).distance;
      final steps = (dist / 2.0).clamp(2.0, 100.0).toInt();
      for (int j = 0; j < steps; j++) {
        final t = j / steps;
        points.add(
          Point(
            start.dx + (end.dx - start.dx) * t,
            start.dy + (end.dy - start.dy) * t,
            pressure: 1.0,
          ),
        );
      }
    }
    points.add(
      Point(closedCorners.last.dx, closedCorners.last.dy, pressure: 1.0),
    );
    return points;
  }
}
