import 'package:flutter_test/flutter_test.dart';
import 'package:exnote/models/indexing/note_index.dart';
import 'package:exnote/services/indexing/note_library_source.dart';
import 'package:exnote/services/indexing/note_search.dart';

void main() {
  test('parses fenced model JSON and retains mathematical transcripts', () {
    final page = IndexedPage.fromModel(
      2,
      '```json\n{"title":"Integrals","text":"Integral of x²","summary":"Substitution","keywords":["integration"]}\n```',
    );
    expect(page.number, 2);
    expect(page.text, 'Integral of x²');
    final index = NoteIndex(
      noteId: 'a',
      fingerprint: 'revision',
      model: 'local',
      pageCount: 1,
      pages: [page],
      complete: true,
    );
    expect(
      NoteIndex.fromJson(index.toJson()).context,
      contains('Page 2: Integrals'),
    );
  });
  test('incomplete or invented annotation schemas are rejected', () {
    expect(
      () => IndexedPage.fromModel(
        1,
        '{"title":"Title","summary":"No transcript"}',
      ),
      throwsFormatException,
    );
    expect(() => IndexedPage.fromModel(1, 'Not JSON'), throwsFormatException);
  });
  test(
    'searches transcript and topic tags while keeping user titles searchable',
    () {
      const note = LibraryNote(
        id: 'a',
        folderId: 'folder',
        name: 'Lecture 4',
        folderName: 'Analysis',
      );
      const index = NoteIndex(
        noteId: 'a',
        fingerprint: 'revision',
        model: 'local',
        pageCount: 1,
        complete: true,
        pages: [
          IndexedPage(
            number: 1,
            title: 'Integrals',
            text: 'Substitution theorem',
            summary: '',
            keywords: ['integration'],
          ),
        ],
      );
      expect(
        NoteSearch.search('substitution', [note], {'a': index}).single.note.id,
        'a',
      );
      expect(
        NoteSearch.search('integration', [note], {'a': index}).single.note.id,
        'a',
      );
      expect(
        NoteSearch.search('Lecture 4', [note], {'a': index}).single.note.id,
        'a',
      );
      expect(NoteSearch.search('biology', [note], {'a': index}), isEmpty);
    },
  );
}
