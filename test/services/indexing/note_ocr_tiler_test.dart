import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:exnote/services/indexing/note_ocr_tiler.dart';
import 'package:exnote/models/indexing/indexed_region.dart';

void main() {
  test(
    'covers every ink band with square crops and avoids splitting lines',
    () async {
      final image = img.Image(width: 768, height: 1100);
      img.fill(image, color: img.ColorRgb8(255, 255, 255));
      for (int i = 0; i < 8; i++) {
        img.drawRect(
          image,
          x1: 40,
          y1: 40 + i * 80,
          x2: 500,
          y2: 60 + i * 80,
          color: img.ColorRgb8(0, 0, 0),
          thickness: 12,
        );
      }
      final regions = await NoteOcrTiler().split(
        Uint8List.fromList(img.encodePng(image)),
      );
      expect(regions.length, greaterThan(1));
      expect(
        regions.fold<int>(0, (sum, region) => sum + region.expectedLines),
        8,
      );
      for (final region in regions) {
        final decoded = img.decodePng(region.png)!;
        expect(decoded.width, 768);
        expect(decoded.height, 768);
      }
      for (int i = 0; i < 8; i++) {
        final center = (50 + i * 80) / 1100;
        expect(
          regions.any(
            (region) =>
                region.bounds[1] <= center &&
                region.bounds[1] + region.bounds[3] >= center,
          ),
          true,
        );
      }
    },
  );
  test('blank pages need no model inference', () async {
    final image = img.Image(width: 300, height: 600);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    expect(
      await NoteOcrTiler().split(Uint8List.fromList(img.encodePng(image))),
      isEmpty,
    );
  });
  test('short and unclear OCR responses require review', () {
    final incomplete = IndexedRegion.fromTranscript(
      number: 1,
      text: 'Only one line',
      bounds: [0, 0, 1, 1],
      expectedLines: 8,
    );
    expect(incomplete.needsReview, true);
    final unclear = IndexedRegion.fromTranscript(
      number: 1,
      text: '[illegible]',
      bounds: [0, 0, 1, 1],
      expectedLines: 1,
    );
    expect(unclear.needsReview, true);
    final complete = IndexedRegion.fromTranscript(
      number: 1,
      text: 'Line 1\nLine 2\nLine 3',
      bounds: [0, 0, 1, 1],
      expectedLines: 3,
    );
    expect(complete.needsReview, false);
  });
}
