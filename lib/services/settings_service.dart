import 'package:shared_preferences/shared_preferences.dart';
import '../models/note_settings.dart';

class SettingsService {
  static Future<NoteSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return NoteSettings.fromPrefs(prefs);
  }

  static Future<void> saveSettings(NoteSettings settings) => settings.save();
}
