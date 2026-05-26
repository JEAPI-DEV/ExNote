import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:exnote/controllers/note_look_controller.dart';
import 'package:exnote/models/note_settings.dart';
import 'package:exnote/utils/note_look_layout.dart';

void main() {
  group('NoteLookController', () {
    test('keeps draft edits isolated until confirmation', () {
      final controller = NoteLookController();
      final initial = const NoteSettings.defaults();

      controller.startEditing(initial);
      controller.setToolbarPosition(const Offset(0.4, 0.8));
      controller.setEditPopupPosition(const Offset(0.2, 0.3));
      controller.setWidthPresetPopupPosition(const Offset(0.7, 0.6));
      controller.setToolbarOrientation(NoteToolbarOrientation.vertical);
      controller.setEditPopupOrientation(NoteToolbarOrientation.vertical);

      expect(initial.toolbarPositionX, 0.0);
      expect(initial.editPopupPositionX, isNull);

      final confirmed = controller.confirmEditing(initial);

      expect(confirmed.toolbarPositionX, 0.4);
      expect(confirmed.toolbarPositionY, 0.8);
      expect(confirmed.editPopupPositionX, 0.2);
      expect(confirmed.editPopupPositionY, 0.3);
      expect(confirmed.widthPresetPopupPositionX, 0.7);
      expect(confirmed.widthPresetPopupPositionY, 0.6);
      expect(confirmed.toolbarOrientation, NoteToolbarOrientation.vertical);
      expect(confirmed.editPopupOrientation, NoteToolbarOrientation.vertical);
      expect(controller.isEditing, isFalse);
    });

    test('cancel discards draft edits', () {
      final controller = NoteLookController();
      final settings = const NoteSettings.defaults();

      controller.startEditing(settings);
      controller.setToolbarPosition(const Offset(0.4, 0.8));
      controller.cancelEditing();

      expect(controller.toolbarPosition(settings), const Offset(0.0, 1.0));
      expect(controller.isEditing, isFalse);
    });
  });

  group('NoteLookLayout', () {
    test('converts top-left coordinates to normalized coordinates', () {
      final normalized = NoteLookLayout.normalizedFromTopLeft(
        constraints: const BoxConstraints.tightFor(width: 300, height: 200),
        itemSize: const Size(100, 50),
        topLeft: const Offset(100, 75),
      );

      expect(normalized.dx, 0.5);
      expect(normalized.dy, 0.5);
    });

    test(
      'auto popup placement chooses left side when right side has no room',
      () {
        final topLeft = NoteLookLayout.autoEditPopupTopLeft(
          constraints: const BoxConstraints.tightFor(width: 400, height: 300),
          toolbarSize: const Size(80, 80),
          toolbarTopLeft: const Offset(300, 100),
          popupSize: const Size(100, 60),
        );

        expect(topLeft.dx, 188);
        expect(topLeft.dy, 110);
      },
    );

    test('auto width preset popup placement stays near toolbar', () {
      final topLeft = NoteLookLayout.autoWidthPresetPopupTopLeft(
        constraints: const BoxConstraints.tightFor(width: 500, height: 400),
        toolbarSize: const Size(200, 80),
        toolbarTopLeft: const Offset(100, 300),
        popupSize: NoteLookLayout.widthPresetPopupSize,
      );

      expect(topLeft.dx, 78);
      expect(topLeft.dy, 202);
    });
  });
}
