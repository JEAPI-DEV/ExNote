import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/folder.dart';
import 'package:exnote/models/note.dart';
import 'package:exnote/models/exercise_list.dart';
import 'package:exnote/models/selection.dart';
import 'package:exnote/services/backup/backup_merge_service.dart';
import 'package:exnote/services/storage_service.dart';

void main() {
  test(
    'restore preserves existing handwriting and rebases PDFs and screenshots',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exnote_merge_test',
      );
      addTearDown(() => directory.delete(recursive: true));
      final source = await Directory('${directory.path}/backup').create();
      final target = await Directory('${directory.path}/documents').create();
      final storage = StorageService(directory: target);
      addTearDown(storage.dispose);
      await storage.saveNote('existing', 'newest writing');
      for (final entry in {
        'note_existing.json': 'old writing',
        'note_new.json': 'restored writing',
        'exercise.pdf': 'pdf',
        'selection.png': 'image',
        'note_thumb_new.png': 'thumb',
      }.entries) {
        await File('${source.path}/${entry.key}').writeAsString(entry.value);
      }
      await Directory('${source.path}/voice_notes').create();
      await File('${source.path}/voice_notes/new.json').writeAsString('[]');
      await Directory('${source.path}/recordings').create();
      await File('${source.path}/recordings/new.m4a').writeAsString('audio');
      final result = await BackupMergeService(storage).merge(
        [
          Folder(
            id: 'folder',
            name: 'Current',
            notes: {
              'existing': Note(id: 'existing', name: 'Keep', scribbleData: ''),
            },
          ),
        ],
        [
          Folder(
            id: 'folder',
            name: 'Old',
            notes: {
              'existing': Note(
                id: 'existing',
                name: 'Old name',
                scribbleData: '',
              ),
              'new': Note(
                id: 'new',
                scribbleData: '',
                screenshotPath: 'note_thumb_new.png',
              ),
            },
            exerciseLists: [
              ExerciseList(
                id: 'list',
                name: 'Math',
                pdfPath: '/old/device/exercise.pdf',
                selections: [
                  Selection(
                    id: 'selection',
                    noteId: 'new',
                    left: 0,
                    top: 0,
                    width: 20,
                    height: 20,
                    pageIndex: 0,
                    screenshotPath: '/old/device/selection.png',
                  ),
                ],
              ),
            ],
          ),
        ],
        source.path,
      );
      expect(await storage.loadNote('existing'), 'newest writing');
      expect(await storage.loadNote('new'), 'restored writing');
      expect(result.single.notes['existing']!.name, 'Keep');
      expect(result.single.notes['new']!.screenshotPath, 'note_thumb_new.png');
      expect(
        result.single.exerciseLists.single.pdfPath,
        '${target.path}/exercise.pdf',
      );
      expect(
        result.single.exerciseLists.single.selections.single.screenshotPath,
        '${target.path}/selection.png',
      );
      expect(
        await File('${target.path}/recordings/new.m4a').readAsString(),
        'audio',
      );
      expect(await File('${target.path}/voice_notes/new.json').exists(), true);
    },
  );
}
