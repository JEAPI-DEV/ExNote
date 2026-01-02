import 'package:shared_preferences/shared_preferences.dart';
import '../models/grid_type.dart';
import '../utils/app_config.dart';

class SettingsService {
  static Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'strokeWidth':
          prefs.getDouble('strokeWidth') ?? AppConfig.defaultStrokeWidth,
      'gridEnabled':
          prefs.getBool('gridEnabled') ?? AppConfig.defaultGridEnabled,
      'gridType': GridType
          .values[prefs.getInt('gridType') ?? AppConfig.defaultGridTypeIndex],
      'gridSpacing':
          prefs.getDouble('gridSpacing') ?? AppConfig.defaultGridSpacing,
      'openRouterToken': prefs.getString('openRouterToken') ?? '',
      'aiModel': prefs.getString('aiModel') ?? AppConfig.defaultAiModel,
      'tutorEnabled':
          prefs.getBool('tutorEnabled') ?? AppConfig.defaultTutorEnabled,
      'submitLastImageOnly':
          prefs.getBool('submitLastImageOnly') ??
          AppConfig.defaultSubmitLastImageOnly,
      'aiDrawerWidth':
          prefs.getDouble('aiDrawerWidth') ?? AppConfig.defaultAiDrawerWidth,
    };
  }

  static Future<void> saveSettings({
    required double strokeWidth,
    required bool gridEnabled,
    required GridType gridType,
    required double gridSpacing,
    required String openRouterToken,
    required String aiModel,
    required bool tutorEnabled,
    required bool submitLastImageOnly,
    required double aiDrawerWidth,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('strokeWidth', strokeWidth);
    await prefs.setBool('gridEnabled', gridEnabled);
    await prefs.setInt('gridType', gridType.index);
    await prefs.setDouble('gridSpacing', gridSpacing);
    await prefs.setString('openRouterToken', openRouterToken);
    await prefs.setString('aiModel', aiModel);
    await prefs.setBool('tutorEnabled', tutorEnabled);
    await prefs.setBool('submitLastImageOnly', submitLastImageOnly);
    await prefs.setDouble('aiDrawerWidth', aiDrawerWidth);
  }
}
