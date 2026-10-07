import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:path_provider/path_provider.dart';
import '../../models/indexing/note_index.dart';
import '../atomic_file_store.dart';
import '../../utils/storage_paths.dart';

/// Derived annotations live separately from the handwritten source files.
class NoteIndexRepository {
  final Directory? directory;
  final _files = AtomicFileStore();
  NoteIndexRepository({this.directory});
  Future<Directory> get root async => Directory(
    '${(directory ?? await getApplicationDocumentsDirectory()).path}/note_index',
  );

  Future<({Map<String, NoteIndex> entries, Map<String, String> errors})>
  load() async {
    final path = (await root).path;
    return Isolate.run(() async {
      final entries = <String, NoteIndex>{};
      final errors = <String, String>{};
      final directory = Directory(path);
      if (!await directory.exists()) return (entries: entries, errors: errors);
      await for (final entity in directory.list()) {
        if (entity is! File || !entity.path.endsWith('.json')) continue;
        try {
          final entry = NoteIndex.fromJson(
            jsonDecode(await entity.readAsString()) as Map<String, dynamic>,
          );
          entries[entry.noteId] = entry;
        } catch (error) {
          errors[entity.uri.pathSegments.last] = '$error';
        }
      }
      return (entries: entries, errors: errors);
    });
  }

  Future<void> save(NoteIndex entry) async {
    final file = File(
      '${(await root).path}/${safeStorageId(entry.noteId)}.json',
    );
    await _files.write(file, jsonEncode(entry.toJson()));
  }
}
