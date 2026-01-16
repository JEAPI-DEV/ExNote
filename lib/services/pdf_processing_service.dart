import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;

class PdfProcessingService {
  /// Creates a new PDF file containing only the selected pages from the source PDF.
  /// [sourcePath] The path to the original PDF.
  /// [destinationPath] The path where the new PDF will be saved.
  /// [pageIndices] The 0-based indices of the pages to include.
  Future<void> extractPages({
    required String sourcePath,
    required String destinationPath,
    required List<int> pageIndices,
  }) async {
    final doc = pw.Document();
    final pdfDocument = await pdfx.PdfDocument.openFile(sourcePath);

    try {
      // Sort indices just in case, though preserving selection order might be desired?
      // Usually users expect pages in original order.
      final sortedIndices = List<int>.from(pageIndices)..sort();

      for (final index in sortedIndices) {
        // pdfx uses 1-based indexing for getPage
        final page = await pdfDocument.getPage(index + 1);
        try {
          // Render at decent resolution for the new PDF
          // Note: This rasterizes vectors! It is filtered.
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
