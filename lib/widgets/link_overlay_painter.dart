import 'package:flutter/material.dart';
import '../models/selection.dart';
import '../utils/page_layout.dart';

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

  /// Converts a [Selection] to its screen-space center position.
  Offset? _selectionCenter(Selection s, PageLayout layout) {
    if (s.pageIndex >= pageWidths.length) return null;

    final screenLeft =
        layout.horizontalOffsets[s.pageIndex] +
        (s.left / pageWidths[s.pageIndex]) * layout.widths[s.pageIndex];
    final screenTop =
        layout.tops[s.pageIndex] +
        (s.top / pageHeights[s.pageIndex]) * layout.heights[s.pageIndex] -
        scrollOffset;
    final screenWidth =
        (s.width / pageWidths[s.pageIndex]) * layout.widths[s.pageIndex];

    // Icon is 24x24 positioned at (screenLeft + screenWidth - 24, screenTop)
    // Center of the icon is offset by +12 from top-left
    return Offset(screenLeft + screenWidth - 12, screenTop + 12);
  }

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

    final layout = PageLayout.calculate(
      pageWidths: pageWidths,
      pageHeights: pageHeights,
      viewSize: viewSize,
    );

    for (final s in selections) {
      final center = _selectionCenter(s, layout);
      if (center == null) continue;

      // Culling: Don't draw if outside view
      if (center.dy + 12 < 0 || center.dy - 12 > viewSize.height) continue;

      canvas.drawCircle(center, 12, shadowPaint);
      canvas.drawCircle(center, 12, paint);

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
  bool? hitTest(Offset position) =>
      findSelectionAt(
        position: position,
        selections: selections,
        pageWidths: pageWidths,
        pageHeights: pageHeights,
        scrollOffset: scrollOffset,
        viewSize: viewSize,
      ) !=
      null;

  @override
  bool shouldRepaint(covariant LinkOverlayPainter oldDelegate) =>
      oldDelegate.scrollOffset != scrollOffset ||
      oldDelegate.selections != selections ||
      oldDelegate.viewSize != viewSize ||
      oldDelegate.pageWidths != pageWidths;

  static Selection? findSelectionAt({
    required Offset position,
    required List<Selection> selections,
    required List<double> pageWidths,
    required List<double> pageHeights,
    required double scrollOffset,
    required Size viewSize,
  }) {
    if (pageWidths.isEmpty || pageHeights.isEmpty) return null;

    final layout = PageLayout.calculate(
      pageWidths: pageWidths,
      pageHeights: pageHeights,
      viewSize: viewSize,
    );

    for (final s in selections) {
      if (s.pageIndex >= pageWidths.length) continue;

      final screenLeft =
          layout.horizontalOffsets[s.pageIndex] +
          (s.left / pageWidths[s.pageIndex]) * layout.widths[s.pageIndex];
      final screenTop =
          layout.tops[s.pageIndex] +
          (s.top / pageHeights[s.pageIndex]) * layout.heights[s.pageIndex] -
          scrollOffset;
      final screenWidth =
          (s.width / pageWidths[s.pageIndex]) * layout.widths[s.pageIndex];

      final center = Offset(screenLeft + screenWidth - 12, screenTop + 12);

      if ((position - center).distance <= 20) return s;
    }
    return null;
  }
}
