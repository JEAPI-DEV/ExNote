import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/note_settings_controller.dart';

// All settings entry points and open editors share one loaded, persisted state.
final noteSettingsProvider = ChangeNotifierProvider<NoteSettingsController>((
  ref,
) {
  final controller = NoteSettingsController();
  controller.load();
  return controller;
});
