import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:scribble/scribble.dart';
import '../../models/exercise_list.dart';
import '../storage_service.dart';
import '../settings_service.dart';
import '../sketch_renderer.dart';
import '../../utils/sketch_bounds.dart';

class PdfNoteExportService {
  final StorageService _storage = StorageService();
  final SketchRenderer _renderer = SketchRenderer();

  Future<File> exportExerciseListToPdf(ExerciseList list) async {
    final doc = pw.Document();
    final pdfFile = File(list.pdfPath);

    if (!pdfFile.existsSync()) {
      throw Exception('Original PDF file not found at ${list.pdfPath}');
    }

    final settings = await SettingsService.loadSettings();
    const bool isDark = false;

    final pdfDocument = await pdfx.PdfDocument.openFile(pdfFile.path);
    PdfPageFormat? firstPageFormat;

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

      Rect sketchBounds = sketch.bounds;
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

      final padding = contentBounds.longestSide * 0.05;
      contentBounds = Rect.fromLTRB(
        contentBounds.left - padding,
        contentBounds.top - padding,
        contentBounds.right + padding,
        contentBounds.bottom + padding,
      );

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
        sketchScale: 2.0,
        gridEnabled: settings.gridEnabled,
        gridType: settings.gridType,
        gridSpacing: settings.gridSpacing * 2,
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
}
