import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../../utils/export_directory.dart';

class PngExportService {
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

    final dir = await ExportDirectory.get();
    final file = File(
      '${dir.path}/exnote_export_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes);
    return file;
  }
}
