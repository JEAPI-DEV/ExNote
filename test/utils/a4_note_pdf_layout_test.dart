import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:scribble/scribble.dart';
import 'package:exnote/services/pdf/a4_note_pdf_renderer.dart';

Sketch _sketchFromPoints(List<Point> points, {double width = 2.0}) {
  return Sketch(
    lines: [SketchLine(points: points, color: 0xFF000000, width: width)],
  );
}

void main() {
  group('A4NotePdfRenderer layout', () {
    test('keeps narrow notes at 100 percent scale', () {
      final sketch = _sketchFromPoints([
        const Point(10, 10),
        const Point(200, 200),
      ]);

      final layout = A4NotePdfRenderer.calculateLayout(sketch: sketch);

      expect(layout.exportScale, 1.0);
      expect(layout.segments, hasLength(1));
      expect(layout.segments.single.drawWidth, PdfPageFormat.a4.width);
      expect(
        layout.segments.single.drawHeight,
        lessThan(PdfPageFormat.a4.height),
      );
    });

    test('scales wide notes down to A4 width', () {
      final sketch = _sketchFromPoints([
        const Point(0, 0),
        const Point(1000, 100),
      ]);

      final layout = A4NotePdfRenderer.calculateLayout(sketch: sketch);

      expect(layout.exportScale, lessThan(1.0));
      expect(
        layout.exportScale,
        closeTo(PdfPageFormat.a4.width / layout.contentRect.width, 0.0001),
      );
      expect(layout.segments.single.drawWidth, PdfPageFormat.a4.width);
    });

    test('splits tall notes across A4-height segments', () {
      final sketch = _sketchFromPoints([
        const Point(100, 0),
        const Point(400, 2000),
      ]);

      final layout = A4NotePdfRenderer.calculateLayout(sketch: sketch);

      expect(layout.exportScale, 1.0);
      expect(layout.segments.length, greaterThan(1));
      for (final segment in layout.segments) {
        expect(segment.drawHeight, lessThanOrEqualTo(PdfPageFormat.a4.height));
      }
    });

    test('splits wide and tall notes after applying width scale', () {
      final sketch = _sketchFromPoints([
        const Point(0, 0),
        const Point(1200, 3000),
      ]);

      final layout = A4NotePdfRenderer.calculateLayout(sketch: sketch);

      expect(layout.exportScale, lessThan(1.0));
      expect(layout.segments.length, greaterThan(1));
      for (final segment in layout.segments) {
        expect(segment.drawWidth, PdfPageFormat.a4.width);
        expect(segment.drawHeight, lessThanOrEqualTo(PdfPageFormat.a4.height));
      }
    });

    test('exports an empty sketch as one blank A4 page', () {
      final layout = A4NotePdfRenderer.calculateLayout(
        sketch: const Sketch(lines: []),
      );

      expect(layout.exportScale, 1.0);
      expect(layout.contentRect.width, PdfPageFormat.a4.width);
      expect(layout.contentRect.height, PdfPageFormat.a4.height);
      expect(layout.segments, hasLength(1));
      expect(layout.segments.single.drawHeight, PdfPageFormat.a4.height);
    });

    test('does not treat a single dot as an empty sketch', () {
      final sketch = _sketchFromPoints([const Point(0, 0)]);

      final layout = A4NotePdfRenderer.calculateLayout(sketch: sketch);

      expect(layout.exportScale, 1.0);
      expect(layout.contentRect.width, 40);
      expect(layout.contentRect.height, 40);
      expect(layout.segments, hasLength(1));
    });
  });
}
