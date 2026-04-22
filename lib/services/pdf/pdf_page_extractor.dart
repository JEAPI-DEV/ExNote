import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfPageExtractor {
  Future<void> extractPages({
    required String sourcePath,
    required String destinationPath,
    required List<int> pageIndices,
  }) async {
    final doc = pw.Document();
    final pdfDocument = await pdfx.PdfDocument.openFile(sourcePath);

    try {
      final sortedIndices = List<int>.from(pageIndices)..sort();

      for (final index in sortedIndices) {
        final page = await pdfDocument.getPage(index + 1);
        try {
          final pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: pdfx.PdfPageImageFormat.png,
          );

          if (pageImage != null) {
            final pwImage = pw.MemoryImage(pageImage.bytes);

            doc.addPage(
              pw.Page(
                pageFormat: PdfPageFormat(page.width, page.height),
                margin: pw.EdgeInsets.zero,
                build: (pw.Context context) {
                  return pw.Center(child: pw.Image(pwImage));
                },
              ),
            );
          }
        } finally {
          await page.close();
        }
      }

      final file = File(destinationPath);
      await file.writeAsBytes(await doc.save());
    } finally {
      await pdfDocument.close();
    }
  }
}
