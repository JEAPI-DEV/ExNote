import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice/voice_note_repository.dart';
import 'folder_provider.dart';

final voiceNoteProvider = Provider<VoiceNoteRepository>((ref) {
  final repository = VoiceNoteRepository(
    directory: ref.read(storageServiceProvider).directory,
  );
  ref.onDispose(repository.dispose);
  return repository;
});
