import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exnote/models/indexing/indexing_settings.dart';

void main() {
  test(
    'scan provider and model persist separately from chat and local weights',
    () async {
      SharedPreferences.setMockInitialValues({
        'aiModel': 'openai/gpt-6.1-sol',
        'openRouterToken': 'keep',
        'localVisionModelPath': '/owned/model.task',
      });
      await const IndexingSettings(backend: IndexingBackend.openRouter).save();
      final prefs = await SharedPreferences.getInstance();
      final loaded = IndexingSettings.fromPrefs(prefs);
      expect(loaded.backend, IndexingBackend.openRouter);
      expect(loaded.model, 'openai/gpt-6-luna');
      expect(prefs.getString('aiModel'), 'openai/gpt-6.1-sol');
      expect(prefs.getString('openRouterToken'), 'keep');
      expect(prefs.getString('localVisionModelPath'), '/owned/model.task');
      expect(prefs.containsKey('indexingScanBudget'), false);
    },
  );
}
