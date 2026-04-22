import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class CanvasCaptureService {
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
}
