class AppConfig {
  static const List<Map<String, String>> aiModels = [
    {'id': 'openai/gpt-6-luna', 'name': 'GPT-6 Luna · economical'},
    {'id': 'openai/gpt-6.1-sol', 'name': 'GPT-6.1 Sol · advanced'},
    {'id': 'openai/gpt-6-astra', 'name': 'GPT-6 Astra · highest cost'},
  ];

  static const String defaultAiModel = 'openai/gpt-6-luna';

  static String migrateAiModel(String? model) =>
      aiModels.any((entry) => entry['id'] == model) ? model! : defaultAiModel;
  static const double defaultStrokeWidth = 2.0;
  static const double defaultAiDrawerWidth = 320.0;
  static const bool defaultGridEnabled = false;
  static const int defaultGridTypeIndex = 0;
  static const double defaultGridSpacing = 40.0;
  static const bool defaultTutorEnabled = false;
  static const bool defaultSubmitLastImageOnly = true;
  static const bool defaultShapeSnappingEnabled = true;
}
