import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class ExportService {
  static Future<File> exportToZip() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = await _getExportDirectory();
    final zipPath =
        '${exportDir.path}/exnote_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    // Add all files from the app documents directory
    final files = appDir.listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        // Skip temporary files or other non-essential files if needed
        // For now, we backup everything in the documents directory
        // We use the relative path to maintain structure if there are subdirectories
        final relativePath = path.relative(file.path, from: appDir.path);
        await encoder.addFile(file, relativePath);
      }
    }

    encoder.close();
    return File(zipPath);
  }

  static Future<File> exportToPng(
    GlobalKey exportKey,
    BuildContext context,
  ) async {
    final boundary =
        exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Nothing to export');
    }

    final dpi = MediaQuery.of(context).devicePixelRatio;
    final ui.Image image = await boundary.toImage(pixelRatio: dpi * 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to encode image');
    final bytes = byteData.buffer.asUint8List();

    final dir = await _getExportDirectory();
    final file = File(
      '${dir.path}/exnote_export_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }

  static Future<File> exportToPdf(
    GlobalKey exportKey,
    BuildContext context,
  ) async {
    final boundary =
        exportKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      throw Exception('Nothing to export');
    }

    final dpi = MediaQuery.of(context).devicePixelRatio;
    final ui.Image image = await boundary.toImage(pixelRatio: dpi * 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Failed to encode image');
    final bytes = byteData.buffer.asUint8List();

    final doc = pw.Document();
    final pwImage = pw.MemoryImage(bytes);
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) =>
            pw.Center(child: pw.Image(pwImage, fit: pw.BoxFit.contain)),
      ),
    );

    final dir = await _getExportDirectory();
    final file = File(
      '${dir.path}/exnote_export_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
    await file.writeAsBytes(await doc.save());
    return file;
  }

  static Future<String?> captureCanvas(GlobalKey exportKey) async {
    try {
      final boundary =
          exportKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) return null;

      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;

      final pngBytes = byteData.buffer.asUint8List();
      return base64Encode(pngBytes);
    } catch (e) {
      debugPrint('Error capturing canvas: $e');
      return null;
    }
  }

  static Future<Directory> _getExportDirectory() async {
    if (Platform.isAndroid) {
      final downloadDir = Directory('/storage/emulated/0/Download');
      if (await downloadDir.exists()) {
        return downloadDir;
      }

      final documentsDir = Directory('/storage/emulated/0/Documents');
      if (await documentsDir.exists()) {
        return documentsDir;
      }

      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) return externalDir;
    }
    return await getApplicationDocumentsDirectory();
  }
}
