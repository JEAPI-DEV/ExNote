import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/indexing/note_index.dart';
import '../services/indexing/local_note_analyzer.dart';
import '../services/indexing/note_index_repository.dart';
import '../services/indexing/note_library_source.dart';
import '../services/notes/note_page_renderer.dart';
import '../services/voice/voice_note_repository.dart';
import '../models/indexing/note_analysis_progress.dart';
import '../models/indexing/indexed_region.dart';
import '../models/indexing/indexing_settings.dart';
import '../services/indexing/openrouter_note_analyzer.dart';
import '../services/indexing/scan_state_repository.dart';
import '../services/indexing/scan_request_retry.dart';
import '../models/indexing/scan_run_state.dart';

/// Coordinates resumable scans; storage, rendering and inference have separate owners.
class LibraryIndexController extends ChangeNotifier
    with WidgetsBindingObserver {
  final NoteIndexRepository repository;
  final ScanStateRepository? scanState;
  ScanRunStatus runStatus = ScanRunStatus.idle;
  String? statusReason;
  List<String> _pendingIds = [];
  bool _resumeRequested = false;
  bool _forceScan = false;
  String? _checkpointNoteId;
  Duration _resumeDelay = const Duration(milliseconds: 500);
  final NoteLibrarySource source;
  final NoteAnalyzer analyzer;
  final OpenRouterNoteAnalyzer? cloudAnalyzer;
  IndexingSettings settings = const IndexingSettings();
  NoteAnalyzer get activeAnalyzer =>
      settings.backend == IndexingBackend.openRouter && cloudAnalyzer != null
      ? cloudAnalyzer!
      : analyzer;
  bool get isCloud => settings.backend == IndexingBackend.openRouter;
  double get scanCost => cloudAnalyzer?.spent ?? 0;
  final NotePageRenderer renderer;
  final VoiceNoteRepository? voiceNotes;
  final Map<String, String> voiceTexts = {};
  final Map<String, NoteIndex> entries = {};
  final Map<String, String> failures = {};
  final Set<String> staleNoteIds = {};
  bool isRunning = false;
  bool isReady = false;
  bool isInstalling = false;
  bool isPaused = false;
  bool _disposed = false;
  int _editors = 0;
  bool _foreground = true;
  int completed = 0;
  int total = 0;
  int currentPage = 0;
  String? currentNote;
  NoteAnalysisProgress? analysisProgress;
  StreamSubscription<NoteAnalysisProgress>? _analysisSubscription;
  StreamSubscription<NoteAnalysisProgress>? _cloudSubscription;
  String? error;
  Future<void>? _initialization;
  Timer? _scheduled;
  List<LibraryNote> _library = [];
  bool automatic = false;
  bool _pausedByUser = false;

  LibraryIndexController({
    required this.repository,
    this.scanState,
    required this.source,
    required this.analyzer,
    required this.renderer,
    this.voiceNotes,
    this.cloudAnalyzer,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _cloudSubscription = cloudAnalyzer?.progress.listen((progress) {
      analysisProgress = progress;
      _notify();
    });
    if (analyzer is LocalNoteAnalyzer) {
      _analysisSubscription = (analyzer as LocalNoteAnalyzer).progress.listen((
        progress,
      ) {
        analysisProgress = progress;
        _notify();
      });
    }
  }

  bool get hasLocalModel =>
      analyzer is LocalNoteAnalyzer &&
      (analyzer as LocalNoteAnalyzer).isInstalled;
  bool get hasModel => isCloud ? cloudAnalyzer != null : hasLocalModel;
  bool get canScan =>
      !_disposed && _foreground && (isCloud || _editors == 0) && !isInstalling;

  Future<void> initialize() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    try {
      final loaded = await repository.load();
      entries.addAll(loaded.entries);
      if (loaded.errors.isNotEmpty) {
        error =
            '${loaded.errors.length} unreadable annotations can be rebuilt by scanning again.';
      }
      if (voiceNotes != null) await _loadVoices();
      if (analyzer is LocalNoteAnalyzer) {
        await (analyzer as LocalNoteAnalyzer).initialize();
      }
      final prefs = await SharedPreferences.getInstance();
      settings = IndexingSettings.fromPrefs(prefs);
      cloudAnalyzer?.model = settings.model;
      automatic = prefs.getBool('automaticNoteIndex') ?? false;
      final savedRun = await scanState?.load();
      if (savedRun != null) {
        failures.addAll(savedRun.failures);
        completed = savedRun.processed;
        total = savedRun.total;
        _pendingIds = List.of(savedRun.pendingIds);
        _forceScan = savedRun.force;
        _checkpointNoteId = savedRun.checkpointNoteId;
        _resumeRequested =
            _pendingIds.isNotEmpty &&
            (savedRun.resumeAutomatically ||
                savedRun.status == ScanRunStatus.running);
        _pausedByUser = _pendingIds.isNotEmpty && !_resumeRequested;
        runStatus = savedRun.status == ScanRunStatus.running
            ? ScanRunStatus.paused
            : savedRun.status;
        statusReason = savedRun.status == ScanRunStatus.running
            ? 'Interrupted scan; resuming saved progress'
            : savedRun.reason;
      }
      isReady = true;
      _schedule();
    } catch (exception) {
      error = 'Could not open note index: $exception';
    }
    _notify();
  }

  Future<void> configure(IndexingSettings value) async {
    if (isRunning || isInstalling) return;
    settings = value;
    cloudAnalyzer?.model = value.model;
    // Choosing a paid provider does not start an unrequested library upload.
    automatic = false;
    _resumeRequested = false;
    _pendingIds.clear();
    runStatus = ScanRunStatus.idle;
    statusReason = null;
    _pausedByUser = true;
    await settings.save();
    await (await SharedPreferences.getInstance()).setBool(
      'automaticNoteIndex',
      false,
    );
    _scheduled?.cancel();
    await _persistRun();
    _notify();
  }

  Future<void> install(String path) async {
    await initialize();
    if (isRunning || isInstalling) return;
    isInstalling = true;
    error = null;
    _notify();
    try {
      await (analyzer as LocalNoteAnalyzer).install(path);
      await setAutomatic(true);
    } catch (exception) {
      error = 'Model installation failed: $exception';
    } finally {
      isInstalling = false;
      _notify();
    }
  }

  Future<void> _loadVoices() async {
    final snapshot = await voiceNotes!.loadTexts();
    voiceTexts.addAll(snapshot.texts);
    for (final entry in snapshot.errors.entries) {
      failures[entry.key] = 'Could not read voice notes: ${entry.value}';
    }
    _notify();
  }

  Future<void> refreshVoice(String noteId) async {
    if (voiceNotes == null) return;
    try {
      final notes = await voiceNotes!.load(noteId);
      voiceTexts[noteId] = notes.map((note) => note.searchableText).join('\n');
    } catch (exception) {
      error = 'Could not read voice notes: $exception';
    }
    _notify();
  }

  void invalidate(String noteId) {
    staleNoteIds.add(noteId);
    _schedule();
    _notify();
  }

  void setLibrary(List<LibraryNote> library) {
    _library = library;
    if (isReady && voiceNotes != null) {
      _loadVoices().catchError((Object exception) {
        error = 'Could not read voice notes: $exception';
        _notify();
      });
    }
    _schedule();
  }

  Future<void> setAutomatic(bool value) async {
    automatic = value;
    if (!value) pause(user: true, reason: 'Automatic indexing turned off');
    await (await SharedPreferences.getInstance()).setBool(
      'automaticNoteIndex',
      value,
    );
    if (value) _pausedByUser = false;
    _schedule();
    _notify();
  }

  void _schedule() {
    _scheduled?.cancel();
    if (!isReady || !hasModel || !canScan || isRunning) return;
    if (_resumeRequested && _pendingIds.isNotEmpty && _library.isNotEmpty) {
      _scheduled = Timer(_resumeDelay, () => _resume());
      return;
    }
    if (!automatic || _pausedByUser) return;
    _scheduled = Timer(const Duration(seconds: 8), () => scan(_library));
  }

  Future<void> _persistRun() async {
    if (scanState == null) return;
    try {
      await scanState!.save(
        ScanRunState(
          status: runStatus,
          reason: statusReason,
          processed: completed,
          total: total,
          pendingIds: List.of(_pendingIds),
          failures: Map.of(failures),
          resumeAutomatically: _resumeRequested,
          force: _forceScan,
          checkpointNoteId: _checkpointNoteId,
        ),
      );
    } catch (exception) {
      error ??= 'Could not save scan progress: $exception';
    }
  }

  Future<void> _resume() async {
    final byId = {for (final note in _library) note.id: note};
    final pending = [
      for (final id in _pendingIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (pending.isEmpty) {
      _pendingIds.clear();
      _resumeRequested = false;
      runStatus = ScanRunStatus.completed;
      await _persistRun();
      _notify();
      return;
    }
    await _runScan(pending, force: _forceScan, continuation: true);
  }

  Future<void> resumeOrScan(List<LibraryNote> library) async {
    _library = library;
    if (_pendingIds.isNotEmpty &&
        (runStatus == ScanRunStatus.paused ||
            runStatus == ScanRunStatus.stopped ||
            runStatus == ScanRunStatus.waiting)) {
      await _resume();
    } else {
      await scan(library);
    }
  }

  Future<void> retryFailed(List<LibraryNote> library) => scan([
    for (final note in library)
      if (failures.containsKey(note.id)) note,
  ]);

  void enterEditor() {
    _editors++;
    if (!isCloud) {
      isPaused = true;
      _scheduled?.cancel();
      _cancelInference();
      if (isRunning) {
        runStatus = ScanRunStatus.paused;
        statusReason = 'Local scan paused while the note editor is open';
        _resumeRequested = true;
        unawaited(_persistRun());
      }
    }
  }

  void leaveEditor() {
    if (_editors > 0) _editors--;
    _schedule();
  }

  void pause({bool user = true, String? reason}) {
    isPaused = true;
    if (user) _pausedByUser = true;
    _resumeRequested = !user && (isRunning || _pendingIds.isNotEmpty);
    if (isRunning || _pendingIds.isNotEmpty) {
      runStatus = ScanRunStatus.paused;
      statusReason =
          reason ??
          (user ? 'Paused by you' : 'Paused; resumes when the app is active');
    }
    _scheduled?.cancel();
    _cancelInference();
    unawaited(_persistRun());
    _notify();
  }

  void _cancelInference() {
    if (!isRunning) return;
    activeAnalyzer.cancel().catchError((Object exception) {
      error = 'Could not interrupt analysis: $exception';
      _notify();
    });
  }

  Future<void> scan(List<LibraryNote> notes, {bool force = false}) =>
      _runScan(notes, force: force);

  Future<void> _runScan(
    List<LibraryNote> notes, {
    required bool force,
    bool continuation = false,
  }) async {
    await initialize();
    if (!canScan || isRunning) return;
    isRunning = true;
    if (isCloud) cloudAnalyzer?.beginScan();
    isPaused = false;
    _pausedByUser = false;
    error = null;
    _resumeRequested = false;
    _scheduled?.cancel();
    _resumeDelay = const Duration(milliseconds: 500);
    runStatus = ScanRunStatus.running;
    statusReason = null;
    final checkpointId = continuation ? _checkpointNoteId : null;
    _forceScan = force;
    _pendingIds = notes.map((note) => note.id).toList();
    if (!continuation) {
      completed = 0;
      total = notes.length;
    }
    await _persistRun();
    _notify();
    try {
      for (final note in notes) {
        if (isPaused || !canScan) break;
        currentNote = note.name;
        _checkpointNoteId = note.id;
        currentPage = 0;
        await _persistRun();
        _notify();
        try {
          await _index(note, force: force && note.id != checkpointId);
          if (!isPaused) failures.remove(note.id);
        } catch (exception) {
          if (exception is ScanStoppedException && !isPaused) {
            error = '$exception';
            isPaused = true;
            _pausedByUser = true;
            runStatus = ScanRunStatus.stopped;
            statusReason = '$exception';
            _resumeRequested = false;
          } else if (exception is TransientScanException && !isPaused) {
            isPaused = true;
            runStatus = ScanRunStatus.waiting;
            statusReason =
                'Connection unavailable. Retrying this page shortly; saved pages are preserved.';
            _resumeRequested = true;
            _pausedByUser = false;
            _resumeDelay = const Duration(seconds: 30);
          } else if (!isPaused && canScan) {
            failures[note.id] = '$exception';
          }
        }
        if (isPaused || !canScan) break;
        _pendingIds.remove(note.id);
        completed++;
        await _persistRun();
        _notify();
      }
    } catch (exception) {
      error = 'Scan failed: $exception';
      runStatus = ScanRunStatus.stopped;
      statusReason = error;
    } finally {
      try {
        await activeAnalyzer.close();
      } catch (exception) {
        error = 'Could not release local model: $exception';
      }
      isRunning = false;
      if (!isPaused && runStatus == ScanRunStatus.running) {
        runStatus = ScanRunStatus.completed;
        statusReason = failures.isEmpty
            ? 'Scan finished'
            : 'Scan finished; ${failures.length} notes need attention';
        _pendingIds.clear();
      }
      await _persistRun();
      currentNote = null;
      analysisProgress = null;
      if (isPaused && canScan) _schedule();
      _notify();
    }
  }

  Future<void> _index(LibraryNote note, {required bool force}) async {
    final snapshot = await source.read(note);
    final old = entries[note.id];
    final reusable =
        !force &&
        old?.fingerprint == snapshot.fingerprint &&
        old?.model == activeAnalyzer.modelId;
    if (reusable && old!.complete) {
      staleNoteIds.remove(note.id);
      return;
    }
    final pages = reusable ? [...old!.pages] : <IndexedPage>[];
    // Persist page count from rendering, including a PDF exercise background.
    var count = 0;
    await for (final page in renderer.render(
      snapshot.document,
      backgroundPath: note.backgroundPath,
    )) {
      count = page.number;
      if (isPaused || !canScan) return;
      final previous = pages
          .where((item) => item.number == page.number)
          .firstOrNull;
      if (previous?.isFinished == true) continue;
      currentPage = page.number;
      _notify();
      Future<void> saveRegions(List<IndexedRegion> regions) async {
        final partial = IndexedPage(
          number: page.number,
          title: note.name,
          text: regions.map((region) => region.text).join('\n\n'),
          summary: '',
          keywords: const [],
          regions: regions,
          isFinished: false,
        );
        pages.removeWhere((item) => item.number == page.number);
        pages.add(partial);
        final saved = NoteIndex(
          noteId: note.id,
          fingerprint: snapshot.fingerprint,
          model: activeAnalyzer.modelId,
          pageCount: count,
          pages: List.unmodifiable(pages),
          complete: false,
        );
        await repository.save(saved);
        entries[note.id] = saved;
        _notify();
      }

      final analyzed = await activeAnalyzer.analyze(
        page,
        previousRegions: previous?.regions ?? const [],
        checkpoint: saveRegions,
      );
      pages.removeWhere((item) => item.number == page.number);
      pages.add(analyzed);
      final checkpoint = NoteIndex(
        noteId: note.id,
        fingerprint: snapshot.fingerprint,
        model: activeAnalyzer.modelId,
        pageCount: count,
        pages: List.unmodifiable(pages),
        complete: false,
      );
      await repository.save(checkpoint);
      entries[note.id] = checkpoint;
      _notify();
    }
    // A scan must never declare old handwriting current if a save happened mid-scan.
    if ((await source.read(note)).fingerprint != snapshot.fingerprint) {
      throw StateError(
        'Note changed during analysis; resume to index the latest version',
      );
    }
    final entry = NoteIndex(
      noteId: note.id,
      fingerprint: snapshot.fingerprint,
      model: activeAnalyzer.modelId,
      pageCount: count,
      pages: List.unmodifiable(pages),
      complete: true,
    );
    await repository.save(entry);
    entries[note.id] = entry;
    staleNoteIds.remove(note.id);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground) {
      _schedule();
    } else {
      pause(
        user: false,
        reason: 'Paused while the app is backgrounded; resumes when you return',
      );
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scheduled?.cancel();
    _analysisSubscription?.cancel();
    _cloudSubscription?.cancel();
    _disposed = true;
    isPaused = true;
    _cancelInference();
    super.dispose();
  }
}
