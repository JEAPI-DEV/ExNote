import 'dart:convert';

/// Parses one OpenRouter/OpenAI-compatible SSE data event.
String? decodeChatDelta(String data) {
  if (data == '[DONE]') return null;
  final event = jsonDecode(data) as Map<String, dynamic>;
  if (event['error'] != null) {
    throw StateError('AI request failed: ${event['error']}');
  }
  final choices = event['choices'] as List?;
  if (choices == null || choices.isEmpty) return '';
  final choice = choices.first as Map;
  if (choice['finish_reason'] == 'length') {
    throw StateError(
      'The response reached the output limit. Ask the assistant to continue.',
    );
  }
  return (choice['delta'] as Map?)?['content'] as String? ?? '';
}
