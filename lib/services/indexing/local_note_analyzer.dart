import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/indexing/note_index.dart';
import '../notes/note_page_renderer.dart';
import 'note_ocr_tiler.dart';
import '../../models/indexing/indexed_region.dart';
import '../../models/indexing/note_analysis_progress.dart';

abstract interface class NoteAnalyzer {
  String get modelId;
  Future<IndexedPage> analyze(
    NotePage page, {
    List<IndexedRegion> previousRegions = const [],
    Future<void> Function(List<IndexedRegion>)? checkpoint,
  });
  Future<void> cancel();
  Future<void> close();
}

/// Owns native inference and its memory. A small vision model is required:
/// text-only models cannot read the handwritten canvas.
class LocalNoteAnalyzer implements NoteAnalyzer {
  static const modelPreference = 'localVisionModelPath';
  InferenceModel? _model;
  final _progress = StreamController<NoteAnalysisProgress>.broadcast();
  Stream<NoteAnalysisProgress> get progress => _progress.stream;
  final _tiler = NoteOcrTiler();
  InferenceModelSession? _activeSession;
  bool _cancelled = false;
  String? _path;
  bool get isInstalled => _path != null;
  String _identity = 'No local model';
  @override
  String get modelId => _identity;

  Future<void> _setIdentity(String path) async {
    final stat = await File(path).stat();
    _path = path;
    _identity =
        '${path.split('/').last}:${stat.size}:${stat.modified.microsecondsSinceEpoch}';
  }

  Future<void> initialize() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    await FlutterGemma.initialize();
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(modelPreference);
    if (path != null && await File(path).exists()) {
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromFile(path).install();
      await _setIdentity(path);
    }
  }

  Future<void> install(String sourcePath) async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError(
        'Local handwriting analysis currently supports Android and iOS.',
      );
    }
    if (!sourcePath.endsWith('.task')) {
      throw const FormatException(
        'Choose a vision-enabled Gemma3n .task model',
      );
    }
    await close();
    await FlutterGemma.initialize();
    final root = await getApplicationSupportDirectory();
    final models = await Directory(
      '${root.path}/vision_models',
    ).create(recursive: true);
    final name = sourcePath.split('/').last;
    final destination = File('${models.path}/$name');
    if (sourcePath != destination.path) {
      final partial = await File(
        sourcePath,
      ).copy('${destination.path}.partial');
      await partial.rename(destination.path);
    }
    await FlutterGemma.installModel(
      modelType: ModelType.gemmaIt,
    ).fromFile(destination.path).install();
    await _setIdentity(destination.path);
    await (await SharedPreferences.getInstance()).setString(
      modelPreference,
      _path!,
    );
  }

  @override
  Future<IndexedPage> analyze(
    NotePage page, {
    List<IndexedRegion> previousRegions = const [],
    Future<void> Function(List<IndexedRegion>)? checkpoint,
  }) async {
    if (!isInstalled) throw StateError('Import a local vision model first');
    _cancelled = false;
    _progress.add(const NoteAnalysisProgress('Preparing readable sections'));
    final tiles = await _tiler.split(page.png);
    if (_cancelled) throw StateError('Analysis paused');
    if (tiles.isEmpty) {
      return IndexedPage(
        number: page.number,
        title: 'Blank page',
        text: '',
        summary: '',
        keywords: const [],
      );
    }
    _progress.add(const NoteAnalysisProgress('Loading local model'));
    _model ??= await FlutterGemma.getActiveModel(
      maxTokens: 4096,
      supportImage: true,
      maxNumImages: 1,
      preferredBackend: PreferredBackend.gpu,
    );
    if (_cancelled) throw StateError('Analysis paused');
    final regions = List<IndexedRegion>.of(previousRegions);
    for (final tile in tiles) {
      if (regions.any((region) => region.number == tile.number)) continue;
      _progress.add(
        NoteAnalysisProgress(
          'Reading section',
          section: tile.number,
          sections: tiles.length,
        ),
      );
      final message = Message.withImage(
        isUser: true,
        imageBytes: tile.png,
        text:
            'Transcribe EVERY visible handwritten and printed line in this cropped university note, from top to bottom. '
            'Copy mathematical symbols, coefficients, superscripts, fractions and side annotations exactly. '
            'Preserve the original language and line breaks. Use LaTeX for legible equations. '
            'Write [illegible] for unclear characters. Do not solve, summarize, correct, or add explanations. '
            'Return only the transcription, without JSON or a heading.',
      );
      final text = await _generate(
        message,
        vision: true,
        section: tile.number,
        sections: tiles.length,
      );
      regions.add(
        IndexedRegion.fromTranscript(
          number: tile.number,
          text: text,
          bounds: tile.bounds,
          expectedLines: tile.expectedLines,
        ),
      );
      if (checkpoint != null) await checkpoint(List.unmodifiable(regions));
    }
    final text = regions
        .map((region) => region.text)
        .where((text) => text.trim().isNotEmpty)
        .join('\n\n');
    _progress.add(const NoteAnalysisProgress('Adding title and search topics'));
    final metadata = await _generate(
      Message.text(
        isUser: true,
        text:
            'Create metadata for this already transcribed university note. Do not rewrite its contents. '
            'Return only JSON with title (specific topic, short), summary (one factual sentence), keywords (array). '
            'Use plain text in these fields, preserving the source language. Transcript:\n$text',
      ),
      vision: false,
    );
    final start = metadata.indexOf('{'), end = metadata.lastIndexOf('}');
    if (start < 0 || end < start) {
      throw const FormatException('Local model did not return note metadata');
    }
    final json =
        jsonDecode(metadata.substring(start, end + 1)) as Map<String, dynamic>;
    return IndexedPage.fromModel(
      page.number,
      jsonEncode({
        ...json,
        'text': text,
        'regions': regions.map((region) => region.toJson()).toList(),
      }),
    );
  }

  Future<String> _generate(
    Message message, {
    required bool vision,
    int section = 0,
    int sections = 0,
  }) async {
    if (_cancelled) throw StateError('Analysis paused');
    final session = await _model!.createSession(
      temperature: 0.1,
      topK: 1,
      enableVisionModality: vision,
    );
    _activeSession = session;
    final timer = Stopwatch()..start();
    try {
      if (_cancelled) throw StateError('Analysis paused');
      await session.addQueryChunk(message);
      final response = StringBuffer();
      int lastUpdate = -1000;
      await for (final chunk in session.getResponseAsync()) {
        response.write(chunk);
        if (timer.elapsedMilliseconds - lastUpdate >= 500) {
          _progress.add(
            NoteAnalysisProgress(
              vision ? 'Reading section' : 'Adding title and search topics',
              section: section,
              sections: sections,
              characters: response.length,
            ),
          );
          lastUpdate = timer.elapsedMilliseconds;
        }
      }
      if (_cancelled) throw StateError('Analysis paused');
      return response.toString().trim().replaceAll(
        RegExp(r'^```(?:latex|text)?\s*|\s*```$'),
        '',
      );
    } finally {
      _activeSession = null;
      await session.close();
    }
  }

  @override
  Future<void> cancel() async {
    _cancelled = true;
    await _activeSession?.stopGeneration();
  }

  @override
  Future<void> close() async {
    final model = _model;
    _model = null;
    if (model != null) await model.close();
  }
}
