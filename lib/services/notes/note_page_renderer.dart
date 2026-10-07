import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/note_document.dart';
import '../../utils/sketch_bounds.dart';
import '../sketch_renderer.dart';

class NotePage {
  final int number;
  final Rect bounds;
  final Uint8List png;
  const NotePage(this.number, this.bounds, this.png);
}

/// Renders one bounded page at a time, including imported images and graphs.
class NotePageRenderer {
  final Directory? directory;
  NotePageRenderer({this.directory});

  static List<Rect> layout(NoteDocument document, {Rect? background}) {
    Rect bounds = document.sketch.bounds;
    for (final image in document.images) {
      final rect = Rect.fromLTWH(
        image.left,
        image.top,
        image.width,
        image.height,
      );
      bounds = bounds.expandToInclude(rect);
    }
    for (final object in document.objects) {
      bounds = bounds.expandToInclude(object.bounds);
    }
    if (background != null) bounds = bounds.expandToInclude(background);
    if (!bounds.left.isFinite ||
        !bounds.top.isFinite ||
        !bounds.right.isFinite ||
        !bounds.bottom.isFinite) {
      throw const FormatException('Note contains invalid coordinates');
    }
    bounds = bounds.inflate(24);
    final width = math.max(800.0, bounds.width);
    final height = width * 1.41421356237;
    return [
      for (double top = bounds.top; top < bounds.bottom; top += height)
        Rect.fromLTWH(bounds.left, top, width, height),
    ];
  }

  Stream<NotePage> render(
    NoteDocument document, {
    String? backgroundPath,
  }) async* {
    final root = directory ?? await getApplicationDocumentsDirectory();
    ui.Image? background;
    Rect? backgroundRect;
    try {
      if (backgroundPath != null) {
        background = await _load(root, backgroundPath, resize: false);
        backgroundRect = Rect.fromLTWH(
          0,
          0,
          background.width / 2,
          background.height / 2,
        );
      }
      final pages = layout(document, background: backgroundRect);
      final renderer = SketchRenderer();
      for (int index = 0; index < pages.length; index++) {
        final rect = pages[index];
        final scale = 1536 / rect.width;
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawColor(Colors.white, BlendMode.src);
        canvas.scale(scale);
        canvas.translate(-rect.left, -rect.top);
        if (background != null && backgroundRect!.overlaps(rect)) {
          canvas.drawImageRect(
            background,
            Rect.fromLTWH(
              0,
              0,
              background.width.toDouble(),
              background.height.toDouble(),
            ),
            backgroundRect,
            Paint(),
          );
        }
        for (final image in document.images) {
          final imageRect = Rect.fromLTWH(
            image.left,
            image.top,
            image.width,
            image.height,
          );
          if (!rect.overlaps(imageRect)) continue;
          final raster = await _load(root, image.path);
          try {
            canvas.drawImageRect(
              raster,
              Rect.fromLTWH(
                0,
                0,
                raster.width.toDouble(),
                raster.height.toDouble(),
              ),
              imageRect,
              Paint(),
            );
          } finally {
            raster.dispose();
          }
        }
        for (final object in document.objects) {
          if (!object.bounds.overlaps(rect)) continue;
          renderer.drawObject(canvas, object, isDark: false);
        }
        final strokes = renderer.renderSketch(
          sketch: document.sketch,
          isDark: false,
          scale: 1,
          verticalRange: (top: rect.top, bottom: rect.bottom),
        );
        canvas.drawPicture(strokes);
        strokes.dispose();
        final picture = recorder.endRecording();
        final raster = await picture.toImage(
          1536,
          (rect.height * scale).ceil(),
        );
        picture.dispose();
        try {
          final bytes = await raster.toByteData(format: ui.ImageByteFormat.png);
          if (bytes == null) {
            throw StateError('Could not render note page ${index + 1}');
          }
          yield NotePage(index + 1, rect, bytes.buffer.asUint8List());
        } finally {
          raster.dispose();
        }
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      background?.dispose();
    }
  }

  Future<ui.Image> _load(
    Directory root,
    String path, {
    bool resize = true,
  }) async {
    final file = File(p.isAbsolute(path) ? path : p.join(root.path, path));
    final codec = await ui.instantiateImageCodec(
      await file.readAsBytes(),
      targetWidth: resize ? 2048 : null,
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }
}
