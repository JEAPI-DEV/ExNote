import 'dart:io';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/services/backup/backup_archive.dart';

void main() {
  late Directory directory;
  setUp(
    () async =>
        directory = await Directory.systemTemp.createTemp('exnote_backup_test'),
  );
  tearDown(() async => directory.delete(recursive: true));

  test(
    'round trips notes and recordings while excluding prior and in-progress backups',
    () async {
      final source = await Directory('${directory.path}/source').create();
      await File('${source.path}/folders.json').writeAsString('[]');
      await File(
        '${source.path}/note_a.json',
      ).writeAsString('{"sketch":{"lines":[]}}');
      await Directory('${source.path}/recordings').create();
      await File('${source.path}/recordings/a.m4a').writeAsBytes([1, 2, 3, 4]);
      await File('${source.path}/exnote_backup_old.zip').writeAsBytes([0]);
      await File('${source.path}/note_b.json.writing').writeAsString('partial');
      final zip = '${source.path}/exnote_backup_new.zip';
      await BackupArchive.create(source.path, zip);
      final destination = await Directory(
        '${directory.path}/restored',
      ).create();
      await BackupArchive.extract(zip, destination.path);
      expect(
        await File('${destination.path}/note_a.json').readAsString(),
        '{"sketch":{"lines":[]}}',
      );
      expect(await File('${destination.path}/recordings/a.m4a').readAsBytes(), [
        1,
        2,
        3,
        4,
      ]);
      expect(
        await File('${destination.path}/exnote_backup_old.zip').exists(),
        false,
      );
      expect(
        await File('${destination.path}/exnote_backup_new.zip').exists(),
        false,
      );
      expect(
        await File('${destination.path}/note_b.json.writing').exists(),
        false,
      );
      expect(await File('$zip.partial').exists(), false);
    },
  );

  test('rejects ZIP entries that escape the extraction directory', () async {
    final archive = Archive()
      ..addFile(ArchiveFile('../outside.txt', 3, [1, 2, 3]));
    final zip = File('${directory.path}/unsafe.zip');
    await zip.writeAsBytes(ZipEncoder().encode(archive));
    final destination = await Directory('${directory.path}/restore').create();
    await expectLater(
      BackupArchive.extract(zip.path, destination.path),
      throwsFormatException,
    );
    expect(await File('${directory.path}/outside.txt').exists(), false);
  });
}
