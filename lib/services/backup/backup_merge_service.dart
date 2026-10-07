import 'dart:io';
import 'package:path/path.dart' as p;
import '../../models/folder.dart';
import '../../models/exercise_list.dart';
import '../../models/note.dart';
import '../../models/selection.dart';
import '../../utils/storage_paths.dart';
import '../storage_service.dart';
import 'note_path_rebaser.dart';

/// Restores missing files and rebases legacy absolute paths, preserving existing notes.
class BackupMergeService {
  final StorageService storage;
  BackupMergeService(this.storage);

  Future<List<Folder>> merge(
    List<Folder> current,
    List<Folder> imported,
    String sourcePath,
  ) async {
    final root = await storage.rootDirectory;
    final existingIds = {
      for (final folder in current) ...folder.notes.keys,
      for (final folder in current)
        for (final list in folder.exerciseLists)
          for (final selection in list.selections) selection.noteId,
    };
    for (final folder in imported) {
      for (final id in folder.notes.keys) {
        safeStorageId(id);
      }
      for (final list in folder.exerciseLists) {
        for (final selection in list.selections) {
          safeStorageId(selection.noteId);
        }
      }
    }
    final copiedPaths = <String, String>{};
    final restoredNotes = <String, File>{};
    await for (final file in Directory(
      sourcePath,
    ).list(recursive: true, followLinks: false)) {
      if (file is! File) continue;
      final relative = p.relative(file.path, from: sourcePath);
      if (relative == 'folders.json' ||
          relative.endsWith('.writing') ||
          relative.endsWith('.partial')) {
        continue;
      }
      final basename = p.basename(relative);
      final noteFile = RegExp(r'^note_(.+)\.json$').firstMatch(basename);
      if (noteFile != null && existingIds.contains(noteFile.group(1))) continue;
      // Sidecars belong to the source note and must not replace existing annotations/voice notes.
      if ((p.split(relative).first == 'note_index' ||
              p.split(relative).first == 'voice_notes') &&
          existingIds.contains(p.basenameWithoutExtension(relative))) {
        continue;
      }
      final destination = File(p.join(root.path, relative));
      if (!await destination.exists()) {
        await destination.parent.create(recursive: true);
        await file.copy(destination.path);
        if (noteFile != null) restoredNotes[noteFile.group(1)!] = destination;
      }
      copiedPaths[relative] = destination.path;
      copiedPaths.putIfAbsent(basename, () => destination.path);
    }
    String rebase(String original) =>
        copiedPaths[original] ?? copiedPaths[p.basename(original)] ?? original;
    for (final entry in restoredNotes.entries) {
      final raw = await entry.value.readAsString();
      final rebased = await rebaseNoteImagePaths(raw, copiedPaths);
      if (rebased != raw) await storage.saveNote(entry.key, rebased);
    }
    final merged = {for (final folder in current) folder.id: folder};
    for (final folder in imported) {
      final old = merged[folder.id];
      final notes = {...?old?.notes};
      for (final entry in folder.notes.entries) {
        if (existingIds.contains(entry.key)) continue;
        final note = entry.value;
        notes[entry.key] = Note(
          id: note.id,
          name: note.name,
          scribbleData: await rebaseNoteImagePaths(
            note.scribbleData,
            copiedPaths,
          ),
          screenshotPath: note.screenshotPath == null
              ? null
              : p.relative(rebase(note.screenshotPath!), from: root.path),
        );
      }
      final lists = [...?old?.exerciseLists];
      for (final list in folder.exerciseLists) {
        if (lists.any((existing) => existing.id == list.id)) continue;
        lists.add(
          ExerciseList(
            id: list.id,
            name: list.name,
            pdfPath: rebase(list.pdfPath),
            annotations: list.annotations,
            selections: [
              for (final selection in list.selections)
                Selection(
                  id: selection.id,
                  noteId: selection.noteId,
                  left: selection.left,
                  top: selection.top,
                  width: selection.width,
                  height: selection.height,
                  pageIndex: selection.pageIndex,
                  screenshotPath: selection.screenshotPath == null
                      ? null
                      : rebase(selection.screenshotPath!),
                ),
            ],
          ),
        );
      }
      merged[folder.id] = (old ?? folder).copyWith(
        notes: notes,
        exerciseLists: lists,
      );
    }
    return merged.values.toList();
  }
}
