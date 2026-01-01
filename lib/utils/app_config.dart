class AppConfig {
  static const List<Map<String, String>> aiModels = [
    {'id': 'google/gemini-2.0-flash-exp:free', 'name': 'FREE:Gemini 2.0 Flash'},
    {'id': 'google/gemini-3-flash-preview', 'name': 'Gemini 3 Flash'},
    {'id': 'qwen/qwen-vl-max', 'name': 'Qwen VL Max'},
    {'id': 'openai/gpt-5-mini', 'name': 'GPT-5 Mini'},
    {'id': 'z-ai/glm-4.6v', 'name': 'GLM 4.6V'},
    {'id': 'nvidia/nemotron-nano-12b-v2-vl:free', 'name': 'FREE:NV Nano V2'},
    {'id': 'qwen/qwen3-vl-235b-a22b-thinking', 'name': 'Qwen3 VL 235B'},
  ];

  static const String defaultAiModel = 'google/gemini-2.0-flash-exp:free';
  static const double defaultStrokeWidth = 2.0;
  static const double defaultAiDrawerWidth = 320.0;
  static const bool defaultGridEnabled = false;
  static const int defaultGridTypeIndex = 0;
  static const bool defaultTutorEnabled = false;
  static const bool defaultSubmitLastImageOnly = true;
}
