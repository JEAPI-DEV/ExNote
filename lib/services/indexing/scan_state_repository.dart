import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../models/indexing/scan_run_state.dart';
import '../atomic_file_store.dart';

/// Durable job progress and diagnostics are separate from per-note annotations.
class ScanStateRepository {
  final Directory? directory;
  final _files = AtomicFileStore();
  ScanStateRepository({this.directory});
  Future<File> get _file async => File(
    '${(directory ?? await getApplicationDocumentsDirectory()).path}/indexing/scan_state.json',
  );
  Future<ScanRunState?> load() async {
    final file = await _file;
    if (!await file.exists()) return null;
    return ScanRunState.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
  }

  Future<void> save(ScanRunState state) async =>
      _files.write(await _file, jsonEncode(state.toJson()));
}
