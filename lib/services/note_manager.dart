import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribble/scribble.dart';
import '../providers/folder_provider.dart';
import '../utils/undo_redo_manager.dart';
import '../utils/sketch_serializer.dart';

class NoteManager {
  final WidgetRef ref;
  final String folderId;
  final String exerciseListId;
  final String selectionId;
  final String noteId;

  final ValueNotifier<Sketch> sketchNotifier;
  final UndoRedoManager undoRedoManager;

  NoteManager({
    required this.ref,
    required this.folderId,
    required this.exerciseListId,
    required this.selectionId,
    required this.noteId,
    required this.sketchNotifier,
    required this.undoRedoManager,
  });

  Future<void> loadNote({required Function(Size) onScreenshotLoaded}) async {
    try {
      final folder = ref
          .read(folderProvider)
          .firstWhere((f) => f.id == folderId);

      String? scribbleData = await ref
          .read(folderProvider.notifier)
          .loadNoteData(noteId);

      if (scribbleData == null || scribbleData.isEmpty) {
        final legacyNote = folder.notes[noteId];
        if (legacyNote != null && legacyNote.scribbleData.isNotEmpty) {
          debugPrint('Migrating legacy note data for $noteId');
          scribbleData = legacyNote.scribbleData;
          await ref
              .read(folderProvider.notifier)
              .updateNote(
                folderId,
                noteId,
                scribbleData,
                legacyNote.screenshotPath,
              );
        }
      }

      if (scribbleData != null && scribbleData.isNotEmpty) {
        try {
          final sketchJson = jsonDecode(scribbleData) as Map<String, dynamic>;
          final loadedSketch = Sketch.fromJson(sketchJson);

          sketchNotifier.value = loadedSketch;
          undoRedoManager.clear();
        } catch (e) {
          debugPrint('Error loading note: $e');
        }
      }

      final list = folder.exerciseLists.firstWhere(
        (l) => l.id == exerciseListId,
      );
      final selection = list.selections.firstWhere((s) => s.id == selectionId);

      if (selection.screenshotPath != null) {
        final image = Image.file(File(selection.screenshotPath!));
        image.image
            .resolve(const ImageConfiguration())
            .addListener(
              ImageStreamListener((ImageInfo info, bool _) {
                onScreenshotLoaded(
                  Size(
                    info.image.width.toDouble() / 2,
                    info.image.height.toDouble() / 2,
                  ),
                );
              }),
            );
      }
    } catch (e) {
      debugPrint('Error loading note: $e');
    }
  }

  Future<void> saveNote() async {
    try {
      final sketch = sketchNotifier.value;
      final jsonSketch = await runSerialization(sketch);

      final folder = ref
          .read(folderProvider)
          .firstWhere((f) => f.id == folderId);
      final list = folder.exerciseLists.firstWhere(
        (l) => l.id == exerciseListId,
      );
      final selection = list.selections.firstWhere((s) => s.id == selectionId);

      await ref
          .read(folderProvider.notifier)
          .updateNote(folderId, noteId, jsonSketch, selection.screenshotPath);
    } catch (e) {
      debugPrint('Error saving note: $e');
      rethrow;
    }
  }
}
