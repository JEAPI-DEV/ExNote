import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:scribble/scribble.dart';
import '../../models/grid_type.dart';
import '../../services/sketch_renderer.dart';
import '../../utils/sketch_bounds.dart';
import '../../utils/export_directory.dart';
import '../../utils/pdf_split_calculator.dart';
import 'canvas_capture_service.dart';
import 'png_export_service.dart';
import 'zip_export_service.dart';

export 'canvas_capture_service.dart';
export 'png_export_service.dart';
export 'zip_export_service.dart';

class ExportService {
  static Future<File> exportToZip() => ZipExportService.exportToZip();

  static Future<File> exportToPng(GlobalKey exportKey, BuildContext context) =>
      PngExportService.exportToPng(exportKey, context);

  static Future<String?> captureCanvas(GlobalKey exportKey) =>
      CanvasCaptureService.captureCanvas(exportKey);

  static Future<File> exportToPdf({
    required Sketch sketch,
    required BuildContext context,
    String? filename,
    bool gridEnabled = false,
    GridType gridType = GridType.grid,
    double gridSpacing = 40.0,
    bool isDark = false,
    ui.Image? backgroundImage,
    Rect? backgroundRect,
  }) async {
    debugPrint("[ExportService] Starting PDF export...");
    final SketchRenderer renderer = SketchRenderer();

    Rect sketchBounds = sketch.bounds;
    debugPrint("[ExportService] Sketch bounds: $sketchBounds");
    if (sketchBounds == Rect.zero) {
      sketchBounds = const Rect.fromLTWH(0, 0, 595, 842);
    }

    final padding = sketchBounds.width * 0.05;
    final contentRect = Rect.fromLTRB(
      sketchBounds.left - padding,
      sketchBounds.top - padding,
      sketchBounds.right + padding,
      sketchBounds.bottom + padding,
    );

    final double pageWidth = contentRect.width;
    const double targetPageHeight = 842.0;

    debugPrint("[ExportService] Finding split points...");
    final List<double> splitPoints = findPdfSplitPoints(
      sketch,
      contentRect,
      targetPageHeight,
    );
    debugPrint("[ExportService] Found ${splitPoints.length - 1} pages.");

    final List<Uint8List> pageImages = [];
    final List<double> segmentHeights = [];

    for (int i = 0; i < splitPoints.length - 1; i++) {
      final top = splitPoints[i];
      final bottom = splitPoints[i + 1];
      final segmentHeight = bottom - top;
      debugPrint(
        "[ExportService] Rendering page ${i + 1} (height: $segmentHeight)...",
      );

      final Size canvasSize = Size(pageWidth * 2, segmentHeight * 2);

      final ui.Image pageImage = await renderer.renderToImage(
        sketch,
        size: canvasSize,
        backgroundImage: backgroundImage,
        backgroundRect: backgroundRect,
        isDark: isDark,
        offset: Offset(-contentRect.left * 2, -top * 2),
        scale: 2.0,
        gridEnabled: gridEnabled,
        gridType: gridType,
        gridSpacing: gridSpacing * 2,
        verticalRange: (top: top, bottom: bottom),
      );

      final byteData = await pageImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      pageImage.dispose();

      if (byteData == null) continue;
      pageImages.add(byteData.buffer.asUint8List());
      segmentHeights.add(segmentHeight);
    }

    debugPrint("[ExportService] Offloading PDF generation to background...");
    final dir = await ExportDirectory.get();
    final String finalFilename =
        filename ?? 'exnote_export_${DateTime.now().millisecondsSinceEpoch}';
    final String filePath = '${dir.path}/$finalFilename.pdf';

    await compute(_generateAndSavePdf, {
      'images': pageImages,
      'pageWidth': pageWidth,
      'targetPageHeight': targetPageHeight,
      'segmentHeights': segmentHeights,
      'filePath': filePath,
    });

    debugPrint("[ExportService] PDF saved to $filePath");
    return File(filePath);
  }

  static Future<void> _generateAndSavePdf(Map<String, dynamic> data) async {
    final List<Uint8List> images = data['images'];
    final double pageWidth = data['pageWidth'];
    final double targetPageHeight = data['targetPageHeight'];
    final List<double> segmentHeights = data['segmentHeights'];
    final String filePath = data['filePath'];

    final doc = pw.Document();

    for (int i = 0; i < images.length; i++) {
      final pwImage = pw.MemoryImage(images[i]);
      final segmentHeight = segmentHeights[i];

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, targetPageHeight),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.topCenter,
              child: pw.Image(
                pwImage,
                width: pageWidth,
                height: segmentHeight,
                fit: pw.BoxFit.fill,
              ),
            );
          },
        ),
      );
    }

    final file = File(filePath);
    await file.writeAsBytes(await doc.save());
  }
}
