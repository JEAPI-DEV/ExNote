class ChatMessage {
  final String text;
  final bool isAi;
  final String? base64Image;

  ChatMessage({required this.text, required this.isAi, this.base64Image});
}
