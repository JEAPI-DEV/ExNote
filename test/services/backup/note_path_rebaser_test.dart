import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/services/backup/note_path_rebaser.dart';

void main() {
  test(
    'restored canvas image paths are rebased while handwriting is preserved',
    () async {
      final raw = jsonEncode({
        'version': 3,
        'sketch': {
          'lines': [
            {
              'points': [1, 2, 3],
              'width': 2,
            },
          ],
        },
        'images': [
          {'path': '/old/device/canvas_image_a.png', 'left': 20, 'top': 40},
        ],
        'objects': [],
      });
      final restored = jsonDecode(
        await rebaseNoteImagePaths(raw, {
          'canvas_image_a.png': '/new/device/canvas_image_a.png',
        }),
      );
      expect(restored['sketch'], jsonDecode(raw)['sketch']);
      expect(
        restored['images'].single['path'],
        '/new/device/canvas_image_a.png',
      );
      expect(restored['images'].single['left'], 20);
    },
  );
  test('legacy ink-only notes retain their exact original bytes', () async {
    const raw = '{ "lines" : [] }';
    expect(await rebaseNoteImagePaths(raw, {}), raw);
  });
}
