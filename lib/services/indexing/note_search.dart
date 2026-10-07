import '../../models/indexing/note_index.dart';
import 'note_library_source.dart';

class NoteSearchHit {
  final LibraryNote note;
  final NoteIndex? index;
  final int score;
  const NoteSearchHit(this.note, this.index, this.score);
}

class NoteSearch {
  static List<NoteSearchHit> search(
    String query,
    List<LibraryNote> notes,
    Map<String, NoteIndex> entries, {
    Map<String, String> voiceTexts = const {},
  }) {
    final terms = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toSet();
    final hits = <NoteSearchHit>[];
    for (final note in notes) {
      final index = entries[note.id];
      final title = '${note.name} ${note.folderName} ${index?.title ?? ''}'
          .toLowerCase();
      final content =
          '${index?.searchableText ?? ''} ${voiceTexts[note.id] ?? ''}'
              .toLowerCase();
      int score = 0;
      for (final term in terms) {
        if (title.contains(term)) score += 5;
        if (content.contains(term)) score++;
      }
      if (score > 0 || terms.isEmpty) {
        hits.add(NoteSearchHit(note, index, score));
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits;
  }
}
