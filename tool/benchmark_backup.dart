import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:archive/archive_io.dart';
import 'package:exnote/services/backup/backup_archive.dart';

/// Runs on synthetic files, never on the user's library.
Future<void> main() async {
  final root = await Directory.systemTemp.createTemp('exnote_backup_benchmark');
  try {
    final source = await Directory('${root.path}/library').create();
    final random = Random(42);
    final pdf = Uint8List.fromList(
      List.generate(16 * 1024 * 1024, (_) => random.nextInt(256)),
    );
    await File('${source.path}/lecture.pdf').writeAsBytes(pdf);
    final handwriting = jsonEncode({
      'lines': List.generate(
        20000,
        (i) => {'x': i % 800, 'y': i, 'pressure': 0.5},
      ),
    });
    for (int i = 0; i < 8; i++) {
      await File('${source.path}/note_$i.json').writeAsString(handwriting);
    }
    Future<void> original(String destination) async {
      final encoder = ZipFileEncoder()..create(destination);
      for (final file in source.listSync()) {
        if (file is File) await encoder.addFile(file);
      }
      await encoder.close();
    }

    Future<Map<String, num>> measure(
      Future<void> Function(String) archive,
      String name,
    ) async {
      int longestGap = 0;
      final timerClock = Stopwatch()..start();
      var previous = 0;
      final timer = Timer.periodic(const Duration(milliseconds: 10), (_) {
        final current = timerClock.elapsedMilliseconds;
        longestGap = max(longestGap, current - previous);
        previous = current;
      });
      final output = '${root.path}/$name.zip';
      final elapsed = Stopwatch()..start();
      await archive(output);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      elapsed.stop();
      timer.cancel();
      return {
        'milliseconds': elapsed.elapsedMilliseconds,
        'max_ui_timer_gap_ms': longestGap,
        'zip_bytes': await File(output).length(),
      };
    }

    final before = await measure(original, 'before');
    final after = await measure(
      (output) => BackupArchive.create(source.path, output),
      'after',
    );
    stdout.writeln(
      jsonEncode({
        'synthetic_library': '16 MiB PDF + 8 handwritten notes',
        'before': before,
        'after': after,
      }),
    );
  } finally {
    await root.delete(recursive: true);
  }
}
