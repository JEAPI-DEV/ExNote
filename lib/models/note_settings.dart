import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_config.dart';
import 'grid_type.dart';

/// Typed model for all note editor settings.
/// Replaces the fragile `Map<String, dynamic>` pattern.
class NoteSettings {
  final double strokeWidth;
  final bool gridEnabled;
  final GridType gridType;
  final double gridSpacing;
  final String openRouterToken;
  final String aiModel;
  final bool tutorEnabled;
  final bool submitLastImageOnly;
  final double aiDrawerWidth;
  final bool shapeSnappingEnabled;

  const NoteSettings({
    required this.strokeWidth,
    required this.gridEnabled,
    required this.gridType,
    required this.gridSpacing,
    required this.openRouterToken,
    required this.aiModel,
    required this.tutorEnabled,
    required this.submitLastImageOnly,
    required this.aiDrawerWidth,
    required this.shapeSnappingEnabled,
  });

  const NoteSettings.defaults()
    : strokeWidth = AppConfig.defaultStrokeWidth,
      gridEnabled = AppConfig.defaultGridEnabled,
      gridType = GridType.grid,
      gridSpacing = AppConfig.defaultGridSpacing,
      openRouterToken = '',
      aiModel = AppConfig.defaultAiModel,
      tutorEnabled = AppConfig.defaultTutorEnabled,
      submitLastImageOnly = AppConfig.defaultSubmitLastImageOnly,
      aiDrawerWidth = AppConfig.defaultAiDrawerWidth,
      shapeSnappingEnabled = AppConfig.defaultShapeSnappingEnabled;

  factory NoteSettings.fromPrefs(SharedPreferences prefs) => NoteSettings(
    strokeWidth: prefs.getDouble('strokeWidth') ?? AppConfig.defaultStrokeWidth,
    gridEnabled: prefs.getBool('gridEnabled') ?? AppConfig.defaultGridEnabled,
    gridType: GridType
        .values[prefs.getInt('gridType') ?? AppConfig.defaultGridTypeIndex],
    gridSpacing: prefs.getDouble('gridSpacing') ?? AppConfig.defaultGridSpacing,
    openRouterToken: prefs.getString('openRouterToken') ?? '',
    aiModel: prefs.getString('aiModel') ?? AppConfig.defaultAiModel,
    tutorEnabled:
        prefs.getBool('tutorEnabled') ?? AppConfig.defaultTutorEnabled,
    submitLastImageOnly:
        prefs.getBool('submitLastImageOnly') ??
        AppConfig.defaultSubmitLastImageOnly,
    aiDrawerWidth:
        prefs.getDouble('aiDrawerWidth') ?? AppConfig.defaultAiDrawerWidth,
    shapeSnappingEnabled:
        prefs.getBool('shapeSnappingEnabled') ??
        AppConfig.defaultShapeSnappingEnabled,
  );

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setDouble('strokeWidth', strokeWidth),
      prefs.setBool('gridEnabled', gridEnabled),
      prefs.setInt('gridType', gridType.index),
      prefs.setDouble('gridSpacing', gridSpacing),
      prefs.setString('openRouterToken', openRouterToken),
      prefs.setString('aiModel', aiModel),
      prefs.setBool('tutorEnabled', tutorEnabled),
      prefs.setBool('submitLastImageOnly', submitLastImageOnly),
      prefs.setDouble('aiDrawerWidth', aiDrawerWidth),
      prefs.setBool('shapeSnappingEnabled', shapeSnappingEnabled),
    ]);
  }

  NoteSettings copyWith({
    double? strokeWidth,
    bool? gridEnabled,
    GridType? gridType,
    double? gridSpacing,
    String? openRouterToken,
    String? aiModel,
    bool? tutorEnabled,
    bool? submitLastImageOnly,
    double? aiDrawerWidth,
    bool? shapeSnappingEnabled,
  }) => NoteSettings(
    strokeWidth: strokeWidth ?? this.strokeWidth,
    gridEnabled: gridEnabled ?? this.gridEnabled,
    gridType: gridType ?? this.gridType,
    gridSpacing: gridSpacing ?? this.gridSpacing,
    openRouterToken: openRouterToken ?? this.openRouterToken,
    aiModel: aiModel ?? this.aiModel,
    tutorEnabled: tutorEnabled ?? this.tutorEnabled,
    submitLastImageOnly: submitLastImageOnly ?? this.submitLastImageOnly,
    aiDrawerWidth: aiDrawerWidth ?? this.aiDrawerWidth,
    shapeSnappingEnabled: shapeSnappingEnabled ?? this.shapeSnappingEnabled,
  );
}
