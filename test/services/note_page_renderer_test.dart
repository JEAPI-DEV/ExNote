import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:exnote/models/note_document.dart';
import 'package:exnote/models/canvas_image.dart';
import 'package:exnote/services/notes/note_page_renderer.dart';

void main() {
  testWidgets(
    'complete page rendering retains imported images beneath handwriting',
    (tester) async {
      await tester.runAsync(() async {
        final directory = await Directory.systemTemp.createTemp(
          'exnote_page_render',
        );
        try {
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawColor(const Color(0xFFFF0000), BlendMode.src);
          final picture = recorder.endRecording();
          final image = await picture.toImage(64, 64);
          picture.dispose();
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          await File(
            '${directory.path}/image.png',
          ).writeAsBytes(png!.buffer.asUint8List());
          final document = NoteDocument(
            sketch: Sketch(
              lines: [
                SketchLine(
                  color: Colors.black.toARGB32(),
                  width: 4,
                  points: [Point(90, 110), Point(160, 110)],
                ),
              ],
            ),
            images: const [
              CanvasImage(
                id: 'image',
                path: 'image.png',
                left: 80,
                top: 80,
                width: 100,
                height: 100,
              ),
            ],
          );
          final pages = await NotePageRenderer(
            directory: directory,
          ).render(document).toList();
          final codec = await ui.instantiateImageCodec(pages.single.png);
          final raster = (await codec.getNextFrame()).image;
          codec.dispose();
          try {
            final rgba = (await raster.toByteData(
              format: ui.ImageByteFormat.rawRgba,
            ))!.buffer.asUint8List();
            List<int> pixel(double x, double y) {
              final rect = pages.single.bounds;
              final scale = raster.width / rect.width;
              final column = ((x - rect.left) * scale).round();
              final row = ((y - rect.top) * scale).round();
              final start = (row * raster.width + column) * 4;
              return rgba.sublist(start, start + 4);
            }

            expect(pixel(130, 140), [255, 0, 0, 255]);
            expect(pixel(130, 110), [0, 0, 0, 255]);
            expect(pixel(700, 100), [255, 255, 255, 255]);
          } finally {
            raster.dispose();
          }
        } finally {
          await directory.delete(recursive: true);
        }
      });
    },
  );
  test(
    'complete note layout covers multiple lecture pages independently of viewport',
    () {
      final document = NoteDocument(
        sketch: Sketch(
          lines: [
            SketchLine(
              color: Colors.black.toARGB32(),
              width: 2,
              points: [Point(20, 20), Point(600, 7500)],
            ),
          ],
        ),
      );
      final pages = NotePageRenderer.layout(document);
      expect(pages.length, greaterThanOrEqualTo(7));
      expect(pages.first.top, lessThan(20));
      expect(pages.last.bottom, greaterThan(7500));
      for (int i = 1; i < pages.length; i++) {
        expect(pages[i].top, pages[i - 1].bottom);
      }
    },
  );
  test(
    'image-only content and exercise background participate in page bounds',
    () {
      const document = NoteDocument(
        sketch: Sketch(lines: []),
        images: [
          CanvasImage(
            id: 'image',
            path: 'image.png',
            left: 10,
            top: 4000,
            width: 500,
            height: 500,
          ),
        ],
      );
      final pages = NotePageRenderer.layout(
        document,
        background: const Rect.fromLTWH(0, 0, 600, 800),
      );
      expect(pages.first.top, lessThanOrEqualTo(0));
      expect(pages.last.bottom, greaterThanOrEqualTo(4500));
    },
  );
}
