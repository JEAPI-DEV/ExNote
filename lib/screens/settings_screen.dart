import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/note_settings_provider.dart';
import '../services/backup_service.dart';
import '../widgets/settings_content.dart';

class SettingsScreen extends ConsumerWidget {
  final VoidCallback? onAdjustNoteLook;
  final Future<void> Function()? onExportBackup;

  const SettingsScreen({super.key, this.onAdjustNoteLook, this.onExportBackup});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(noteSettingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: controller.loadError != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(controller.loadError!),
                  TextButton(
                    onPressed: controller.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : !controller.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : SettingsContent(
              settingsController: controller,
              onAdjustNoteLook: onAdjustNoteLook == null
                  ? null
                  : () {
                      Navigator.pop(context);
                      onAdjustNoteLook!();
                    },
              onExportBackup: () {
                if (onExportBackup != null) {
                  onExportBackup!();
                } else {
                  BackupService.exportBackup(context, ref);
                }
              },
              onImportBackup: () =>
                  BackupService.importFromBackup(context, ref),
            ),
    );
  }
}
