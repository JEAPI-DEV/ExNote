import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/folder.dart';
import 'package:exnote/services/storage_service.dart';

void main() {
  late Directory directory;
  late StorageService storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exnote_storage_test');
    storage = StorageService(directory: directory);
  });
  tearDown(() async {
    await storage.dispose();
    await directory.delete(recursive: true);
  });

  test('overlapping folder writes preserve request order', () async {
    final saves = [
      storage.saveFolders([Folder(id: 'a', name: 'First')]),
      storage.saveFolders([Folder(id: 'a', name: 'Latest')]),
    ];
    await Future.wait(saves);
    expect((await storage.loadFolders()).single.name, 'Latest');
    expect(
      await File('${directory.path}/folders.json.writing').exists(),
      false,
    );
  });
  test(
    'load errors are surfaced without overwriting a corrupt library',
    () async {
      final file = File('${directory.path}/folders.json');
      await file.writeAsString('invalid JSON');
      await expectLater(storage.loadFolders(), throwsFormatException);
      expect(await file.readAsString(), 'invalid JSON');
    },
  );
  test(
    'identical note saves do not replace files or emit index invalidations',
    () async {
      await storage.saveNote('same', 'same contents');
      final file = File('${directory.path}/note_same.json');
      final timestamp = DateTime(2000, 1, 1);
      await file.setLastModified(timestamp);
      final changes = <String>[];
      final subscription = storage.changedNotes.listen(changes.add);
      await storage.saveNote('same', 'same contents');
      await Future<void>.delayed(Duration.zero);
      expect(changes, isEmpty);
      expect(await file.lastModified(), timestamp);
      await subscription.cancel();
    },
  );
  test('stored IDs cannot traverse the document directory', () async {
    await expectLater(
      storage.saveNote('../bad', 'text'),
      throwsFormatException,
    );
    await expectLater(storage.loadNote('../bad'), throwsFormatException);
  });
}
