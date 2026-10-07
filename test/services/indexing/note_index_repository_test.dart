import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/indexing/note_index.dart';
import 'package:exnote/services/indexing/note_index_repository.dart';

void main() {
  test(
    'an unreadable derived index does not hide valid notes or delete source files',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exnote_index_recovery',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = NoteIndexRepository(directory: directory);
      await repository.save(
        const NoteIndex(
          noteId: 'valid',
          fingerprint: 'revision',
          model: 'local',
          pageCount: 1,
          complete: true,
          pages: [
            IndexedPage(
              number: 1,
              title: 'Math',
              text: 'Content',
              summary: '',
              keywords: [],
            ),
          ],
        ),
      );
      final broken = await File(
        '${directory.path}/note_index/broken.json',
      ).writeAsString('invalid');
      final loaded = await repository.load();
      expect(loaded.entries.keys, ['valid']);
      expect(loaded.errors.keys, ['broken.json']);
      expect(await broken.readAsString(), 'invalid');
    },
  );
}
