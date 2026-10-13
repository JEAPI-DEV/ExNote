import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/app_config.dart';

enum IndexingBackend { local, openRouter }

class IndexingSettings {
  final IndexingBackend backend;
  final String model;
  const IndexingSettings({
    this.backend = IndexingBackend.local,
    this.model = AppConfig.defaultAiModel,
  });

  factory IndexingSettings.fromPrefs(SharedPreferences prefs) =>
      IndexingSettings(
        backend: prefs.getString('indexingBackend') == 'openRouter'
            ? IndexingBackend.openRouter
            : IndexingBackend.local,
        model: AppConfig.migrateAiModel(prefs.getString('indexingCloudModel')),
      );

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('indexingBackend', backend.name);
    await prefs.setString('indexingCloudModel', model);
  }

  IndexingSettings copyWith({IndexingBackend? backend, String? model}) =>
      IndexingSettings(
        backend: backend ?? this.backend,
        model: model ?? this.model,
      );
}
