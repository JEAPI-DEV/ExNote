import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../models/folder.dart';
import '../providers/folder_provider.dart';
import 'backup/backup_archive.dart';
import 'export/zip_backup_service.dart';
import 'package:share_plus/share_plus.dart';

class BackupService {
  static bool _exporting = false;
  static bool _importing = false;

  static Future<void> exportBackup(BuildContext context, WidgetRef ref) async {
    if (_exporting) return;
    _exporting = true;
    final storage = ref.read(storageServiceProvider);
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Creating backup'),
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Expanded(child: Text('Saving your library to ZIP…')),
            ],
          ),
        ),
      ),
    );
    unawaited(navigator.push(route));
    File? file;
    Object? error;
    try {
      await storage.flush();
      file = await ZipBackupService.createBackup();
    } catch (exception) {
      error = exception;
    } finally {
      _exporting = false;
      if (route.isActive) navigator.removeRoute(route);
    }
    if (!context.mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Backup failed: $error')));
      return;
    }
    try {
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file!.path)], text: 'ExNote backup'),
      );
    } catch (exception) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Backup saved to ${file!.path}; sharing failed: $exception',
            ),
          ),
        );
      }
    }
  }

  static Future<void> importFromBackup(
    BuildContext context,
    WidgetRef ref,
  ) async {
    if (_importing) return;
    _importing = true;
    final folders = ref.read(folderProvider.notifier);
    Directory? tempDir;
    DialogRoute<void>? progress;
    NavigatorState? navigator;
    try {
      // 1. Pick the .zip backup file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return; // User canceled
      }

      if (!context.mounted) return;
      navigator = Navigator.of(context, rootNavigator: true);
      progress = DialogRoute<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const PopScope(
          canPop: false,
          child: AlertDialog(
            title: Text('Restoring backup'),
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 20),
                Expanded(child: Text('Restoring notes and recordings…')),
              ],
            ),
          ),
        ),
      );
      unawaited(navigator.push(progress));
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
      await BackupArchive.extract(zipFile.path, tempDir.path);

      // 4. Find folders.json (it might be in a subdirectory)
      File? foldersJsonFile;
      String? actualSourcePath;

      await for (final entity in tempDir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File && entity.uri.pathSegments.last == 'folders.json') {
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
      final importedFolders = await Isolate.run(() {
        final jsonList = jsonDecode(contents) as List;
        return jsonList
            .map((json) => Folder.fromJson(Map<String, dynamic>.from(json)))
            .toList();
      });

      // 6. Call provider to merge
      await folders.mergeFromBackup(importedFolders, actualSourcePath!);

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
      _importing = false;
      if (progress?.isActive == true && navigator!.mounted) {
        navigator.removeRoute(progress!);
      }
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
