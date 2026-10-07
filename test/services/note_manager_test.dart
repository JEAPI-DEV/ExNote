import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribble/scribble.dart';
import 'package:exnote/models/canvas_image.dart';
import 'package:exnote/models/canvas_object.dart';
import 'package:exnote/models/folder.dart';
import 'package:exnote/models/note.dart';
import 'package:exnote/models/note_document.dart';
import 'package:exnote/providers/folder_provider.dart';
import 'package:exnote/services/storage_service.dart';
import 'package:exnote/services/note_manager.dart';
import 'package:exnote/utils/undo_redo_manager.dart';

void main() {
  late Directory directory;
  late StorageService storage;
  late FolderNotifier folders;
  late ValueNotifier<Sketch> sketch;
  late ValueNotifier<List<CanvasImage>> images;
  late ValueNotifier<List<CanvasObject>> objects;
  late UndoRedoManager undo;
  late NoteManager manager;
  const legacy = '{ "lines" : [] }';
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('exnote_readonly_test');
    storage = StorageService(directory: directory);
    await storage.saveFolders([
      Folder(
        id: 'folder',
        name: 'Math',
        notes: {'note': Note(id: 'note', scribbleData: '')},
      ),
    ]);
    await storage.saveNote('note', legacy);
    folders = FolderNotifier(storage);
    await folders.loadFolders();
    sketch = ValueNotifier(const Sketch(lines: []));
    images = ValueNotifier([]);
    objects = ValueNotifier([]);
    undo = UndoRedoManager(
      sketchNotifier: sketch,
      objectsNotifier: objects,
      onStateChanged: () {},
    );
    manager = NoteManager(
      folders: folders,
      folderId: 'folder',
      noteId: 'note',
      sketchNotifier: sketch,
      imagesNotifier: images,
      objectsNotifier: objects,
      undoRedoManager: undo,
    );
    await manager.loadNote(onScreenshotLoaded: (_) {});
  });
  tearDown(() async {
    await manager.flush();
    manager.close();
    folders.dispose();
    undo.dispose();
    sketch.dispose();
    images.dispose();
    objects.dispose();
    await storage.dispose();
    await directory.delete(recursive: true);
  });
  test(
    'viewing and closing preserve original JSON, timestamp and index state',
    () async {
      final file = File('${directory.path}/note_note.json');
      final timestamp = DateTime(2000, 1, 1);
      await file.setLastModified(timestamp);
      final changes = <String>[];
      final subscription = storage.changedNotes.listen(changes.add);
      expect(manager.hasChanges, false);
      await manager.saveNote(screenshotBase64: 'not an image');
      await Future<void>.delayed(Duration.zero);
      expect(await file.readAsString(), legacy);
      expect(await file.lastModified(), timestamp);
      expect(changes, isEmpty);
      await subscription.cancel();
    },
  );
  test(
    'draw then undo before saving does not invalidate an unchanged note',
    () async {
      sketch.value = Sketch(
        lines: [
          SketchLine(
            color: 0xff000000,
            width: 2,
            points: [Point(10, 10), Point(20, 20)],
          ),
        ],
      );
      expect(manager.hasChanges, true);
      sketch.value = const Sketch(lines: []);
      expect(manager.hasChanges, false);
      await manager.saveNote();
      expect(await storage.loadNote('note'), legacy);
    },
  );
  test(
    'undo during an in-flight save is queued and persists the final content',
    () async {
      sketch.value = Sketch(
        lines: [
          SketchLine(color: 0xff000000, width: 2, points: [Point(10, 10)]),
        ],
      );
      final first = manager.saveNote();
      sketch.value = const Sketch(lines: []);
      expect(manager.hasChanges, true);
      final last = manager.saveNote();
      await Future.wait([first, last]);
      expect(
        NoteDocument.decode((await storage.loadNote('note'))!).sketch.lines,
        isEmpty,
      );
      expect(manager.hasChanges, false);
    },
  );
}
