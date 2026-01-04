import 'package:flutter/material.dart';
import '../models/selection.dart';

class LinkOverlayPainter extends CustomPainter {
  final List<Selection> selections;
  final List<double> pageWidths;
  final List<double> pageHeights;
  final double scrollOffset;
  final Size viewSize;

  LinkOverlayPainter({
    required this.selections,
    required this.pageWidths,
    required this.pageHeights,
    required this.scrollOffset,
    required this.viewSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pageWidths.isEmpty || pageHeights.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black26
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    // Pre-calculate page layout
    // Note: In a real optimization, this should be cached outside paint if viewSize/pages don't change.
    // But this is still O(Pages) which is much smaller than O(Selections) usually,
    // and definitely faster than Widget building.

    final viewAspectRatio = viewSize.width / viewSize.height;
    final pageOffsets = <double>[0];
    double currentOffset = 0;

    final pageActualHeights = <double>[];
    final pageActualWidths = <double>[];
    final pageHorizontalOffsets = <double>[];

    for (int i = 0; i < pageWidths.length; i++) {
      final w = pageWidths[i];
      final h = pageHeights[i];
      final aspectRatio = w / h;

      double actualW, actualH, offX;

      if (aspectRatio > viewAspectRatio) {
        actualW = viewSize.width;
        actualH = viewSize.width / aspectRatio;
        offX = 0;
      } else {
        actualH = viewSize.height;
        actualW = viewSize.height * aspectRatio;
        offX = (viewSize.width - actualW) / 2;
      }

      pageActualWidths.add(actualW);
      pageActualHeights.add(actualH);
      pageHorizontalOffsets.add(offX);

      currentOffset += actualH;
      pageOffsets.add(currentOffset);
    }

    for (final s in selections) {
      if (s.pageIndex >= pageWidths.length) continue;

      final pageTop = pageOffsets[s.pageIndex];
      final actualW = pageActualWidths[s.pageIndex];
      final actualH = pageActualHeights[s.pageIndex];
      final offX = pageHorizontalOffsets[s.pageIndex];

      final screenLeft = offX + (s.left / pageWidths[s.pageIndex]) * actualW;
      final screenTop =
          pageTop + (s.top / pageHeights[s.pageIndex]) * actualH - scrollOffset;
      final screenWidth = (s.width / pageWidths[s.pageIndex]) * actualW;

      // Position logic from original code:
      // left: screenLeft + screenWidth - 24
      // top: screenTop
      // Container size is approx 24x24 (padding 4 + icon 16)
      // Center is at (left + 12, top + 12)

      final centerX = screenLeft + screenWidth - 24 + 12;
      final centerY = screenTop + 12;
      final center = Offset(centerX, centerY);

      // Culling: Don't draw if outside view
      if (centerY + 12 < 0 || centerY - 12 > viewSize.height) continue;

      // Draw shadow
      canvas.drawCircle(center, 12, shadowPaint);
      // Draw circle
      canvas.drawCircle(center, 12, paint);

      // Draw icon
      textPainter.text = TextSpan(
        text: String.fromCharCode(Icons.link.codePoint),
        style: TextStyle(
          fontSize: 16,
          fontFamily: Icons.link.fontFamily,
          color: Colors.white,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, center - const Offset(8, 8));
    }
  }

  @override
  bool? hitTest(Offset position) {
    return findSelectionAt(
          position: position,
          selections: selections,
          pageWidths: pageWidths,
          pageHeights: pageHeights,
          scrollOffset: scrollOffset,
          viewSize: viewSize,
        ) !=
        null;
  }

  @override
  bool shouldRepaint(covariant LinkOverlayPainter oldDelegate) {
    return oldDelegate.scrollOffset != scrollOffset ||
        oldDelegate.selections != selections ||
        oldDelegate.viewSize != viewSize ||
        oldDelegate.pageWidths != pageWidths;
  }

  // Helper for hit testing
  static Selection? findSelectionAt({
    required Offset position,
    required List<Selection> selections,
    required List<double> pageWidths,
    required List<double> pageHeights,
    required double scrollOffset,
    required Size viewSize,
  }) {
    if (pageWidths.isEmpty || pageHeights.isEmpty) return null;

    final viewAspectRatio = viewSize.width / viewSize.height;
    final pageOffsets = <double>[0];
    double currentOffset = 0;

    final pageActualHeights = <double>[];
    final pageActualWidths = <double>[];
    final pageHorizontalOffsets = <double>[];

    for (int i = 0; i < pageWidths.length; i++) {
      final w = pageWidths[i];
      final h = pageHeights[i];
      final aspectRatio = w / h;

      double actualW, actualH, offX;

      if (aspectRatio > viewAspectRatio) {
        actualW = viewSize.width;
        actualH = viewSize.width / aspectRatio;
        offX = 0;
      } else {
        actualH = viewSize.height;
        actualW = viewSize.height * aspectRatio;
        offX = (viewSize.width - actualW) / 2;
      }

      pageActualWidths.add(actualW);
      pageActualHeights.add(actualH);
      pageHorizontalOffsets.add(offX);

      currentOffset += actualH;
      pageOffsets.add(currentOffset);
    }

    for (final s in selections) {
      if (s.pageIndex >= pageWidths.length) continue;

      final pageTop = pageOffsets[s.pageIndex];
      final actualW = pageActualWidths[s.pageIndex];
      final actualH = pageActualHeights[s.pageIndex];
      final offX = pageHorizontalOffsets[s.pageIndex];

      final screenLeft = offX + (s.left / pageWidths[s.pageIndex]) * actualW;
      final screenTop =
          pageTop + (s.top / pageHeights[s.pageIndex]) * actualH - scrollOffset;
      final screenWidth = (s.width / pageWidths[s.pageIndex]) * actualW;

      final centerX = screenLeft + screenWidth - 12;
      final centerY = screenTop + 12;
      final center = Offset(centerX, centerY);

      if ((position - center).distance <= 20) {
        // 20 hit radius for easier tapping
        return s;
      }
    }
    return null;
  }
}
