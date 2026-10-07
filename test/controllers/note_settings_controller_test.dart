import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exnote/controllers/note_settings_controller.dart';

void main() {
  test(
    'closing before settings load does not overwrite the saved API token',
    () async {
      SharedPreferences.setMockInitialValues({
        'openRouterToken': 'keep-token',
        'aiModel': 'openai/gpt-6.1-sol',
      });
      final controller = NoteSettingsController();
      final loading = controller.load();
      controller.dispose();
      await loading;
      await Future<void>.delayed(Duration.zero);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('openRouterToken'), 'keep-token');
      expect(prefs.getString('aiModel'), 'openai/gpt-6.1-sol');
    },
  );
}
