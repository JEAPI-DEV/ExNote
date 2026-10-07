import 'dart:async';

/// Debounces changes and waits until the pen is up before persisting a snapshot.
class NoteAutosaveController {
  final Future<void> Function() save;
  final void Function(Object error) onError;
  Timer? _timer;
  bool _drawing = false;
  bool _saving = false;
  bool _dirty = false;
  bool _disposed = false;
  NoteAutosaveController({required this.save, required this.onError});

  void changed() {
    _dirty = true;
    _schedule();
  }

  void setDrawing(bool value) {
    _drawing = value;
    if (value) {
      _timer?.cancel();
    } else if (_dirty) {
      _schedule();
    }
  }

  void cancel() {
    _timer?.cancel();
  }

  void _schedule() {
    _timer?.cancel();
    if (_disposed || _drawing) return;
    _timer = Timer(const Duration(seconds: 2), _run);
  }

  Future<void> _run() async {
    if (_disposed || _drawing || !_dirty) return;
    if (_saving) {
      _schedule();
      return;
    }
    _saving = true;
    _dirty = false;
    try {
      await save();
    } catch (error) {
      _dirty = true;
      if (!_disposed) onError(error);
    } finally {
      _saving = false;
      if (_dirty && !_disposed) _schedule();
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}
