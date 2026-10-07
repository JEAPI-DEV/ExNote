import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/folder.dart';
import 'atomic_file_store.dart';
import '../utils/storage_paths.dart';

class StorageService {
  final _changes = StreamController<String>.broadcast();
  Stream<String> get changedNotes => _changes.stream;
  Future<void> dispose() => _changes.close();

  final AtomicFileStore _files = AtomicFileStore();
  final Directory? directory;

  StorageService({this.directory});

  Future<void> flush() async {
    await _folderWrites;
    await _files.flush();
  }

  Future<Directory> get rootDirectory async =>
      directory ?? await getApplicationDocumentsDirectory();
  static const String _fileName = 'folders.json';

  Future<String> get _localPath async {
    final root = directory ?? await getApplicationDocumentsDirectory();
    return root.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<List<Folder>> loadFolders() async {
    try {
      final file = await _localFile;
      return await Isolate.run(() async {
        if (!await file.exists()) return <Folder>[];
        final contents = await file.readAsString();
        final jsonList = jsonDecode(contents) as List;
        return jsonList
            .map((json) => Folder.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      });
    } catch (e) {
      debugPrint('Could not load library: $e');
      rethrow;
    }
  }

  Future<void> saveFolders(List<Folder> folders) async {
    final file = await _localFile;
    // Queue before serializing so an older snapshot cannot finish after a newer one.
    await _queueFoldersSave(file, folders);
  }

  Future<void> saveNote(String noteId, String sketchJson) async {
    safeStorageId(noteId);
    final path = await _localPath;
    final file = File('$path/note_$noteId.json');
    final changed = await _files.write(file, sketchJson, skipIfIdentical: true);
    if (changed) _changes.add(noteId);
  }

  Future<String?> loadNote(String noteId) async {
    safeStorageId(noteId);
    try {
      final path = await _localPath;
      final file = File('$path/note_$noteId.json');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      debugPrint('Could not load note $noteId: $e');
      rethrow;
    }
  }

  Future<void> importNoteFile(String noteId, File sourceFile) async {
    safeStorageId(noteId);
    final path = await _localPath;
    final destination = File('$path/note_$noteId.json');
    if (await sourceFile.exists()) {
      await sourceFile.copy(destination.path);
    }
  }

  Future<void> importScreenshot(String fileName, File sourceFile) async {
    final path = await _localPath;
    final destination = File('$path/$fileName');
    if (await sourceFile.exists()) {
      await sourceFile.copy(destination.path);
    }
  }

  Future<void> _folderWrites = Future.value();

  Future<void> _queueFoldersSave(File file, List<Folder> folders) {
    final operation = _folderWrites.then((_) async {
      final json = await _runFoldersSerialization(folders);
      await _files.write(file, json);
    });
    _folderWrites = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }
}

String _serializeFolders(List<Folder> folders) {
  final jsonList = folders.map((f) => f.toJson()).toList();
  return jsonEncode(jsonList);
}

Future<String> _runFoldersSerialization(List<Folder> folders) {
  return Isolate.run(() => _serializeFolders(folders));
}
