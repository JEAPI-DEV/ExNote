import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:exnote/utils/pdf_page_geometry.dart';

void main() {
  group('PdfPageGeometry', () {
    test('maps a portrait page to the full viewport', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [400],
        pageHeights: const [800],
        scrollOffset: 0,
      );

      final rect = geometry.rectForPage(0);

      expect(rect.offsetX, 0);
      expect(rect.offsetY, 0);
      expect(rect.width, 400);
      expect(rect.height, 800);
      expect(rect.scale, 1);
      expect(rect.top, 0);
    });

    test('letterboxes a wide page vertically within the viewport slot', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [800],
        pageHeights: const [400],
        scrollOffset: 0,
      );

      final rect = geometry.rectForPage(0);

      expect(rect.scale, 0.5);
      expect(rect.width, 400);
      expect(rect.height, 200);
      expect(rect.offsetX, 0);
      expect(rect.offsetY, 300);
    });

    test('stacks pages at viewport-height intervals', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [400, 400],
        pageHeights: const [800, 800],
        scrollOffset: 0,
      );

      expect(geometry.rectForPage(0).top, 0);
      expect(geometry.rectForPage(1).top, 800);
    });

    test('accounts for scroll offset', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [400, 400],
        pageHeights: const [800, 800],
        scrollOffset: 400,
      );

      expect(geometry.rectForPage(0).top, -400);
      expect(geometry.rectForPage(1).top, 400);
    });

    test('pageIndexAt finds the page under a point', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [400, 400],
        pageHeights: const [800, 800],
        scrollOffset: 0,
      );

      expect(geometry.pageIndexAt(const Offset(200, 100)), 0);
      expect(geometry.pageIndexAt(const Offset(200, 900)), 1);
    });

    test('pageIndexAt returns null in letterbox gaps', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [800, 800],
        pageHeights: const [400, 400],
        scrollOffset: 0,
      );

      // Page 0 image occupies y in [300, 500]; the gap below it is letterbox.
      expect(geometry.pageIndexAt(const Offset(200, 700)), isNull);
      expect(geometry.pageIndexAt(const Offset(200, 400)), 0);
    });

    test('screenToPagePoint converts using page scale and offset', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [800],
        pageHeights: const [400],
        scrollOffset: 0,
      );

      // Screen (200, 400) is the center of the displayed page image.
      final pagePoint = geometry.screenToPagePoint(0, const Offset(200, 400));

      expect(pagePoint.dx, closeTo(400, 0.001));
      expect(pagePoint.dy, closeTo(200, 0.001));
    });

    test('returns no pages when page sizes are empty', () {
      final geometry = PdfPageGeometry(
        viewSize: const Size(400, 800),
        pageWidths: const [],
        pageHeights: const [],
        scrollOffset: 0,
      );

      expect(geometry.pageCount, 0);
      expect(geometry.pageIndexAt(const Offset(200, 100)), isNull);
    });
  });
}
