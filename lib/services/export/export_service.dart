import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:scribble/scribble.dart';
import '../../models/canvas_object.dart';
import '../../models/grid_type.dart';
import '../../utils/export_directory.dart';
import '../pdf/a4_note_pdf_renderer.dart';
import 'canvas_capture_service.dart';
import 'png_export_service.dart';
import 'zip_backup_service.dart';

export 'canvas_capture_service.dart';
export 'png_export_service.dart';
export 'zip_backup_service.dart';

class ExportService {
  static Future<File> exportToZip() => ZipBackupService.createBackup();

  static Future<File> exportToPng(GlobalKey exportKey, BuildContext context) =>
      PngExportService.exportToPng(exportKey, context);

  static Future<String?> captureCanvas(GlobalKey exportKey) =>
      CanvasCaptureService.captureCanvas(exportKey);

  static Future<File> exportToPdf({
    required Sketch sketch,
    List<CanvasObject> objects = const [],
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
    final renderedPages = await A4NotePdfRenderer().renderPages(
      sketch: sketch,
      objects: objects,
      backgroundImage: backgroundImage,
      backgroundRect: backgroundRect,
      gridEnabled: gridEnabled,
      gridType: gridType,
      gridSpacing: gridSpacing,
      isDark: isDark,
    );

    if (renderedPages.isEmpty) {
      throw Exception('Failed to render PDF pages');
    }

    debugPrint("[ExportService] Offloading PDF generation to background...");
    final dir = await ExportDirectory.get();
    final String finalFilename =
        filename ?? 'exnote_export_${DateTime.now().millisecondsSinceEpoch}';
    final String filePath = '${dir.path}/$finalFilename.pdf';

    await compute(_generateAndSavePdf, {
      'pages': renderedPages
          .map(
            (page) => {
              'image': page.pngBytes,
              'drawWidth': page.drawWidth,
              'drawHeight': page.drawHeight,
            },
          )
          .toList(),
      'filePath': filePath,
    });

    debugPrint("[ExportService] PDF saved to $filePath");
    return File(filePath);
  }

  static Future<void> _generateAndSavePdf(Map<String, dynamic> data) async {
    final List<dynamic> pages = data['pages'];
    final String filePath = data['filePath'];

    final doc = pw.Document();

    for (final page in pages) {
      final pageData = page as Map<dynamic, dynamic>;
      final pwImage = pw.MemoryImage(pageData['image'] as Uint8List);
      final drawWidth = pageData['drawWidth'] as double;
      final drawHeight = pageData['drawHeight'] as double;

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) {
            return pw.Container(
              alignment: pw.Alignment.topLeft,
              child: pw.Image(
                pwImage,
                width: drawWidth,
                height: drawHeight,
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
