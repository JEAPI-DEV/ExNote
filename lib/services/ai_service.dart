import 'dart:convert';
import 'package:http/http.dart' as http;

class AiService {
  final String apiKey;
  final String model;
  final bool isTutorMode;

  AiService({
    required this.apiKey,
    this.model = 'google/gemini-2.0-flash-exp:free',
    this.isTutorMode = false,
  });

  Future<String> sendMessage(String message, {String? base64Image}) async {
    if (apiKey.isEmpty) {
      return 'Please set your OpenRouter API Token in Settings.';
    }

    try {
      final systemPrompt = isTutorMode
          ? "You are a helpful and encouraging tutor. Your goal is to guide the student to the answer by asking leading questions and providing hints, rather than just giving the solution. Use clear and simple language."
          : "You are a helpful assistant. Provide clear and concise answers.";

      final List<Map<String, dynamic>> messages = [
        {'role': 'system', 'content': systemPrompt},
      ];

      if (base64Image != null) {
        messages.add({
          'role': 'user',
          'content': [
            {'type': 'text', 'text': message},
            {
              'type': 'image_url',
              'image_url': {'url': 'data:image/png;base64,$base64Image'},
            },
          ],
        });
      } else {
        messages.add({'role': 'user', 'content': message});
      }

      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
          'X-Title': 'ExNote', // Optional
        },
        body: jsonEncode({'model': model, 'messages': messages}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices'][0]['message']['content'] ??
            'No response from AI';
      } else {
        return 'Error: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      return 'Error: $e';
    }
  }
}
