import 'dart:async';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/voice_note.dart';
import '../services/voice/voice_note_repository.dart';
import '../providers/voice_note_provider.dart';
import '../services/voice/audio_transcription_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice/voice_recorder.dart';
import 'chat/dictation_button.dart';

class VoiceNoteSheet extends ConsumerStatefulWidget {
  final String noteId;
  final String apiKey;
  const VoiceNoteSheet({super.key, required this.noteId, this.apiKey = ''});
  @override
  ConsumerState<VoiceNoteSheet> createState() => _VoiceNoteSheetState();
}

class _VoiceNoteSheetState extends ConsumerState<VoiceNoteSheet>
    with WidgetsBindingObserver {
  late VoiceNoteRepository _repository;
  final _recorder = VoiceRecorder();
  final _player = AudioPlayer();
  final _text = TextEditingController();
  List<VoiceNote> _notes = [];
  bool _recording = false;
  bool _busy = true;
  bool _canSave = false;
  bool _autoTranscribe = false;
  String? _playing;
  VoiceNote? _unsavedRecording;
  String? _error;
  StreamSubscription<void>? _playback;

  @override
  void initState() {
    super.initState();
    _repository = ref.read(voiceNoteProvider);
    WidgetsBinding.instance.addObserver(this);
    _load();
    _playback = _player.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playing = null);
    });
  }

  Future<void> _load() async {
    try {
      final automatic =
          (await SharedPreferences.getInstance()).getBool(
            'transcribeNewRecordings',
          ) ??
          false;
      final notes = await _repository.load(widget.noteId);
      if (mounted) {
        setState(() {
          _notes = notes;
          _autoTranscribe = automatic;
          _canSave = true;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _record() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_recording || _unsavedRecording != null) {
        final note =
            _unsavedRecording ??
            await _recorder.stop(transcript: _text.text.trim());
        _unsavedRecording = note;
        _recording = false;
        // Commit the audio reference before clearing the draft.
        final notes = [..._notes, note];
        await _repository.save(widget.noteId, notes);
        _notes = notes;
        _text.clear();
        _unsavedRecording = null;
        if (_autoTranscribe && widget.apiKey.isNotEmpty) {
          await _transcribeAndSave(note);
        }
      } else {
        await _player.stop();
        _playing = null;
        await _recorder.start();
        _recording = true;
      }
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveText() async {
    if (_busy || _text.text.trim().isEmpty) return;
    setState(() => _busy = true);
    try {
      final note = VoiceNote(
        id: const Uuid().v4(),
        transcript: _text.text.trim(),
        createdAt: DateTime.now(),
      );
      final notes = [..._notes, note];
      await _repository.save(widget.noteId, notes);
      _notes = notes;
      _text.clear();
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _transcribeAndSave(VoiceNote note) async {
    final root = await getApplicationDocumentsDirectory();
    final transcript = await AudioTranscriptionService(
      apiKey: widget.apiKey,
    ).transcribe(File('${root.path}/${note.audioPath}'));
    final notes = [
      for (final item in _notes)
        item.id == note.id
            ? item.withTranscription(transcript.text, transcript.cost)
            : item,
    ];
    await _repository.save(widget.noteId, notes);
    _notes = notes;
  }

  Future<void> _transcribe(VoiceNote note) async {
    if (_busy || _recording) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _transcribeAndSave(note);
    } catch (error) {
      _error = '$error';
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setAutoTranscribe(bool value) async {
    setState(() => _autoTranscribe = value);
    try {
      await (await SharedPreferences.getInstance()).setBool(
        'transcribeNewRecordings',
        value,
      );
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  Future<void> _play(VoiceNote note) async {
    try {
      if (_playing == note.id) {
        await _player.stop();
        if (mounted) setState(() => _playing = null);
        return;
      }
      final root = await getApplicationDocumentsDirectory();
      final file = File('${root.path}/${note.audioPath}');
      if (!await file.exists()) throw StateError('Recording file is missing');
      await _player.play(DeviceFileSource(file.path));
      if (mounted) setState(() => _playing = note.id);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _recording && !_busy) _record();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _playback?.cancel();
    _player.dispose();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_recording && !_busy && _unsavedRecording == null,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Voice notes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'Dictate a searchable text note, or keep a longer audio recording. Saved text is available to the assistant.',
              ),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: Colors.red)),
              if (!_canSave && !_busy)
                TextButton(
                  onPressed: _load,
                  child: const Text('Reload voice notes'),
                ),
              TextField(
                controller: _text,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Your spoken note or recording description…',
                  suffixIcon: DictationButton(
                    controller: _text,
                    enabled: !_recording && !_busy,
                  ),
                ),
              ),
              Wrap(
                spacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _busy || !_canSave ? null : _record,
                    icon: Icon(
                      _recording ? Icons.stop : Icons.fiber_manual_record,
                    ),
                    label: Text(
                      _recording
                          ? 'Stop and save recording'
                          : _unsavedRecording != null
                          ? 'Retry saving recording'
                          : 'Record audio',
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _busy ||
                            !_canSave ||
                            _recording ||
                            _unsavedRecording != null
                        ? null
                        : _saveText,
                    child: const Text('Save text'),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: const Text('Transcribe new recordings with AI'),
                subtitle: const Text(
                  'Uploads audio to OpenRouter and uses credits',
                ),
                value: _autoTranscribe,
                onChanged: widget.apiKey.isEmpty || _busy || _recording
                    ? null
                    : _setAutoTranscribe,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _notes.length,
                  itemBuilder: (context, index) {
                    final note = _notes[index];
                    return ListTile(
                      title: Text(
                        note.searchableText.isEmpty
                            ? 'Audio recording'
                            : note.searchableText,
                      ),
                      subtitle: Text(
                        '${note.createdAt.toLocal().toString().split('.').first}${note.transcriptionCost == null ? '' : ' · \$${note.transcriptionCost!.toStringAsFixed(4)}'}',
                      ),
                      trailing: note.audioPath == null
                          ? null
                          : IconButton(
                              tooltip:
                                  'Transcribe audio with OpenRouter (uses credits)',
                              onPressed:
                                  _busy || _recording || widget.apiKey.isEmpty
                                  ? null
                                  : () => _transcribe(note),
                              icon: const Icon(Icons.closed_caption_outlined),
                            ),
                      leading: note.audioPath == null
                          ? const Icon(Icons.text_snippet_outlined)
                          : IconButton(
                              onPressed: _recording ? null : () => _play(note),
                              icon: Icon(
                                _playing == note.id
                                    ? Icons.stop
                                    : Icons.play_arrow,
                              ),
                            ),
                    );
                  },
                ),
              ),
              TextButton(
                onPressed: _recording || _busy || _unsavedRecording != null
                    ? null
                    : () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
