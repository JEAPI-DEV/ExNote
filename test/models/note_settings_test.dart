import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:exnote/models/note_settings.dart';

void main() {
  test('saves and loads toolbar look settings', () async {
    SharedPreferences.setMockInitialValues({});

    final settings = const NoteSettings.defaults().copyWith(
      toolbarPositionX: 0.25,
      toolbarPositionY: 0.75,
      toolbarOrientation: NoteToolbarOrientation.vertical,
      editPopupPositionX: 0.6,
      editPopupPositionY: 0.2,
      editPopupOrientation: NoteToolbarOrientation.vertical,
      widthPresetPopupPositionX: 0.1,
      widthPresetPopupPositionY: 0.9,
    );

    await settings.save();

    final prefs = await SharedPreferences.getInstance();
    final loaded = NoteSettings.fromPrefs(prefs);

    expect(loaded.toolbarPositionX, 0.25);
    expect(loaded.toolbarPositionY, 0.75);
    expect(loaded.toolbarOrientation, NoteToolbarOrientation.vertical);
    expect(loaded.editPopupPositionX, 0.6);
    expect(loaded.editPopupPositionY, 0.2);
    expect(loaded.editPopupOrientation, NoteToolbarOrientation.vertical);
    expect(loaded.widthPresetPopupPositionX, 0.1);
    expect(loaded.widthPresetPopupPositionY, 0.9);
  });

  test('clamps look coordinates loaded from preferences', () async {
    SharedPreferences.setMockInitialValues({
      'toolbarPositionX': 2.0,
      'toolbarPositionY': -1.0,
      'editPopupPositionX': 3.0,
      'editPopupPositionY': -2.0,
      'widthPresetPopupPositionX': 4.0,
      'widthPresetPopupPositionY': -3.0,
    });

    final prefs = await SharedPreferences.getInstance();
    final loaded = NoteSettings.fromPrefs(prefs);

    expect(loaded.toolbarPositionX, 1.0);
    expect(loaded.toolbarPositionY, 0.0);
    expect(loaded.editPopupPositionX, 1.0);
    expect(loaded.editPopupPositionY, 0.0);
    expect(loaded.widthPresetPopupPositionX, 1.0);
    expect(loaded.widthPresetPopupPositionY, 0.0);
  });

  test('defaults edit popup position to automatic placement', () async {
    SharedPreferences.setMockInitialValues({});

    final prefs = await SharedPreferences.getInstance();
    final loaded = NoteSettings.fromPrefs(prefs);

    expect(loaded.editPopupPositionX, isNull);
    expect(loaded.editPopupPositionY, isNull);
    expect(loaded.editPopupOrientation, NoteToolbarOrientation.horizontal);
    expect(loaded.widthPresetPopupPositionX, isNull);
    expect(loaded.widthPresetPopupPositionY, isNull);
  });
}
