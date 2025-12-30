import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/folder.dart';

class StorageService {
  static const String _fileName = 'folders.json';

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/$_fileName');
  }

  Future<List<Folder>> loadFolders() async {
    try {
      final file = await _localFile;
      if (!await file.exists()) {
        return [];
      }
      final contents = await file.readAsString();
      debugPrint('DEBUG: folders.json content length: ${contents.length}');
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => Folder.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFolders(List<Folder> folders) async {
    final file = await _localFile;
    final jsonString = await _runFoldersSerialization(folders);
    await file.writeAsString(jsonString);
  }

  Future<void> saveNote(String noteId, String sketchJson) async {
    final path = await _localPath;
    final file = File('$path/note_$noteId.json');
    await file.writeAsString(sketchJson);
  }

  Future<String?> loadNote(String noteId) async {
    try {
      final path = await _localPath;
      final file = File('$path/note_$noteId.json');
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      return null;
    }
  }
}

String _serializeFolders(List<Folder> folders) {
  // DO NOT clear scribbleData here anymore.
  // We will handle clearing it only after we are 100% sure it's migrated.
  final jsonList = folders.map((f) => f.toJson()).toList();
  return jsonEncode(jsonList);
}

Future<String> _runFoldersSerialization(List<Folder> folders) {
  return Isolate.run(() => _serializeFolders(folders));
}
