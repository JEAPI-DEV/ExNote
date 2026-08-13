import 'package:flutter/material.dart';
import 'package:scribble/scribble.dart';

import '../services/sketch_renderer.dart';
import '../utils/pdf_page_geometry.dart';

/// Paints committed annotations and the in-progress stroke over the PDF.
///
/// Each page's sketch is stored in page-point coordinates; the painter maps
/// them to screen space using [PdfPageGeometry] and the shared [SketchRenderer].
class PdfAnnotationPainter extends CustomPainter {
  final Map<int, Sketch> annotations;
  final int activePageIndex;
  final Sketch activeSketch;
  final List<Point>? activeLine;
  final Color activeColor;
  final double activeWidth;
  final bool isDark;
  final PdfPageGeometry geometry;

  final SketchRenderer _renderer = SketchRenderer();

  PdfAnnotationPainter({
    required this.annotations,
    required this.activePageIndex,
    required this.activeSketch,
    required this.activeLine,
    required this.activeColor,
    required this.activeWidth,
    required this.isDark,
    required this.geometry,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (geometry.pageCount == 0) return;

    for (int i = 0; i < geometry.pageCount; i++) {
      final rect = geometry.rectForPage(i);
      if (rect.top + rect.height < 0 || rect.top > size.height) continue;

      final sketch = i == activePageIndex
          ? activeSketch
          : (annotations[i] ?? const Sketch(lines: []));
      if (sketch.lines.isEmpty) continue;

      _drawSketch(canvas, i, rect, sketch);
    }

    final line = activeLine;
    if (line != null && line.isNotEmpty && activePageIndex < geometry.pageCount) {
      final rect = geometry.rectForPage(activePageIndex);
      canvas.save();
      canvas.translate(rect.offsetX, rect.top);
      canvas.scale(rect.scale);
      canvas.clipRect(
        Rect.fromLTWH(
          0,
          0,
          geometry.pageWidths[activePageIndex],
          geometry.pageHeights[activePageIndex],
        ),
      );
      _renderer.drawLine(
        canvas,
        line,
        activeColor,
        activeWidth,
        isDark: isDark,
        scale: 1.0,
      );
      canvas.restore();
    }
  }

  void _drawSketch(
    Canvas canvas,
    int pageIndex,
    PdfPageScreenRect rect,
    Sketch sketch,
  ) {
    canvas.save();
    canvas.translate(rect.offsetX, rect.top);
    canvas.scale(rect.scale);
    canvas.clipRect(
      Rect.fromLTWH(
        0,
        0,
        geometry.pageWidths[pageIndex],
        geometry.pageHeights[pageIndex],
      ),
    );
    canvas.drawPicture(
      _renderer.renderSketch(sketch: sketch, isDark: isDark, scale: 1.0),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PdfAnnotationPainter oldDelegate) =>
      oldDelegate.annotations != annotations ||
      oldDelegate.activePageIndex != activePageIndex ||
      oldDelegate.activeSketch != activeSketch ||
      oldDelegate.activeLine != activeLine ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.activeWidth != activeWidth ||
      oldDelegate.isDark != isDark ||
      oldDelegate.geometry != geometry;
}
