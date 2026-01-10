import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../models/grid_type.dart';
import '../utils/app_config.dart';

class SettingsDrawer extends ConsumerWidget {
  final bool gridEnabled;
  final GridType gridType;
  final String aiModel;
  final bool tutorEnabled;
  final bool submitLastImageOnly;
  final bool waifuFetcherEnabled;
  final double waifuImageWidth;
  final String waifuTag;
  final bool waifuNsfw;
  final double gridSpacing;
  final TextEditingController tokenController;
  final ValueChanged<bool> onGridEnabledChanged;
  final ValueChanged<GridType> onGridTypeChanged;
  final ValueChanged<double> onGridSpacingChanged;
  final ValueChanged<String> onTokenChanged;
  final ValueChanged<String> onAiModelChanged;
  final ValueChanged<bool> onTutorEnabledChanged;
  final ValueChanged<bool> onSubmitLastImageOnlyChanged;
  final ValueChanged<bool> onWaifuFetcherEnabledChanged;
  final ValueChanged<double> onWaifuImageWidthChanged;
  final ValueChanged<String> onWaifuTagChanged;
  final ValueChanged<bool> onWaifuNsfwChanged;
  final VoidCallback? onExportBackup;

  const SettingsDrawer({
    super.key,
    required this.gridEnabled,
    required this.gridType,
    required this.gridSpacing,
    required this.aiModel,
    required this.tutorEnabled,
    required this.submitLastImageOnly,
    required this.waifuFetcherEnabled,
    required this.waifuImageWidth,
    required this.waifuTag,
    required this.waifuNsfw,
    required this.tokenController,
    required this.onGridEnabledChanged,
    required this.onGridTypeChanged,
    required this.onGridSpacingChanged,
    required this.onTokenChanged,
    required this.onAiModelChanged,
    required this.onTutorEnabledChanged,
    required this.onSubmitLastImageOnlyChanged,
    required this.onWaifuFetcherEnabledChanged,
    required this.onWaifuImageWidthChanged,
    required this.onWaifuTagChanged,
    required this.onWaifuNsfwChanged,
    this.onExportBackup,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

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

          // Theme Selection
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Theme', style: Theme.of(context).textTheme.titleMedium),
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
            value: gridEnabled,
            onChanged: onGridEnabledChanged,
          ),
          if (gridEnabled) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: DropdownButton<GridType>(
                value: gridType,
                onChanged: (GridType? newValue) {
                  if (newValue != null) {
                    onGridTypeChanged(newValue);
                  }
                },
                items: GridType.values.map((GridType type) {
                  return DropdownMenuItem<GridType>(
                    value: type,
                    child: Text(
                      type == GridType.grid ? 'Grid (Math)' : 'Writing Lines',
                    ),
                  );
                }).toList(),
              ),
            ),
            if (gridType == GridType.grid)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      'Grid Spacing: ${gridSpacing.toInt()}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    Slider(
                      value: gridSpacing,
                      min: 20.0,
                      max: 100.0,
                      divisions: 16,
                      label: gridSpacing.round().toString(),
                      onChanged: onGridSpacingChanged,
                    ),
                  ],
                ),
              ),
          ],
          const Divider(),

          // AI Settings
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
                  controller: tokenController,
                  decoration: const InputDecoration(
                    labelText: 'OpenRouter API Token',
                    border: OutlineInputBorder(),
                    hintText: 'sk-or-v1-...',
                  ),
                  obscureText: true,
                  onChanged: onTokenChanged,
                ),
                const SizedBox(height: 16),
                Text('AI Model', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: aiModel,
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
                      onAiModelChanged(value);
                    }
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tutor Mode'),
                  subtitle: const Text('AI will act as a helpful tutor'),
                  value: tutorEnabled,
                  onChanged: onTutorEnabledChanged,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Submit Last Image Only'),
                  subtitle: const Text(
                    'AI will only receive the last captured image',
                  ),
                  value: submitLastImageOnly,
                  onChanged: onSubmitLastImageOnlyChanged,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Anime Background'),
                  subtitle: const Text('Fetch random anime image on open'),
                  value: waifuFetcherEnabled,
                  onChanged: onWaifuFetcherEnabledChanged,
                ),
                if (waifuFetcherEnabled)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Image Width: ${waifuImageWidth.toInt()}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Slider(
                          value: waifuImageWidth,
                          min: 200.0,
                          max: 2000.0,
                          divisions: 18,
                          label: waifuImageWidth.round().toString(),
                          onChanged: onWaifuImageWidthChanged,
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('NSFW'),
                          value: waifuNsfw,
                          onChanged: onWaifuNsfwChanged,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tag',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        DropdownButtonFormField<String>(
                          value: waifuTag,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                          ),
                          items:
                              (waifuNsfw
                                      ? AppConfig.waifuTagsNsfw
                                      : AppConfig.waifuTagsSfw)
                                  .map((tag) {
                                    return DropdownMenuItem(
                                      value: tag,
                                      child: Text(tag),
                                    );
                                  })
                                  .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              onWaifuTagChanged(value);
                            }
                          },
                        ),
                      ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
