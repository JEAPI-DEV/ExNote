import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:scribble/scribble.dart';
import '../models/exercise_list.dart';
import '../models/grid_type.dart';
import '../services/sketch_renderer.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';

class PdfExportService {
  final StorageService _storage = StorageService();
  final SketchRenderer _renderer = SketchRenderer();

  Future<File> exportExerciseListToPdf(ExerciseList list) async {
    final doc = pw.Document();
    final pdfFile = File(list.pdfPath);

    if (!pdfFile.existsSync()) {
      throw Exception('Original PDF file not found at ${list.pdfPath}');
    }

    // Load settings for grid and theme
    final settings = await SettingsService.loadSettings();
    final bool gridEnabled = settings['gridEnabled'] ?? false;
    final GridType gridType = settings['gridType'] ?? GridType.grid;
    final double gridSpacing = settings['gridSpacing'] ?? 40.0;
    // We'll use light mode for PDF export usually, but we can follow settings
    final bool isDark = false; // Usually PDFs are light

    // Open original PDF
    final pdfDocument = await pdfx.PdfDocument.openFile(pdfFile.path);
    PdfPageFormat? firstPageFormat;

    // 1. Render original pages and add links
    for (int i = 1; i <= pdfDocument.pagesCount; i++) {
      final page = await pdfDocument.getPage(i);
      if (i == 1) {
        firstPageFormat = PdfPageFormat(page.width, page.height);
      }
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: pdfx.PdfPageImageFormat.png,
      );

      final pwImage = pw.MemoryImage(pageImage!.bytes);

      final pageSelections = list.selections
          .where((s) => s.pageIndex == i - 1)
          .toList();

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(page.width, page.height),
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                pw.Image(pwImage),
                for (final s in pageSelections)
                  pw.Positioned(
                    left: s.left + s.width - 24,
                    top: s.top,
                    child: pw.SizedBox(
                      width: 24,
                      height: 24,
                      child: pw.Link(
                        destination: s.id,
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            color: PdfColors.blue,
                            shape: pw.BoxShape.circle,
                            border: pw.Border.all(
                              color: PdfColors.white,
                              width: 1,
                            ),
                          ),
                          child: pw.Center(
                            child: pw.Stack(
                              children: [
                                pw.Positioned(
                                  left: 3,
                                  top: 7,
                                  child: pw.Container(
                                    width: 6,
                                    height: 6,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(
                                        color: PdfColors.white,
                                        width: 1.5,
                                      ),
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                ),
                                pw.Positioned(
                                  left: 7,
                                  top: 3,
                                  child: pw.Container(
                                    width: 6,
                                    height: 6,
                                    decoration: pw.BoxDecoration(
                                      border: pw.Border.all(
                                        color: PdfColors.white,
                                        width: 1.5,
                                      ),
                                      shape: pw.BoxShape.circle,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      );
      await page.close();
    }

    final notePageFormat = firstPageFormat ?? PdfPageFormat.a4;

    // 2. Add note pages
    for (final s in list.selections) {
      final noteData = await _storage.loadNote(s.noteId);
      if (noteData == null) continue;

      Sketch sketch;
      try {
        sketch = Sketch.fromJson(jsonDecode(noteData));
      } catch (e) {
        debugPrint('Error parsing sketch for note ${s.noteId}: $e');
        continue;
      }

      // Determine canvas size for the note page
      // We use the same format as the PDF pages to make it look like a notebook
      final Size canvasSize = Size(
        notePageFormat.width * 2,
        notePageFormat.height * 2,
      );
      ui.Image? bgImage;

      if (s.screenshotPath != null && File(s.screenshotPath!).existsSync()) {
        final bgBytes = await File(s.screenshotPath!).readAsBytes();
        final codec = await ui.instantiateImageCodec(bgBytes);
        final frame = await codec.getNextFrame();
        bgImage = frame.image;
      }

      // Calculate content bounds to fit everything
      Rect sketchBounds = _getSketchBounds(sketch);
      // Scale sketch bounds by 2.0 to match the rendering scale used for alignment
      sketchBounds = Rect.fromLTRB(
        sketchBounds.left * 2,
        sketchBounds.top * 2,
        sketchBounds.right * 2,
        sketchBounds.bottom * 2,
      );

      Rect contentBounds = sketchBounds;
      if (bgImage != null) {
        final bgRect = Rect.fromLTWH(
          0,
          0,
          bgImage.width.toDouble(),
          bgImage.height.toDouble(),
        );
        contentBounds = contentBounds == Rect.zero
            ? bgRect
            : contentBounds.expandToInclude(bgRect);
      }

      if (contentBounds == Rect.zero) {
        contentBounds = Rect.fromLTWH(
          0,
          0,
          canvasSize.width,
          canvasSize.height,
        );
      }

      // Add padding (5% of the larger dimension)
      final padding = contentBounds.longestSide * 0.05;
      contentBounds = Rect.fromLTRB(
        contentBounds.left - padding,
        contentBounds.top - padding,
        contentBounds.right + padding,
        contentBounds.bottom + padding,
      );

      // Calculate scale and offset to fit contentBounds into canvasSize
      final double scaleX = canvasSize.width / contentBounds.width;
      final double scaleY = canvasSize.height / contentBounds.height;
      final double fitScale = scaleX < scaleY ? scaleX : scaleY;

      final double offsetX =
          (canvasSize.width - contentBounds.width * fitScale) / 2 -
          contentBounds.left * fitScale;
      final double offsetY =
          (canvasSize.height - contentBounds.height * fitScale) / 2 -
          contentBounds.top * fitScale;

      final noteUiImage = await _renderer.renderToImage(
        sketch,
        size: canvasSize,
        backgroundImage: bgImage,
        backgroundRect: bgImage != null
            ? Rect.fromLTWH(
                0,
                0,
                bgImage.width.toDouble(),
                bgImage.height.toDouble(),
              )
            : null,
        offset: Offset(offsetX, offsetY),
        scale: fitScale,
        sketchScale:
            2.0, // Keep the 2x scale for sketch-to-screenshot alignment
        gridEnabled: gridEnabled,
        gridType: gridType,
        gridSpacing: gridSpacing * 2,
        isDark: isDark,
      );

      final byteData = await noteUiImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) continue;

      final pwNoteImage = pw.MemoryImage(byteData.buffer.asUint8List());

      doc.addPage(
        pw.Page(
          pageFormat: notePageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Anchor(name: s.id, child: pw.Image(pwNoteImage));
          },
        ),
      );
    }

    await pdfDocument.close();

    final outputDir = await getTemporaryDirectory();
    final outputFile = File(
      '${outputDir.path}/${list.name.replaceAll(' ', '_')}_exported.pdf',
    );
    await outputFile.writeAsBytes(await doc.save());

    return outputFile;
  }

  Rect _getSketchBounds(Sketch sketch) {
    if (sketch.lines.isEmpty) return Rect.zero;
    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;
    for (final line in sketch.lines) {
      for (final p in line.points) {
        if (p.x < minX) minX = p.x;
        if (p.x > maxX) maxX = p.x;
        if (p.y < minY) minY = p.y;
        if (p.y > maxY) maxY = p.y;
      }
    }
    if (minX == double.infinity) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
