import 'dart:async';
import 'package:flutter/material.dart';
import '../models/note_settings.dart';
import '../services/settings_service.dart';

class NoteSettingsController extends ChangeNotifier {
  NoteSettings _settings = const NoteSettings.defaults();
  final TextEditingController tokenController = TextEditingController();
  Timer? _saveTimer;
  Future<void> _pending = Future.value();
  bool _disposed = false;
  bool _hasChanges = false;
  String? saveError;

  NoteSettings get settings => _settings;

  Future<void> load() async {
    final settings = await SettingsService.loadSettings();
    if (_disposed) return;
    _settings = settings;
    tokenController.text = settings.openRouterToken;
    notifyListeners();
  }

  void update(NoteSettings Function(NoteSettings) updater) {
    _settings = updater(_settings);
    _hasChanges = true;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
    notifyListeners();
  }

  void _save() {
    if (!_hasChanges) return;
    _hasChanges = false;
    final snapshot = _settings;
    _pending = _pending
        .then((_) => SettingsService.saveSettings(snapshot))
        .catchError((Object error) {
          saveError = 'Could not save settings: $error';
          if (!_disposed) notifyListeners();
        });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _save();
    _disposed = true;
    tokenController.dispose();
    super.dispose();
  }
}
