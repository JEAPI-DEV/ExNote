import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:scribble/scribble.dart';

import '../../models/grid_type.dart';
import '../../utils/pdf_split_calculator.dart';
import '../../utils/sketch_bounds.dart';
import '../sketch_renderer.dart';

class A4RenderedNotePage {
  final Uint8List pngBytes;
  final double drawWidth;
  final double drawHeight;

  const A4RenderedNotePage({
    required this.pngBytes,
    required this.drawWidth,
    required this.drawHeight,
  });
}

class A4NotePageLayout {
  final Rect contentRect;
  final double exportScale;
  final List<A4NotePageSegment> segments;

  const A4NotePageLayout({
    required this.contentRect,
    required this.exportScale,
    required this.segments,
  });
}

class A4NotePageSegment {
  final double top;
  final double bottom;
  final double drawWidth;
  final double drawHeight;

  const A4NotePageSegment({
    required this.top,
    required this.bottom,
    required this.drawWidth,
    required this.drawHeight,
  });
}

class A4NotePdfRenderer {
  static const PdfPageFormat pageFormat = PdfPageFormat.a4;
  static const double pixelRatio = 2.0;

  final SketchRenderer _renderer;

  A4NotePdfRenderer({SketchRenderer? renderer})
    : _renderer = renderer ?? SketchRenderer();

  static A4NotePageLayout calculateLayout({
    required Sketch sketch,
    Rect? backgroundRect,
  }) {
    final contentRect = _calculateContentRect(
      sketch: sketch,
      backgroundRect: backgroundRect,
    );
    final exportScale = math.min(1.0, pageFormat.width / contentRect.width);
    final segmentHeight = pageFormat.height / exportScale;
    final splitPoints = findPdfSplitPoints(sketch, contentRect, segmentHeight);

    final segments = <A4NotePageSegment>[];
    for (int i = 0; i < splitPoints.length - 1; i++) {
      final top = splitPoints[i];
      final bottom = splitPoints[i + 1];
      final drawHeight = math.min(
        pageFormat.height,
        (bottom - top) * exportScale,
      );
      segments.add(
        A4NotePageSegment(
          top: top,
          bottom: bottom,
          drawWidth: pageFormat.width,
          drawHeight: drawHeight,
        ),
      );
    }

    if (segments.isEmpty) {
      segments.add(
        A4NotePageSegment(
          top: contentRect.top,
          bottom: contentRect.bottom,
          drawWidth: pageFormat.width,
          drawHeight: math.min(
            pageFormat.height,
            contentRect.height * exportScale,
          ),
        ),
      );
    }

    return A4NotePageLayout(
      contentRect: contentRect,
      exportScale: exportScale,
      segments: segments,
    );
  }

  Future<List<A4RenderedNotePage>> renderPages({
    required Sketch sketch,
    required bool gridEnabled,
    required GridType gridType,
    required double gridSpacing,
    required bool isDark,
    ui.Image? backgroundImage,
    Rect? backgroundRect,
  }) async {
    final layout = calculateLayout(
      sketch: sketch,
      backgroundRect: backgroundRect,
    );
    final pages = <A4RenderedNotePage>[];
    final renderScale = layout.exportScale * pixelRatio;

    for (final segment in layout.segments) {
      final image = await _renderer.renderToImage(
        sketch,
        size: Size(
          pageFormat.width * pixelRatio,
          segment.drawHeight * pixelRatio,
        ),
        backgroundImage: backgroundImage,
        backgroundRect: backgroundRect,
        offset: Offset(
          -layout.contentRect.left * renderScale,
          -segment.top * renderScale,
        ),
        scale: renderScale,
        gridEnabled: gridEnabled,
        gridType: gridType,
        gridSpacing: gridSpacing,
        isDark: isDark,
        verticalRange: (top: segment.top, bottom: segment.bottom),
      );

      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) continue;

      pages.add(
        A4RenderedNotePage(
          pngBytes: byteData.buffer.asUint8List(),
          drawWidth: segment.drawWidth,
          drawHeight: segment.drawHeight,
        ),
      );
    }

    return pages;
  }

  static Rect _calculateContentRect({
    required Sketch sketch,
    Rect? backgroundRect,
  }) {
    final hasSketch = sketch.lines.any((line) => line.points.isNotEmpty);
    Rect? contentRect = hasSketch ? sketch.bounds : null;

    if (backgroundRect != null &&
        backgroundRect.width > 0 &&
        backgroundRect.height > 0) {
      contentRect = contentRect == null
          ? backgroundRect
          : contentRect.expandToInclude(backgroundRect);
    }

    if (contentRect == null) {
      return Rect.fromLTWH(0, 0, pageFormat.width, pageFormat.height);
    }

    final padding = contentRect.longestSide > 0
        ? contentRect.longestSide * 0.05
        : 20.0;
    return Rect.fromLTRB(
      contentRect.left - padding,
      contentRect.top - padding,
      contentRect.right + padding,
      contentRect.bottom + padding,
    );
  }
}
