import 'dart:convert';
import 'dart:isolate';
import 'package:path/path.dart' as p;

/// Rebases imported image paths without decoding or modifying stroke data.
Future<String> rebaseNoteImagePaths(
  String raw,
  Map<String, String> restoredPaths,
) => Isolate.run(() {
  if (raw.isEmpty || !raw.trimLeft().startsWith('{')) return raw;
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  final images = decoded['images'];
  if (images is! List) return raw;
  bool changed = false;
  for (final value in images) {
    final image = value as Map<String, dynamic>;
    final original = image['path'] as String;
    final restored =
        restoredPaths[original] ?? restoredPaths[p.basename(original)];
    if (restored == null || original == restored) continue;
    image['path'] = restored;
    changed = true;
  }
  return changed ? jsonEncode(decoded) : raw;
});
