import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:scribble/scribble.dart';
import '../models/grid_type.dart';
import '../services/sketch_renderer.dart';

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
    print("[ExportService] Starting PDF export...");
    final SketchRenderer renderer = SketchRenderer();

    // 1. Calculate Bounds
    Rect sketchBounds = _getSketchBounds(sketch);
    print("[ExportService] Sketch bounds: $sketchBounds");
    if (sketchBounds == Rect.zero) {
      // Default to A4 if empty
      sketchBounds = const Rect.fromLTWH(0, 0, 595, 842);
    }

    // Add padding (5% of width)
    final padding = sketchBounds.width * 0.05;
    final contentRect = Rect.fromLTRB(
      sketchBounds.left - padding,
      sketchBounds.top - padding,
      sketchBounds.right + padding,
      sketchBounds.bottom + padding,
    );

    final double pageWidth = contentRect.width;
    const double targetPageHeight = 842.0; // A4 height in points

    // 2. Find Split Points
    print("[ExportService] Finding split points...");
    final List<double> splitPoints = _findSplitPoints(
      sketch,
      contentRect,
      targetPageHeight,
    );
    print("[ExportService] Found ${splitPoints.length - 1} pages.");

    final List<Uint8List> pageImages = [];
    final List<double> segmentHeights = [];

    // 3. Render each page
    for (int i = 0; i < splitPoints.length - 1; i++) {
      final top = splitPoints[i];
      final bottom = splitPoints[i + 1];
      final segmentHeight = bottom - top;
      print(
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
      pageImage.dispose(); // Free memory immediately

      if (byteData == null) continue;
      pageImages.add(byteData.buffer.asUint8List());
      segmentHeights.add(segmentHeight);
    }

    print("[ExportService] Offloading PDF generation to background...");
    final dir = await _getExportDirectory();
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

    print("[ExportService] PDF saved to $filePath");
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

  static Rect _getSketchBounds(Sketch sketch) {
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

  static List<double> _findSplitPoints(
    Sketch sketch,
    Rect contentRect,
    double targetHeight,
  ) {
    // Optimization: Use a vertical occupancy map
    final double startY = contentRect.top;
    final double endY = contentRect.bottom;
    final int mapSize = (endY - startY).ceil() + 1;
    if (mapSize <= 0) return [startY, endY];

    final occupancy = List<bool>.filled(mapSize, false);

    for (final line in sketch.lines) {
      final halfWidth = line.width / 2 + 2; // Buffer
      for (int i = 0; i < line.points.length - 1; i++) {
        final p1 = line.points[i];
        final p2 = line.points[i + 1];
        final top = (math.min(p1.y, p2.y) - halfWidth - startY).floor().clamp(
          0,
          mapSize - 1,
        );
        final bottom = (math.max(p1.y, p2.y) + halfWidth - startY).ceil().clamp(
          0,
          mapSize - 1,
        );
        for (int y = top; y <= bottom; y++) {
          occupancy[y] = true;
        }
      }
      if (line.points.length == 1) {
        final p = line.points[0];
        final top = (p.y - halfWidth - startY).floor().clamp(0, mapSize - 1);
        final bottom = (p.y + halfWidth - startY).ceil().clamp(0, mapSize - 1);
        for (int y = top; y <= bottom; y++) {
          occupancy[y] = true;
        }
      }
    }

    final List<double> splits = [startY];
    double currentTop = startY;

    while (currentTop < endY) {
      double nextSplit = currentTop + targetHeight;
      if (nextSplit >= endY) {
        splits.add(endY);
        break;
      }

      // Search for a gap backwards from targetHeight to targetHeight * 0.7
      int bestGapIdx = -1;
      final int startSearch = (nextSplit - startY).floor().clamp(
        0,
        mapSize - 1,
      );
      final int endSearch = (currentTop + targetHeight * 0.7 - startY)
          .floor()
          .clamp(0, mapSize - 1);

      for (int y = startSearch; y >= endSearch; y--) {
        if (!occupancy[y]) {
          bestGapIdx = y;
          break;
        }
      }

      // If no gap found, search further up to 50%
      if (bestGapIdx == -1) {
        final int endSearchDeep = (currentTop + targetHeight * 0.5 - startY)
            .floor()
            .clamp(0, mapSize - 1);
        for (int y = endSearch; y >= endSearchDeep; y--) {
          if (!occupancy[y]) {
            bestGapIdx = y;
            break;
          }
        }
      }

      double splitY = bestGapIdx == -1 ? nextSplit : startY + bestGapIdx;
      splits.add(splitY);
      currentTop = splitY;
    }

    return splits;
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
