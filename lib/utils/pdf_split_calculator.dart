import 'dart:math' as math;
import 'dart:ui';
import 'package:scribble/scribble.dart';

List<double> findPdfSplitPoints(
  Sketch sketch,
  Rect contentRect,
  double targetHeight,
) {
  final double startY = contentRect.top;
  final double endY = contentRect.bottom;
  final int mapSize = (endY - startY).ceil() + 1;
  if (mapSize <= 0) return [startY, endY];

  final occupancy = List<bool>.filled(mapSize, false);

  for (final line in sketch.lines) {
    final halfWidth = line.width / 2 + 2;
    for (int i = 0; i < line.points.length - 1; i++) {
      final p1 = line.points[i];
      final p2 = line.points[i + 1];
      final top = (math.min(p1.y, p2.y) - halfWidth - startY).floor().clamp(
        0,
        mapSize - 1,
      );
      final bottom = (math.max(p1.y, p2.y) + halfWidth - startY).ceil().clamp(
        0,
        mapSize - 1,
      );
      for (int y = top; y <= bottom; y++) {
        occupancy[y] = true;
      }
    }
    if (line.points.length == 1) {
      final p = line.points[0];
      final top = (p.y - halfWidth - startY).floor().clamp(0, mapSize - 1);
      final bottom = (p.y + halfWidth - startY).ceil().clamp(0, mapSize - 1);
      for (int y = top; y <= bottom; y++) {
        occupancy[y] = true;
      }
    }
  }

  final List<double> splits = [startY];
  double currentTop = startY;

  while (currentTop < endY) {
    double nextSplit = currentTop + targetHeight;
    if (nextSplit >= endY) {
      splits.add(endY);
      break;
    }

    int bestGapIdx = -1;
    final int startSearch = (nextSplit - startY).floor().clamp(0, mapSize - 1);
    final int endSearch = (currentTop + targetHeight * 0.7 - startY)
        .floor()
        .clamp(0, mapSize - 1);

    for (int y = startSearch; y >= endSearch; y--) {
      if (!occupancy[y]) {
        bestGapIdx = y;
        break;
      }
    }

    if (bestGapIdx == -1) {
      final int endSearchDeep = (currentTop + targetHeight * 0.5 - startY)
          .floor()
          .clamp(0, mapSize - 1);
      for (int y = endSearch; y >= endSearchDeep; y--) {
        if (!occupancy[y]) {
          bestGapIdx = y;
          break;
        }
      }
    }

    double splitY = bestGapIdx == -1 ? nextSplit : startY + bestGapIdx;
    splits.add(splitY);
    currentTop = splitY;
  }

  return splits;
}
