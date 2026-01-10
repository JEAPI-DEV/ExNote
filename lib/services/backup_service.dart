import 'dart:convert';
import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';

class BackupService {
  static Future<void> importFromBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    Directory? tempDir;
    try {
      // 1. Pick the .zip backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled
      }

      final zipFile = File(result.files.single.path!);

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unzipping backup...')));
      }

      // 2. Create a temporary directory to unzip
      final appTempDir = await getTemporaryDirectory();
      tempDir = await Directory(
        '${appTempDir.path}/exnote_import_${DateTime.now().millisecondsSinceEpoch}',
      ).create(recursive: true);

      // 3. Extract the ZIP file
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('${tempDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('${tempDir.path}/$filename').createSync(recursive: true);
        }
      }

      // 4. Find folders.json (it might be in a subdirectory)
      File? foldersJsonFile;
      String? actualSourcePath;

      final extractedFiles = tempDir.listSync(recursive: true);
      for (final entity in extractedFiles) {
        if (entity is File && entity.path.endsWith('folders.json')) {
          foldersJsonFile = entity;
          actualSourcePath = entity.parent.path;
          break;
        }
      }

      if (foldersJsonFile == null || !await foldersJsonFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Error: Invalid backup. No folders.json found in ZIP.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 5. Read and parse folders.json
      final contents = await foldersJsonFile.readAsString();
      final List<dynamic> jsonList = jsonDecode(contents);
      final importedFolders = jsonList
          .map((json) => Folder.fromJson(json))
          .toList();

      // 6. Call provider to merge
      await ref
          .read(folderProvider.notifier)
          .mergeFromBackup(importedFolders, actualSourcePath!);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully imported ${importedFolders.length} folders from ZIP.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // 7. Cleanup temp directory
      if (tempDir != null && await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (e) {
          debugPrint('Error cleaning up temp import dir: $e');
        }
      }
    }
  }
}
