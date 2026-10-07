import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../services/ai_service.dart';
import '../services/ai/note_chat_context.dart';

/// Owns the request lifecycle so rebuilding or closing the drawer does not lose a reply.
class AiChatController extends ChangeNotifier {
  final List<ChatMessage> history = [];
  final TextEditingController textController = TextEditingController();
  bool isLoading = false;
  bool readReplies = false;
  Timer? _replyUpdateTimer;

  void setReadReplies(bool value) {
    readReplies = value;
    _notify();
  }

  String? pendingBase64Image;
  String? error;
  bool _disposed = false;
  StreamSubscription<String>? _reply;
  Completer<void>? _done;
  int _generation = 0;
  String? _retryText;
  List<ChatMessage>? _retryHistory;

  void addMessage(ChatMessage message) {
    history.add(message);
    _notify();
  }

  void clearHistory(String greeting) {
    if (isLoading) return;
    history.clear();
    history.add(ChatMessage(text: greeting, isAi: true));
    error = null;
    _retryText = null;
    _retryHistory = null;
    _notify();
  }

  void setLoading(bool value) {
    isLoading = value;
    _notify();
  }

  void setPendingImage(String? base64) {
    pendingBase64Image = base64;
    _notify();
  }

  Future<void> send({
    required AiService service,
    required Future<NoteChatContext> Function(String query) context,
    bool submitLastImageOnly = true,
    bool retry = false,
  }) async {
    if (isLoading || _disposed) return;
    final text = retry ? _retryText ?? '' : textController.text.trim();
    if (!retry && text.isEmpty && pendingBase64Image == null) return;
    if (retry && _retryHistory == null) return;
    error = null;
    isLoading = true;
    final generation = ++_generation;
    if (!retry) {
      history.add(
        ChatMessage(text: text, isAi: false, base64Image: pendingBase64Image),
      );
      textController.clear();
      pendingBase64Image = null;
    }
    final input = retry
        ? List<ChatMessage>.of(_retryHistory!)
        : List<ChatMessage>.of(history);
    _retryText = text;
    _retryHistory = input;
    int? replyIndex;
    _notify();
    try {
      final material = await context(text);
      if (_disposed || generation != _generation) return;
      replyIndex = history.length;
      history.add(ChatMessage(text: '', isAi: true));
      final response = StringBuffer();
      // Keep stream errors and cleanup in the request lifecycle.
      final done = Completer<void>();
      _done = done;
      _reply = service
          .streamMessage(
            input,
            submitLastImageOnly: submitLastImageOnly,
            context: material,
          )
          .listen(
            (delta) {
              if (_disposed || generation != _generation) return;
              response.write(delta);
              history[replyIndex!] = ChatMessage(
                text: response.toString(),
                isAi: true,
              );
              // Batch chunks so Markdown and LaTeX do not re-layout for every token.
              _replyUpdateTimer ??= Timer(const Duration(milliseconds: 80), () {
                _replyUpdateTimer = null;
                _notify();
              });
            },
            onError: (Object exception, StackTrace stack) {
              if (!done.isCompleted) done.completeError(exception, stack);
            },
            onDone: () {
              if (!done.isCompleted) done.complete();
            },
            cancelOnError: true,
          );
      await done.future;
      _retryHistory = null;
    } catch (exception) {
      if (!_disposed && generation == _generation) {
        if (replyIndex != null && history[replyIndex].text.isEmpty) {
          history.removeAt(replyIndex);
        }
        error = '$exception';
      }
    } finally {
      if (!_disposed && generation == _generation) {
        _replyUpdateTimer?.cancel();
        _replyUpdateTimer = null;
        isLoading = false;
        _reply = null;
        _done = null;
        _notify();
      }
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _replyUpdateTimer?.cancel();
    _disposed = true;
    _generation++;
    _reply?.cancel();
    if (_done != null && !_done!.isCompleted) _done!.complete();
    textController.dispose();
    super.dispose();
  }
}
