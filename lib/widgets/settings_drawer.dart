import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../models/grid_type.dart';
import '../controllers/note_settings_controller.dart';
import '../utils/app_config.dart';

class SettingsDrawer extends ConsumerWidget {
  final NoteSettingsController settingsController;
  final VoidCallback? onExportBackup;
  final VoidCallback? onImportBackup;
  final VoidCallback? onAdjustNoteLook;

  const SettingsDrawer({
    super.key,
    required this.settingsController,
    this.onExportBackup,
    this.onImportBackup,
    this.onAdjustNoteLook,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return AnimatedBuilder(
      animation: settingsController,
      builder: (context, _) {
        final settings = settingsController.settings;

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                ),
                child: Text(
                  'Settings',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 24,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Theme',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        ref
                            .read(themeProvider.notifier)
                            .setThemeMode(newSelection.first);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(),

              SwitchListTile(
                title: const Text('Grid Enabled'),
                value: settings.gridEnabled,
                onChanged: (v) => settingsController.update(
                  (s) => s.copyWith(gridEnabled: v),
                ),
              ),
              if (settings.gridEnabled) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: DropdownButton<GridType>(
                    value: settings.gridType,
                    onChanged: (GridType? newValue) {
                      if (newValue != null) {
                        settingsController.update(
                          (s) => s.copyWith(gridType: newValue),
                        );
                      }
                    },
                    items: GridType.values.map((GridType type) {
                      return DropdownMenuItem<GridType>(
                        value: type,
                        child: Text(
                          type == GridType.grid
                              ? 'Grid (Math)'
                              : 'Writing Lines',
                        ),
                      );
                    }).toList(),
                  ),
                ),
                if (settings.gridType == GridType.grid)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Grid Spacing: ${settings.gridSpacing.toInt()}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: settings.gridSpacing,
                          min: 20.0,
                          max: 100.0,
                          divisions: 16,
                          label: settings.gridSpacing.round().toString(),
                          onChanged: (v) => settingsController.update(
                            (s) => s.copyWith(gridSpacing: v),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const Divider(),
              SwitchListTile(
                title: const Text('Shape Snapping'),
                subtitle: const Text(
                  'Hold at the end of a stroke to snap to shape',
                ),
                value: settings.shapeSnappingEnabled,
                onChanged: (v) => settingsController.update(
                  (s) => s.copyWith(shapeSnappingEnabled: v),
                ),
              ),
              const Divider(),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Adjust note look',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.tune),
                      title: const Text('Edit note look'),
                      subtitle: Text(
                        'Move toolbar, ${settings.toolbarOrientation.name} layout',
                      ),
                      onTap: onAdjustNoteLook,
                    ),
                  ],
                ),
              ),
              const Divider(),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: settingsController.tokenController,
                      decoration: const InputDecoration(
                        labelText: 'OpenRouter API Token',
                        border: OutlineInputBorder(),
                        hintText: 'sk-or-v1-...',
                      ),
                      obscureText: true,
                      onChanged: (v) => settingsController.update(
                        (s) => s.copyWith(openRouterToken: v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'AI Model',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: settings.aiModel,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: AppConfig.aiModels.map((model) {
                        return DropdownMenuItem(
                          value: model['id'],
                          child: Text(model['name']!),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          settingsController.update(
                            (s) => s.copyWith(aiModel: value),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tutor Mode'),
                      subtitle: const Text('AI will act as a helpful tutor'),
                      value: settings.tutorEnabled,
                      onChanged: (v) => settingsController.update(
                        (s) => s.copyWith(tutorEnabled: v),
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Submit Last Image Only'),
                      subtitle: const Text(
                        'AI will only receive the last captured image',
                      ),
                      value: settings.submitLastImageOnly,
                      onChanged: (v) => settingsController.update(
                        (s) => s.copyWith(submitLastImageOnly: v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.archive),
                      title: const Text('Backup Data'),
                      subtitle: const Text('Export all data to Zip'),
                      onTap: onExportBackup,
                    ),
                    ListTile(
                      leading: const Icon(Icons.unarchive),
                      title: const Text('Import Backup'),
                      subtitle: const Text('Import from .zip file'),
                      onTap: onImportBackup,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
