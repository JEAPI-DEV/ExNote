import 'package:flutter/material.dart';
import '../models/chat_message.dart';

class AiChatController extends ChangeNotifier {
  final List<ChatMessage> history = [];
  final TextEditingController textController = TextEditingController();
  bool isLoading = false;
  String? pendingBase64Image;

  void addMessage(ChatMessage message) {
    history.add(message);
    notifyListeners();
  }

  void clearHistory(String greeting) {
    history.clear();
    history.add(ChatMessage(text: greeting, isAi: true));
    notifyListeners();
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  void setPendingImage(String? base64) {
    pendingBase64Image = base64;
    notifyListeners();
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }
}
