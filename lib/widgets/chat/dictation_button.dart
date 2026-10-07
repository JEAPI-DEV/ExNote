import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device speech recognition inserts a reviewable draft; it never auto-sends.
class DictationButton extends StatefulWidget {
  final TextEditingController controller;
  final bool enabled;
  final Color? iconColor;
  const DictationButton({
    super.key,
    required this.controller,
    this.enabled = true,
    this.iconColor,
  });
  @override
  State<DictationButton> createState() => _DictationButtonState();
}

class _DictationButtonState extends State<DictationButton> {
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;
  bool _starting = false;

  Future<void> _toggle() async {
    if (_starting) return;
    if (_listening) {
      await _speech.stop();
      return;
    }
    _starting = true;
    try {
      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) setState(() => _listening = status == 'listening');
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _listening = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Dictation: ${error.errorMsg}')),
          );
        },
      );
      if (!mounted) return;
      if (!available) {
        throw StateError(
          'Speech recognition is unavailable. Check microphone permission and your device speech service.',
        );
      }
      final value = widget.controller.value;
      final selection = value.selection;
      final start = selection.isValid ? selection.start : value.text.length;
      final end = selection.isValid ? selection.end : value.text.length;
      final prefix = value.text.substring(0, start);
      final suffix = value.text.substring(end);
      await _speech.listen(
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          if (!mounted || !widget.enabled) return;
          final text = '$prefix${result.recognizedWords}$suffix';
          widget.controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(
              offset: prefix.length + result.recognizedWords.length,
            ),
          );
        },
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      _starting = false;
    }
  }

  @override
  void didUpdateWidget(covariant DictationButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _listening) _speech.stop();
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: _listening ? 'Stop dictation' : 'Dictate a message',
    onPressed: widget.enabled ? _toggle : null,
    icon: Icon(
      _listening ? Icons.mic : Icons.mic_none,
      color: _listening ? Colors.red : widget.iconColor,
    ),
  );
}
