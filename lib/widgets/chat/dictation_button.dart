import 'package:flutter/material.dart';
import '../../controllers/chat_dictation_controller.dart';

class DictationButton extends StatelessWidget {
  final ChatDictationController controller;
  final bool enabled;
  final Color? iconColor;
  const DictationButton({
    super.key,
    required this.controller,
    this.enabled = true,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => IconButton(
      tooltip: controller.listening ? 'Stop dictation' : 'Dictate a message',
      onPressed: enabled && !controller.starting ? controller.toggle : null,
      icon: Icon(
        controller.listening ? Icons.mic : Icons.mic_none,
        color: controller.listening ? Colors.red : iconColor,
      ),
    ),
  );
}
