import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/indexing/note_index.dart';
import '../providers/folder_provider.dart';
import '../providers/note_index_provider.dart';
import '../services/indexing/note_library_source.dart';
import '../services/indexing/note_search.dart';
import 'note_screen.dart';
import '../widgets/indexing_settings_panel.dart';

class NoteLibraryScreen extends ConsumerStatefulWidget {
  const NoteLibraryScreen({super.key});
  @override
  ConsumerState<NoteLibraryScreen> createState() => _NoteLibraryScreenState();
}

class _NoteLibraryScreenState extends ConsumerState<NoteLibraryScreen> {
  final _query = TextEditingController();
  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _getModel() async {
    try {
      final launched = await launchUrl(
        Uri.parse(
          'https://huggingface.co/google/gemma-3n-E2B-it-litert-preview',
        ),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw StateError('Could not open the model download page');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _install() async {
    try {
      // Android cannot filter the binary .task extension by MIME type.
      // The inference service validates the selected model before copying it.
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      final path = result?.files.single.path;
      if (path == null || !mounted) return;
      final controller = ref.read(noteIndexProvider);
      await controller.install(path);
      if (!mounted || !controller.hasModel || controller.error != null) return;
      await controller.scan(LibraryNote.fromFolders(ref.read(folderProvider)));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not select a model: $error')),
        );
      }
    }
  }

  void _showAnnotation(NoteIndex index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(index.title, style: Theme.of(context).textTheme.titleLarge),
              Text(
                index.needsReview
                    ? 'Some sections may be missing or unclear. Review against the original note.'
                    : 'Model transcription; verify formulas against the original note.',
              ),
              for (final page in index.pages) ...[
                const Divider(height: 32),
                Text(
                  'Page ${page.number} · ${page.title}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(page.keywords.join(' · ')),
                const SizedBox(height: 8),
                SelectableText(page.text),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(noteIndexProvider);
    final library = LibraryNote.fromFolders(ref.watch(folderProvider));
    final hits = NoteSearch.search(
      _query.text,
      library,
      controller.entries,
      voiceTexts: controller.voiceTexts,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Search your notes')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _query,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search titles, topics, equations or transcripts',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                IndexingSettingsPanel(controller: controller),
                if (!controller.isCloud && !controller.hasLocalModel) ...[
                  const Text(
                    'Import a vision-enabled Gemma3n E2B .task model to scan handwriting locally. Model weights are kept on your device; the scan makes no cloud requests.',
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed:
                        controller.isInstalling ||
                            controller.isRunning ||
                            (!Platform.isAndroid && !Platform.isIOS)
                        ? null
                        : _install,
                    icon: const Icon(Icons.install_mobile),
                    label: Text(
                      controller.isInstalling
                          ? 'Installing model…'
                          : 'Import local vision model',
                    ),
                  ),
                  TextButton(
                    onPressed: _getModel,
                    child: const Text('Get Gemma3n E2B model'),
                  ),
                ] else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: controller.isRunning || !controller.canScan
                            ? null
                            : () => controller.scan(library),
                        icon: const Icon(Icons.document_scanner_outlined),
                        label: Text(
                          controller.canScan
                              ? 'Scan / resume library'
                              : 'Close the note editor to scan',
                        ),
                      ),
                      if (controller.isRunning)
                        TextButton(
                          onPressed: controller.pause,
                          child: const Text('Pause scan'),
                        ),
                      if (!controller.isCloud)
                        TextButton(
                          onPressed:
                              controller.isRunning || controller.isInstalling
                              ? null
                              : _install,
                          child: const Text('Change local model'),
                        ),
                      TextButton(
                        onPressed: controller.isRunning || !controller.canScan
                            ? null
                            : () => controller.scan(library, force: true),
                        child: const Text('Rebuild annotations'),
                      ),
                    ],
                  ),
                if (controller.hasModel)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Index new and changed notes automatically',
                    ),
                    subtitle: const Text(
                      'Runs while browsing; pauses while you write',
                    ),
                    value: controller.automatic,
                    onChanged: controller.setAutomatic,
                  ),
                if (controller.isRunning) ...[
                  LinearProgressIndicator(
                    value: controller.total == 0
                        ? null
                        : controller.completed / controller.total,
                  ),
                  Text(
                    '${controller.completed}/${controller.total} notes · ${controller.currentNote ?? ''} · page ${controller.currentPage}',
                  ),
                ],
                if (controller.isRunning && controller.analysisProgress != null)
                  Text(
                    '${controller.analysisProgress!.phase}${controller.analysisProgress!.sections == 0 ? '' : ' ${controller.analysisProgress!.section}/${controller.analysisProgress!.sections}'}'
                    '${controller.analysisProgress!.characters == 0 ? '' : ' · ${controller.analysisProgress!.characters} characters read'}',
                  ),
                if (controller.error != null)
                  Text(
                    controller.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                if (controller.failures.isNotEmpty)
                  Text(
                    '${controller.failures.length} notes need another scan. Their original files are preserved.',
                    style: const TextStyle(color: Colors.orange),
                  ),
              ],
            ),
          ),
          Expanded(
            child: hits.isEmpty
                ? const Center(
                    child: Text(
                      'No matching notes. Scan older notes to search their contents.',
                    ),
                  )
                : ListView.builder(
                    itemCount: hits.length,
                    itemBuilder: (context, position) {
                      final hit = hits[position];
                      return ListTile(
                        title: Text(hit.index?.title ?? hit.note.name),
                        subtitle: Text(
                          '${hit.note.folderName} · ${hit.note.name}\n'
                          '${controller.failures[hit.note.id] ?? (controller.staleNoteIds.contains(hit.note.id) ? 'Changed; awaiting a fresh scan' : null) ?? (hit.index == null
                                  ? 'Not indexed yet'
                                  : hit.index!.complete
                                  ? hit.index!.needsReview
                                        ? 'Transcript coverage needs review'
                                        : '${hit.index!.pageCount} processed pages'
                                  : 'Scan paused; partial index')}',
                        ),
                        isThreeLine: true,
                        leading: const Icon(Icons.description_outlined),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Note indexing actions',
                          onSelected: (action) {
                            if (action == 'text' && hit.index != null) {
                              _showAnnotation(hit.index!);
                            }
                            if (action == 'scan') {
                              controller.scan([hit.note], force: true);
                            }
                          },
                          itemBuilder: (_) => [
                            if (hit.index != null)
                              const PopupMenuItem(
                                value: 'text',
                                child: Text('Read extracted text'),
                              ),
                            PopupMenuItem(
                              value: 'scan',
                              enabled:
                                  controller.hasModel &&
                                  !controller.isRunning &&
                                  controller.canScan,
                              child: const Text('Rescan this note'),
                            ),
                          ],
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => NoteScreen(
                              folderId: hit.note.folderId,
                              noteId: hit.note.id,
                              exerciseListId: hit.note.exerciseListId,
                              selectionId: hit.note.selectionId,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
