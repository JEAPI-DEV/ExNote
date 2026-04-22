import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../utils/export_directory.dart';

class ZipExportService {
  static Future<File> exportToZip() async {
    final appDir = await getApplicationDocumentsDirectory();
    final exportDir = await ExportDirectory.get();
    final zipPath =
        '${exportDir.path}/exnote_backup_${DateTime.now().millisecondsSinceEpoch}.zip';

    final encoder = ZipFileEncoder();
    encoder.create(zipPath);

    final files = appDir.listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        final relativePath = path.relative(file.path, from: appDir.path);
        await encoder.addFile(file, relativePath);
      }
    }

    encoder.close();
    return File(zipPath);
  }
}
