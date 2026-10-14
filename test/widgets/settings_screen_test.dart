import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:exnote/controllers/library_index_controller.dart';
import 'package:exnote/controllers/note_settings_controller.dart';
import 'package:exnote/models/indexing/indexing_settings.dart';
import 'package:exnote/providers/note_index_provider.dart';
import 'package:exnote/providers/note_settings_provider.dart';
import 'package:exnote/screens/settings_screen.dart';
import 'package:exnote/services/indexing/local_note_analyzer.dart';
import 'package:exnote/services/indexing/note_index_repository.dart';
import 'package:exnote/services/indexing/note_library_source.dart';
import 'package:exnote/services/notes/note_page_renderer.dart';
import 'package:exnote/services/storage_service.dart';

void main() {
  testWidgets(
    'shared settings persists speech and separates scan model from chat model',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final settings = NoteSettingsController();
      await settings.load();
      final storage = StorageService(directory: Directory.systemTemp);
      final index =
          LibraryIndexController(
              repository: NoteIndexRepository(directory: Directory.systemTemp),
              source: NoteLibrarySource(storage),
              analyzer: LocalNoteAnalyzer(),
              renderer: NotePageRenderer(),
            )
            ..isReady = true
            ..settings = const IndexingSettings(
              backend: IndexingBackend.openRouter,
            );
      final container = ProviderContainer(
        overrides: [
          noteSettingsProvider.overrideWith((_) => settings),
          noteIndexProvider.overrideWith((_) => index),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(storage.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.text('Read replies aloud'),
        400,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read replies aloud'));
      await tester.pump(const Duration(milliseconds: 350));
      expect(settings.settings.readRepliesAloud, true);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('readRepliesAloud'), true);
      expect(find.text('Scan notes with'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Scan model'),
        250,
        scrollable: scroll,
      );
      await tester.pumpAndSettle();
      final dropdown = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Scan model',
      );
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('GPT-6 Astra · highest cost').last);
      await tester.pumpAndSettle();
      expect(index.settings.model, 'openai/gpt-6-astra');
      expect(prefs.getString('indexingCloudModel'), 'openai/gpt-6-astra');
      expect(settings.settings.aiModel, 'openai/gpt-6-luna');
      // Reopen the same page via another entry point with editor callbacks.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: SettingsScreen(onAdjustNoteLook: () {})),
        ),
      );
      await tester.pumpAndSettle();
      expect(settings.settings.readRepliesAloud, true);
      expect(index.settings.model, 'openai/gpt-6-astra');
    },
  );
}
