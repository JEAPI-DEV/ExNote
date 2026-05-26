import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_config.dart';
import 'grid_type.dart';

enum NoteToolbarOrientation { horizontal, vertical }

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
  final double toolbarPositionX;
  final double toolbarPositionY;
  final NoteToolbarOrientation toolbarOrientation;
  final double? editPopupPositionX;
  final double? editPopupPositionY;
  final NoteToolbarOrientation editPopupOrientation;
  final double? widthPresetPopupPositionX;
  final double? widthPresetPopupPositionY;

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
    required this.toolbarPositionX,
    required this.toolbarPositionY,
    required this.toolbarOrientation,
    required this.editPopupPositionX,
    required this.editPopupPositionY,
    required this.editPopupOrientation,
    required this.widthPresetPopupPositionX,
    required this.widthPresetPopupPositionY,
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
      shapeSnappingEnabled = AppConfig.defaultShapeSnappingEnabled,
      toolbarPositionX = 0.0,
      toolbarPositionY = 1.0,
      toolbarOrientation = NoteToolbarOrientation.horizontal,
      editPopupPositionX = null,
      editPopupPositionY = null,
      editPopupOrientation = NoteToolbarOrientation.horizontal,
      widthPresetPopupPositionX = null,
      widthPresetPopupPositionY = null;

  factory NoteSettings.fromPrefs(SharedPreferences prefs) {
    final orientationIndex = prefs.getInt('toolbarOrientation');
    final editPopupOrientationIndex = prefs.getInt('editPopupOrientation');
    return NoteSettings(
      strokeWidth:
          prefs.getDouble('strokeWidth') ?? AppConfig.defaultStrokeWidth,
      gridEnabled: prefs.getBool('gridEnabled') ?? AppConfig.defaultGridEnabled,
      gridType: GridType
          .values[prefs.getInt('gridType') ?? AppConfig.defaultGridTypeIndex],
      gridSpacing:
          prefs.getDouble('gridSpacing') ?? AppConfig.defaultGridSpacing,
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
      toolbarPositionX: (prefs.getDouble('toolbarPositionX') ?? 0.0)
          .clamp(0.0, 1.0)
          .toDouble(),
      toolbarPositionY: (prefs.getDouble('toolbarPositionY') ?? 1.0)
          .clamp(0.0, 1.0)
          .toDouble(),
      toolbarOrientation:
          orientationIndex != null &&
              orientationIndex >= 0 &&
              orientationIndex < NoteToolbarOrientation.values.length
          ? NoteToolbarOrientation.values[orientationIndex]
          : NoteToolbarOrientation.horizontal,
      editPopupPositionX: prefs
          .getDouble('editPopupPositionX')
          ?.clamp(0.0, 1.0)
          .toDouble(),
      editPopupPositionY: prefs
          .getDouble('editPopupPositionY')
          ?.clamp(0.0, 1.0)
          .toDouble(),
      editPopupOrientation:
          editPopupOrientationIndex != null &&
              editPopupOrientationIndex >= 0 &&
              editPopupOrientationIndex < NoteToolbarOrientation.values.length
          ? NoteToolbarOrientation.values[editPopupOrientationIndex]
          : NoteToolbarOrientation.horizontal,
      widthPresetPopupPositionX: prefs
          .getDouble('widthPresetPopupPositionX')
          ?.clamp(0.0, 1.0)
          .toDouble(),
      widthPresetPopupPositionY: prefs
          .getDouble('widthPresetPopupPositionY')
          ?.clamp(0.0, 1.0)
          .toDouble(),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final writes = <Future<bool>>[
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
      prefs.setDouble('toolbarPositionX', toolbarPositionX),
      prefs.setDouble('toolbarPositionY', toolbarPositionY),
      prefs.setInt('toolbarOrientation', toolbarOrientation.index),
      editPopupPositionX == null
          ? prefs.remove('editPopupPositionX')
          : prefs.setDouble('editPopupPositionX', editPopupPositionX!),
      editPopupPositionY == null
          ? prefs.remove('editPopupPositionY')
          : prefs.setDouble('editPopupPositionY', editPopupPositionY!),
      prefs.setInt('editPopupOrientation', editPopupOrientation.index),
      widthPresetPopupPositionX == null
          ? prefs.remove('widthPresetPopupPositionX')
          : prefs.setDouble(
              'widthPresetPopupPositionX',
              widthPresetPopupPositionX!,
            ),
      widthPresetPopupPositionY == null
          ? prefs.remove('widthPresetPopupPositionY')
          : prefs.setDouble(
              'widthPresetPopupPositionY',
              widthPresetPopupPositionY!,
            ),
    ];
    await Future.wait(writes);
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
    double? toolbarPositionX,
    double? toolbarPositionY,
    NoteToolbarOrientation? toolbarOrientation,
    double? editPopupPositionX,
    double? editPopupPositionY,
    NoteToolbarOrientation? editPopupOrientation,
    double? widthPresetPopupPositionX,
    double? widthPresetPopupPositionY,
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
    toolbarPositionX: toolbarPositionX ?? this.toolbarPositionX,
    toolbarPositionY: toolbarPositionY ?? this.toolbarPositionY,
    toolbarOrientation: toolbarOrientation ?? this.toolbarOrientation,
    editPopupPositionX: editPopupPositionX ?? this.editPopupPositionX,
    editPopupPositionY: editPopupPositionY ?? this.editPopupPositionY,
    editPopupOrientation: editPopupOrientation ?? this.editPopupOrientation,
    widthPresetPopupPositionX:
        widthPresetPopupPositionX ?? this.widthPresetPopupPositionX,
    widthPresetPopupPositionY:
        widthPresetPopupPositionY ?? this.widthPresetPopupPositionY,
  );
}
