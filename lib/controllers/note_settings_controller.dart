import 'package:flutter/material.dart';
import '../models/note_settings.dart';
import '../services/settings_service.dart';

class NoteSettingsController extends ChangeNotifier {
  NoteSettings _settings = const NoteSettings.defaults();
  final TextEditingController tokenController = TextEditingController();

  NoteSettings get settings => _settings;

  Future<void> load() async {
    _settings = await SettingsService.loadSettings();
    tokenController.text = _settings.openRouterToken;
    notifyListeners();
  }

  void update(NoteSettings Function(NoteSettings) updater) {
    _settings = updater(_settings);
    SettingsService.saveSettings(_settings);
    notifyListeners();
  }

  @override
  void dispose() {
    tokenController.dispose();
    super.dispose();
  }
}
