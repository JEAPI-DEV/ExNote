import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

class AiService {
  final String apiKey;
  final String model;
  final bool isTutorMode;

  AiService({
    required this.apiKey,
    this.model = 'google/gemini-2.0-flash-exp:free',
    this.isTutorMode = false,
  });

  Future<String> sendMessage(
    List<ChatMessage> history, {
    bool submitLastImageOnly = true,
  }) async {
    if (apiKey.isEmpty) {
      return 'Please set your OpenRouter API Token in Settings.';
    }

    try {
      final systemPrompt = isTutorMode
          ? "You are a helpful and encouraging tutor. Your goal is to guide the student to the answer by asking leading questions and providing hints, rather than just giving the solution. Use clear and simple language. Format math equations using standard LaTeX: \\( ... \\) or \$ ... \$ for inline math, and \\[ ... \\] or \$\$ ... \$\$ for block math."
          : "You are a helpful assistant. Provide clear and concise answers. Format math equations using standard LaTeX: \\( ... \\) or \$ ... \$ for inline math, and \\[ ... \\] or \$\$ ... \$\$ for block math.";

      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt},
      ];

      int lastImageIndex = -1;
      if (submitLastImageOnly) {
        lastImageIndex = history.lastIndexWhere(
          (msg) => msg.base64Image != null,
        );
      }

      for (int i = 0; i < history.length; i++) {
        final msg = history[i];

        final shouldIncludeImage =
            msg.base64Image != null &&
            (!submitLastImageOnly || i == lastImageIndex);

        if (shouldIncludeImage) {
          messages.add({
            'role': msg.isAi ? 'assistant' : 'user',
            'content': [
              {'type': 'text', 'text': msg.text},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/png;base64,${msg.base64Image}',
                },
              },
            ],
          });
        } else {
          messages.add({
            'role': msg.isAi ? 'assistant' : 'user',
            'content': msg.text,
          });
        }
      }

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer':
              'https://github.com/jeapi/excerciser', // Required by OpenRouter
          'X-Title': 'ExNote',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature': 0.7,
          'top_p': 1.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['choices'] != null && (data['choices'] as List).isNotEmpty) {
          final choice = data['choices'][0];
          final message = choice['message'];
          String content = message['content'] ?? '';

          final reasoning = message['reasoning'];
          if (reasoning != null && reasoning.toString().isNotEmpty) {
            content =
                '> **Reasoning:**\n> ${reasoning.toString().replaceAll('\n', '\n> ')}\n\n$content';
          }

          return content.isEmpty ? 'No response from AI' : content;
        }
        return 'No response from AI';
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
