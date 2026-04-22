import 'dart:ui';

/// Computes page layout metrics for mapping PDF coordinates to screen coordinates.
class PageLayout {
  final List<double> tops;
  final List<double> heights;
  final List<double> widths;
  final List<double> horizontalOffsets;

  const PageLayout({
    required this.tops,
    required this.heights,
    required this.widths,
    required this.horizontalOffsets,
  });

  /// Pre-computes layout for all pages given their PDF dimensions and the viewport size.
  factory PageLayout.calculate({
    required List<double> pageWidths,
    required List<double> pageHeights,
    required Size viewSize,
  }) {
    final viewAspectRatio = viewSize.width / viewSize.height;
    final tops = <double>[0];
    final heights = <double>[];
    final widths = <double>[];
    final horizontalOffsets = <double>[];
    double currentOffset = 0;

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

      widths.add(actualW);
      heights.add(actualH);
      horizontalOffsets.add(offX);

      currentOffset += actualH;
      tops.add(currentOffset);
    }

    return PageLayout(
      tops: tops,
      heights: heights,
      widths: widths,
      horizontalOffsets: horizontalOffsets,
    );
  }
}
