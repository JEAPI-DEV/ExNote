import 'dart:io';

/// Serializes writes and replaces files only after their new contents are flushed.
class AtomicFileStore {
  Future<void> _pending = Future.value();

  Future<bool> write(
    File file,
    String contents, {
    bool skipIfIdentical = false,
  }) {
    final operation = _pending.then((_) async {
      if (skipIfIdentical &&
          await file.exists() &&
          await file.readAsString() == contents) {
        return false;
      }
      await file.parent.create(recursive: true);
      final temporary = File('${file.path}.writing');
      try {
        await temporary.writeAsString(contents, flush: true);
        await temporary.rename(file.path);
        return true;
      } finally {
        if (await temporary.exists()) await temporary.delete();
      }
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  Future<void> flush() => _pending;
}
