import 'package:flutter/material.dart';
import '../controllers/library_index_controller.dart';
import '../models/indexing/indexing_settings.dart';
import '../utils/app_config.dart';

class IndexingSettingsPanel extends StatelessWidget {
  final LibraryIndexController controller;
  const IndexingSettingsPanel({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text('Scan notes with'),
      const SizedBox(height: 8),
      SegmentedButton<IndexingBackend>(
        segments: const [
          ButtonSegment(
            value: IndexingBackend.local,
            label: Text('Local model'),
            icon: Icon(Icons.phone_android),
          ),
          ButtonSegment(
            value: IndexingBackend.openRouter,
            label: Text('OpenRouter'),
            icon: Icon(Icons.cloud_outlined),
          ),
        ],
        selected: {controller.settings.backend},
        onSelectionChanged: controller.isRunning || controller.isInstalling
            ? null
            : (values) => controller.configure(
                controller.settings.copyWith(backend: values.first),
              ),
      ),
      if (controller.isCloud) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(controller.settings.model),
          initialValue: controller.settings.model,
          decoration: const InputDecoration(
            labelText: 'Scan model',
            border: OutlineInputBorder(),
          ),
          items: AppConfig.aiModels
              .map(
                (model) => DropdownMenuItem(
                  value: model['id'],
                  child: Text(model['name']!),
                ),
              )
              .toList(),
          onChanged: controller.isRunning
              ? null
              : (value) {
                  if (value != null) {
                    controller.configure(
                      controller.settings.copyWith(model: value),
                    );
                  }
                },
        ),
        const SizedBox(height: 8),
        const Text(
          'Scanned note images are sent to OpenRouter using your token from AI Settings. Chat settings are separate.',
        ),
      ],
      const SizedBox(height: 12),
    ],
  );
}
