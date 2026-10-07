import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../models/folder.dart';
import '../../models/note_document.dart';
import '../storage_service.dart';

class LibraryNote {
  final String id;
  final String folderId;
  final String name;
  final String folderName;
  final String legacyData;
  final String? backgroundPath;
  final String? exerciseListId;
  final String? selectionId;
  const LibraryNote({
    required this.id,
    required this.folderId,
    required this.name,
    required this.folderName,
    this.legacyData = '',
    this.backgroundPath,
    this.exerciseListId,
    this.selectionId,
  });

  static List<LibraryNote> fromFolders(List<Folder> folders) {
    final result = <String, LibraryNote>{};
    for (final folder in folders) {
      for (final note in folder.notes.values) {
        result[note.id] = LibraryNote(
          id: note.id,
          folderId: folder.id,
          name: note.name ?? 'Note',
          folderName: folder.name,
          legacyData: note.scribbleData,
        );
      }
      for (final list in folder.exerciseLists) {
        for (final selection in list.selections) {
          result[selection.noteId] = LibraryNote(
            id: selection.noteId,
            folderId: folder.id,
            name:
                folder.notes[selection.noteId]?.name ??
                '${list.name} · page ${selection.pageIndex + 1}',
            folderName: folder.name,
            legacyData: folder.notes[selection.noteId]?.scribbleData ?? '',
            backgroundPath: selection.screenshotPath,
            exerciseListId: list.id,
            selectionId: selection.id,
          );
        }
      }
    }
    return result.values.toList();
  }
}

class NoteSourceSnapshot {
  final NoteDocument document;
  final String fingerprint;
  const NoteSourceSnapshot(this.document, this.fingerprint);
}

class NoteLibrarySource {
  final StorageService storage;
  NoteLibrarySource(this.storage);

  Future<NoteSourceSnapshot> read(LibraryNote note) async {
    final raw = await storage.loadNote(note.id) ?? note.legacyData;
    final document = await Isolate.run(() => NoteDocument.decode(raw));
    final root = storage.directory ?? await getApplicationDocumentsDirectory();
    final resources = <String>[];
    for (final path in [
      if (note.backgroundPath != null) note.backgroundPath!,
      ...document.images.map((image) => image.path),
    ]) {
      final stat = await File(
        p.isAbsolute(path) ? path : p.join(root.path, path),
      ).stat();
      if (stat.type == FileSystemEntityType.notFound) {
        throw FileSystemException('Missing note image', path);
      }
      resources.add(
        '$path:${stat.size}:${stat.modified.microsecondsSinceEpoch}',
      );
    }
    final fingerprint = await Isolate.run(
      () => sha256
          .convert(utf8.encode('$raw\n${resources.join('\n')}'))
          .toString(),
    );
    return NoteSourceSnapshot(document, fingerprint);
  }
}
