import 'dart:convert';
import '../../models/note_document.dart';
import '../indexing/note_library_source.dart';
import '../indexing/note_search.dart';
import 'package:flutter/foundation.dart';
import '../../models/indexing/note_index.dart';
import '../notes/note_page_renderer.dart';
import '../voice/voice_note_repository.dart';
import 'note_chat_context.dart';

/// Supplies the full current canvas and bounded, relevant library references.
class NoteContextService {
  final NotePageRenderer renderer;
  final NoteLibrarySource source;
  NoteDocument? _cachedDocument;
  String? _cachedBackground;
  List<String>? _cachedPages;
  final VoiceNoteRepository voiceNotes;
  NoteContextService({
    required this.renderer,
    required this.source,
    required this.voiceNotes,
  });

  Future<NoteChatContext> build({
    required String query,
    required LibraryNote current,
    required NoteDocument document,
    required List<LibraryNote> library,
    Map<String, NoteIndex> indexes = const {},
    Map<String, String> voiceTexts = const {},
  }) async {
    final cacheMatches =
        _cachedDocument != null &&
        identical(document.sketch, _cachedDocument!.sketch) &&
        listEquals(document.images, _cachedDocument!.images) &&
        listEquals(document.objects, _cachedDocument!.objects) &&
        current.backgroundPath == _cachedBackground;
    final pages = cacheMatches ? _cachedPages! : <String>[];
    if (!cacheMatches) {
      await for (final page in renderer.render(
        document,
        backgroundPath: current.backgroundPath,
      )) {
        pages.add(base64Encode(page.png));
      }
      _cachedDocument = document;
      _cachedBackground = current.backgroundPath;
      _cachedPages = pages;
    }
    final recordings = await voiceNotes.load(current.id);
    final context = StringBuffer(
      'Current note: ${current.name}\nFolder: ${current.folderName}\n'
      'The attached images show the COMPLETE current note in page order. Use the original images for equations.\n',
    );
    for (final voice in recordings) {
      if (voice.searchableText.isNotEmpty) {
        context.writeln('Voice note: ${voice.searchableText}');
      }
    }
    // A reference is sent only if its fingerprint still matches its source.
    int included = 0;
    for (final hit in NoteSearch.search(
      query,
      library,
      indexes,
      voiceTexts: voiceTexts,
    )) {
      if (hit.note.id == current.id || hit.score == 0) {
        continue;
      }
      if (included == 4) break;
      try {
        final snapshot = await source.read(hit.note);
        final recordings = await voiceNotes.load(hit.note.id);
        final voiceText = recordings
            .map((note) => note.searchableText)
            .where((text) => text.isNotEmpty)
            .join('\n');
        final validIndex =
            hit.index?.complete == true &&
            !hit.index!.needsReview &&
            snapshot.fingerprint == hit.index!.fingerprint;
        if (!validIndex && voiceText.isEmpty) continue;
        final text =
            '${validIndex ? hit.index!.context : ''}\nVoice notes: $voiceText';
        context.writeln(
          '\nLibrary reference: ${hit.note.name} (${hit.note.folderName}), note ${hit.note.id}\n'
          '${text.length > 16000 ? text.substring(0, 16000) : text}',
        );
        included++;
      } catch (_) {
        // Missing source files cannot be used as trustworthy library references.
      }
    }
    return NoteChatContext(text: context.toString(), pageImages: pages);
  }
}
