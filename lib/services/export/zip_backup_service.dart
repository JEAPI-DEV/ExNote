import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../utils/export_directory.dart';
import '../backup/backup_archive.dart';

class ZipBackupService {
  static Future<File> createBackup() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = await ExportDirectory.get();
    final zipPath =
        '${exportDir.path}/exnote_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

    await BackupArchive.create(appDir.path, zipPath);
    return File(zipPath);
  }
}
