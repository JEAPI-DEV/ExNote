import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:exnote/utils/shape_recognizer.dart';

List<Point> _generateEdgePoints(Point start, Point end, int count) {
  final points = <Point>[];
  for (int i = 0; i < count; i++) {
    final t = i / count;
    points.add(
      Point(start.x + (end.x - start.x) * t, start.y + (end.y - start.y) * t),
    );
  }
  return points;
}

void main() {
  group('ShapeRecognizer', () {
    test('recognizes a perfect square', () {
      final points = [
        ..._generateEdgePoints(const Point(0, 0), const Point(100, 0), 10),
        ..._generateEdgePoints(const Point(100, 0), const Point(100, 100), 10),
        ..._generateEdgePoints(const Point(100, 100), const Point(0, 100), 10),
        ..._generateEdgePoints(const Point(0, 100), const Point(0, 0), 10),
        const Point(0, 0),
      ];
      final result = ShapeRecognizer.recognize(points);
      expect(result?.type, ShapeType.square);
    });

    test('recognizes a clear rectangle', () {
      final points = [
        ..._generateEdgePoints(const Point(0, 0), const Point(200, 0), 10),
        ..._generateEdgePoints(const Point(200, 0), const Point(200, 100), 10),
        ..._generateEdgePoints(const Point(200, 100), const Point(0, 100), 10),
        ..._generateEdgePoints(const Point(0, 100), const Point(0, 0), 10),
        const Point(0, 0),
      ];
      final result = ShapeRecognizer.recognize(points);
      expect(result?.type, ShapeType.rectangle);
    });

    test('rejects an open square root shape', () {
      final points = [
        ..._generateEdgePoints(const Point(10, 50), const Point(20, 100), 5),
        ..._generateEdgePoints(const Point(20, 100), const Point(50, 10), 5),
        ..._generateEdgePoints(const Point(50, 10), const Point(150, 10), 10),
      ];
      final result = ShapeRecognizer.recognize(points);
      expect(result, isNull);
    });

    test('rejects an open rectangle-like shape', () {
      final points = [
        ..._generateEdgePoints(const Point(0, 0), const Point(100, 0), 10),
        ..._generateEdgePoints(const Point(100, 0), const Point(100, 100), 10),
        ..._generateEdgePoints(const Point(100, 100), const Point(0, 100), 10),
      ];
      final result = ShapeRecognizer.recognize(points);
      expect(result, isNull);
    });

    test('recognizes a circle', () {
      final points = <Point>[];
      const int count = 40;
      for (int i = 0; i <= count; i++) {
        final angle = 2 * math.pi * i / count;
        points.add(Point(50 + 50 * math.cos(angle), 50 + 50 * math.sin(angle)));
      }
      final result = ShapeRecognizer.recognize(points);
      expect(result?.type, ShapeType.circle);
    });

    test('recognizes an ellipse', () {
      final points = <Point>[];
      const int count = 40;
      for (int i = 0; i <= count; i++) {
        final angle = 2 * math.pi * i / count;
        points.add(
          Point(100 + 100 * math.cos(angle), 50 + 50 * math.sin(angle)),
        );
      }
      final result = ShapeRecognizer.recognize(points);
      expect(result?.type, ShapeType.ellipse);
    });
  });
}
