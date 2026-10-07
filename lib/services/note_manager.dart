import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:scribble/scribble.dart';
import '../providers/folder_provider.dart';
import '../utils/undo_redo_manager.dart';
import '../utils/sketch_serializer.dart';
import '../models/canvas_image.dart';
import '../models/canvas_object.dart';
import '../models/folder.dart';
import '../models/note_document.dart';

class NoteManager {
  final FolderNotifier folders;
  Future<void> _pendingSave = Future.value();
  Future<void> _lastRequestedSave = Future.value();
  NoteDocument? _savedDocument;
  NoteDocument? _queuedDocument;

  NoteDocument get _currentDocument => NoteDocument(
    sketch: sketchNotifier.value,
    images: List.of(imagesNotifier.value),
    objects: List.of(objectsNotifier.value),
  );
  bool get hasChanges {
    final reference = _queuedDocument ?? _savedDocument;
    return reference == null || !reference.hasSameContent(_currentDocument);
  }

  Future<void> flush() => _lastRequestedSave;
  bool _closed = false;
  void close() {
    _closed = true;
  }

  final String folderId;
  final String? exerciseListId;
  final String? selectionId;
  final String noteId;

  final ValueNotifier<Sketch> sketchNotifier;
  final ValueNotifier<List<CanvasImage>> imagesNotifier;
  final ValueNotifier<List<CanvasObject>> objectsNotifier;
  final UndoRedoManager undoRedoManager;

  NoteManager({
    required this.folders,
    required this.folderId,
    this.exerciseListId,
    this.selectionId,
    required this.noteId,
    required this.sketchNotifier,
    required this.imagesNotifier,
    required this.objectsNotifier,
    required this.undoRedoManager,
  });

  Future<void> loadNote({required Function(Size) onScreenshotLoaded}) async {
    try {
      final folder = folders.folderById(folderId);

      String? scribbleData = await folders.loadNoteData(noteId);

      if (scribbleData == null || scribbleData.isEmpty) {
        final legacyNote = folder.notes[noteId];
        if (legacyNote != null && legacyNote.scribbleData.isNotEmpty) {
          // Preserve the stored representation until the user actually edits.
          scribbleData = legacyNote.scribbleData;
        }
      }

      if (_closed) return;
      if (scribbleData != null && scribbleData.isNotEmpty) {
        final content = await runDeserialization(scribbleData);
        if (_closed) return;

        sketchNotifier.value = content.sketch;
        imagesNotifier.value = content.images;
        objectsNotifier.value = content.objects;
        undoRedoManager.clear();
      }

      _savedDocument = _currentDocument;

      if (exerciseListId != null && selectionId != null) {
        final list = folder.exerciseLists.firstWhere(
          (l) => l.id == exerciseListId,
        );
        final selection = list.selections.firstWhere(
          (s) => s.id == selectionId,
        );

        if (selection.screenshotPath != null) {
          final codec = await ui.instantiateImageCodec(
            await File(selection.screenshotPath!).readAsBytes(),
          );
          final image = (await codec.getNextFrame()).image;
          codec.dispose();
          if (!_closed) {
            onScreenshotLoaded(Size(image.width / 2, image.height / 2));
          }
          image.dispose();
        }
      }
    } catch (e) {
      debugPrint('Error loading note: $e');
      rethrow;
    }
  }

  Future<void> saveNote({String? screenshotBase64}) {
    // Snapshot synchronously, while editor notifiers are alive. Queue before
    // serialization so a manual save and autosave cannot reorder handwriting.
    final folder = folders.folderById(folderId);
    final document = _currentDocument;
    _queuedDocument = document;
    final operation = _pendingSave.then((_) async {
      if (_savedDocument?.hasSameContent(document) == true) return;
      await _saveSnapshot(
        folder,
        document.sketch,
        document.images,
        document.objects,
        screenshotBase64,
      );
      _savedDocument = document;
    });
    _lastRequestedSave = operation;
    _pendingSave = operation.then<void>(
      (_) {
        if (identical(_queuedDocument, document)) _queuedDocument = null;
      },
      onError: (Object _, StackTrace __) {
        if (identical(_queuedDocument, document)) _queuedDocument = null;
      },
    );
    return operation;
  }

  Future<void> _saveSnapshot(
    Folder folder,
    Sketch sketch,
    List<CanvasImage> images,
    List<CanvasObject> objects,
    String? screenshotBase64,
  ) async {
    try {
      final jsonSketch = await runSerialization(
        sketch,
        images: images,
        objects: objects,
      );

      String? screenshotPath;
      if (exerciseListId != null && selectionId != null) {
        try {
          final list = folder.exerciseLists.firstWhere(
            (l) => l.id == exerciseListId,
          );
          final selection = list.selections.firstWhere(
            (s) => s.id == selectionId,
          );
          screenshotPath = selection.screenshotPath;
        } catch (e) {
          debugPrint('Error getting selection for save: $e');
        }
      } else {
        // Handle standalone note screenshot capture
        if (screenshotBase64 != null) {
          final bytes = base64Decode(screenshotBase64);
          final appDir = await getApplicationDocumentsDirectory();
          final fileName = 'note_thumb_$noteId.png';
          final file = File('${appDir.path}/$fileName');
          await file.writeAsBytes(bytes);
          screenshotPath = fileName;
        } else {
          screenshotPath = folder.notes[noteId]?.screenshotPath;
        }
      }

      await folders.updateNote(folderId, noteId, jsonSketch, screenshotPath);
    } catch (e) {
      debugPrint('Error saving note: $e');
      rethrow;
    }
  }
}
