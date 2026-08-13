import 'dart:ui';

/// Screen placement of a single PDF page image within the viewer.
class PdfPageScreenRect {
  /// Horizontal offset of the page image's left edge.
  final double offsetX;

  /// Vertical offset of the page image's top edge within its viewport slot.
  final double offsetY;

  /// Rendered width of the page image in screen pixels.
  final double width;

  /// Rendered height of the page image in screen pixels.
  final double height;

  /// Scale factor mapping page-point coordinates to screen pixels.
  final double scale;

  /// Screen-space top of the page image, already adjusted for scroll.
  final double top;

  const PdfPageScreenRect({
    required this.offsetX,
    required this.offsetY,
    required this.width,
    required this.height,
    required this.scale,
    required this.top,
  });
}

/// Maps between PDF page-point coordinates and viewer screen coordinates.
///
/// The `PdfView` stacks one page per viewport slot, scaling each page image to
/// fit ("contained") and centering it both horizontally and vertically. This
/// mirrors that layout so annotations stay aligned with the rendered pages.
class PdfPageGeometry {
  final Size viewSize;
  final List<double> pageWidths;
  final List<double> pageHeights;
  final double scrollOffset;

  final List<PdfPageScreenRect> _rects;

  PdfPageGeometry({
    required this.viewSize,
    required this.pageWidths,
    required this.pageHeights,
    required this.scrollOffset,
  }) : _rects = _computeRects(viewSize, pageWidths, pageHeights, scrollOffset);

  static List<PdfPageScreenRect> _computeRects(
    Size viewSize,
    List<double> pageWidths,
    List<double> pageHeights,
    double scrollOffset,
  ) {
    final rects = <PdfPageScreenRect>[];
    for (int i = 0; i < pageWidths.length; i++) {
      final pageWidth = pageWidths[i];
      final pageHeight = pageHeights[i];
      if (pageWidth <= 0 || pageHeight <= 0) {
        rects.add(
          const PdfPageScreenRect(
            offsetX: 0,
            offsetY: 0,
            width: 0,
            height: 0,
            scale: 0,
            top: 0,
          ),
        );
        continue;
      }

      final scale = _min(
        viewSize.width / pageWidth,
        viewSize.height / pageHeight,
      );
      final width = pageWidth * scale;
      final height = pageHeight * scale;
      final offsetX = (viewSize.width - width) / 2;
      final offsetY = (viewSize.height - height) / 2;
      final top = i * viewSize.height + offsetY - scrollOffset;

      rects.add(
        PdfPageScreenRect(
          offsetX: offsetX,
          offsetY: offsetY,
          width: width,
          height: height,
          scale: scale,
          top: top,
        ),
      );
    }
    return rects;
  }

  static double _min(double a, double b) => a < b ? a : b;

  /// Number of pages this geometry describes.
  int get pageCount => pageWidths.length;

  /// Screen rect of the image for the given zero-based page index.
  PdfPageScreenRect rectForPage(int pageIndex) => _rects[pageIndex];

  /// Zero-based page index containing [position], or null when the point falls
  /// in a letterbox/gap outside any page image.
  int? pageIndexAt(Offset position) {
    if (pageCount == 0) return null;

    final raw = ((position.dy + scrollOffset) / viewSize.height).floor();
    for (final i in [raw - 1, raw, raw + 1]) {
      if (i < 0 || i >= pageCount) continue;
      final rect = _rects[i];
      if (position.dx >= rect.offsetX &&
          position.dx <= rect.offsetX + rect.width &&
          position.dy >= rect.top &&
          position.dy <= rect.top + rect.height) {
        return i;
      }
    }
    return null;
  }

  /// Converts a screen position to page-point coordinates for [pageIndex].
  Offset screenToPagePoint(int pageIndex, Offset screen) {
    final rect = _rects[pageIndex];
    if (rect.scale == 0) return Offset.zero;
    return Offset(
      (screen.dx - rect.offsetX) / rect.scale,
      (screen.dy - rect.top) / rect.scale,
    );
  }
}
