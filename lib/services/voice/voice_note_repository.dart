import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/voice_note.dart';
import '../atomic_file_store.dart';
import '../../utils/storage_paths.dart';

class VoiceNoteRepository {
  final Directory? directory;
  final _files = AtomicFileStore();
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changes => _changes.stream;
  Future<void> dispose() => _changes.close();
  VoiceNoteRepository({this.directory});
  Future<Directory> get root async =>
      directory ?? await getApplicationDocumentsDirectory();
  Future<File> _file(String noteId) async =>
      File('${(await root).path}/voice_notes/${safeStorageId(noteId)}.json');
  Future<List<VoiceNote>> load(String noteId) async {
    final file = await _file(noteId);
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List;
    return list
        .map((json) => VoiceNote.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<void> save(String noteId, List<VoiceNote> notes) async {
    await _files.write(
      await _file(noteId),
      jsonEncode(notes.map((note) => note.toJson()).toList()),
    );
    _changes.add(noteId);
  }

  Future<({Map<String, String> texts, Map<String, String> errors})>
  loadTexts() async {
    final path = '${(await root).path}/voice_notes';
    return Isolate.run(() async {
      final directory = Directory(path);
      final texts = <String, String>{};
      final errors = <String, String>{};
      if (!await directory.exists()) return (texts: texts, errors: errors);
      await for (final file in directory.list()) {
        if (file is! File || !file.path.endsWith('.json')) continue;
        final name = file.uri.pathSegments.last;
        final noteId = name.substring(0, name.length - 5);
        try {
          final notes = (jsonDecode(await file.readAsString()) as List).map(
            (json) => VoiceNote.fromJson(Map<String, dynamic>.from(json)),
          );
          texts[noteId] = notes.map((note) => note.searchableText).join('\n');
        } catch (error) {
          errors[noteId] = '$error';
        }
      }
      return (texts: texts, errors: errors);
    });
  }
}
