import 'dart:io';
import 'dart:isolate';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

/// File streams and compression stay off the Flutter UI isolate.
class BackupArchive {
  static Future<void> create(String source, String destination) =>
      Isolate.run(() async {
        final partial = '$destination.partial';
        final encoder = ZipFileEncoder();
        final root = p.normalize(p.absolute(source));
        final output = p.normalize(p.absolute(destination));
        try {
          encoder.create(partial, level: 1);
          try {
            await for (final entity in Directory(
              root,
            ).list(recursive: true, followLinks: false)) {
              if (entity is! File) continue;
              final relative = p.relative(entity.path, from: root);
              if (p.normalize(entity.path) == output ||
                  relative.endsWith('.partial') ||
                  relative.endsWith('.writing') ||
                  (p.basename(relative).startsWith('exnote_backup_') &&
                      p.extension(relative) == '.zip')) {
                continue;
              }
              // PDFs, raster images, and recordings are already compressed.
              final compressed = {
                '.pdf',
                '.png',
                '.jpg',
                '.jpeg',
                '.m4a',
                '.zip',
              }.contains(p.extension(relative).toLowerCase());
              await encoder.addFile(entity, relative, compressed ? 0 : 1);
            }
          } finally {
            await encoder.close();
          }
          await File(partial).rename(destination);
        } catch (_) {
          if (await File(partial).exists()) await File(partial).delete();
          rethrow;
        }
      });

  static Future<void> extract(String source, String destination) =>
      Isolate.run(() async {
        final input = InputFileStream(source);
        try {
          final archive = ZipDecoder().decodeStream(input);
          final root = p.normalize(p.absolute(destination));
          for (final entry in archive) {
            final target = p.normalize(p.join(root, entry.name));
            if (p.isAbsolute(entry.name) ||
                !p.isWithin(root, target) ||
                entry.isSymbolicLink) {
              throw FormatException('Unsafe backup entry: ${entry.name}');
            }
            if (!entry.isFile) {
              await Directory(target).create(recursive: true);
              continue;
            }
            await File(target).parent.create(recursive: true);
            final output = OutputFileStream(target);
            try {
              entry.writeContent(output);
            } finally {
              await output.close();
            }
          }
        } finally {
          await input.close();
        }
      });
}
