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
import 'a4_note_pdf_renderer.dart';

class PdfNoteExportService {
  final StorageService _storage = StorageService();
  final A4NotePdfRenderer _noteRenderer = A4NotePdfRenderer();

  Future<File> exportExerciseListToPdf(ExerciseList list) async {
    final doc = pw.Document();
    final pdfFile = File(list.pdfPath);

    if (!pdfFile.existsSync()) {
      throw Exception('Original PDF file not found at ${list.pdfPath}');
    }

    final settings = await SettingsService.loadSettings();
    const bool isDark = false;

    final pdfDocument = await pdfx.PdfDocument.openFile(pdfFile.path);

    for (int i = 1; i <= pdfDocument.pagesCount; i++) {
      final page = await pdfDocument.getPage(i);
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

      ui.Image? bgImage;
      Rect? bgRect;

      if (s.screenshotPath != null && File(s.screenshotPath!).existsSync()) {
        final bgBytes = await File(s.screenshotPath!).readAsBytes();
        final codec = await ui.instantiateImageCodec(bgBytes);
        final frame = await codec.getNextFrame();
        bgImage = frame.image;
        bgRect = Rect.fromLTWH(
          0,
          0,
          bgImage.width.toDouble() / 2,
          bgImage.height.toDouble() / 2,
        );
      }

      List<A4RenderedNotePage> renderedPages;
      try {
        renderedPages = await _noteRenderer.renderPages(
          sketch: sketch,
          backgroundImage: bgImage,
          backgroundRect: bgRect,
          gridEnabled: settings.gridEnabled,
          gridType: settings.gridType,
          gridSpacing: settings.gridSpacing,
          isDark: isDark,
        );
      } finally {
        bgImage?.dispose();
      }

      for (int i = 0; i < renderedPages.length; i++) {
        final renderedPage = renderedPages[i];
        final pwNoteImage = pw.MemoryImage(renderedPage.pngBytes);

        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              final image = pw.Image(
                pwNoteImage,
                width: renderedPage.drawWidth,
                height: renderedPage.drawHeight,
                fit: pw.BoxFit.fill,
              );

              if (i == 0) {
                return pw.Anchor(name: s.id, child: image);
              }

              return image;
            },
          ),
        );
      }
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
