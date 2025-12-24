import 'dart:convert';
import 'dart:io';
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
      final List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.map((json) => Folder.fromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveFolders(List<Folder> folders) async {
    final file = await _localFile;
    final jsonList = folders.map((f) => f.toJson()).toList();
    await file.writeAsString(jsonEncode(jsonList));
  }
}
