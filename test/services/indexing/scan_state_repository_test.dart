import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/indexing/scan_run_state.dart';
import 'package:exnote/services/indexing/scan_state_repository.dart';

void main() {
  test(
    'interrupted job, remaining notes and failure details survive restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'exnote_scan_state',
      );
      addTearDown(() => directory.delete(recursive: true));
      final repository = ScanStateRepository(directory: directory);
      await repository.save(
        const ScanRunState(
          status: ScanRunStatus.waiting,
          reason: 'Waiting for connection',
          processed: 300,
          total: 612,
          pendingIds: ['current', 'next'],
          failures: {'bad': 'Malformed note data'},
          resumeAutomatically: true,
          force: false,
          checkpointNoteId: 'current',
        ),
      );
      final loaded = (await ScanStateRepository(directory: directory).load())!;
      expect(loaded.status, ScanRunStatus.waiting);
      expect(loaded.pendingIds, ['current', 'next']);
      expect(loaded.processed, 300);
      expect(loaded.failures['bad'], 'Malformed note data');
      expect(loaded.resumeAutomatically, true);
    },
  );
}
