import 'package:flutter/foundation.dart';
import '../models/menu_models.dart';
import '../services/menu_service.dart';

class ChatbotProvider extends ChangeNotifier {
  final List<ChatMessage> _messages = [];
  bool _isSending = false;
  bool _historyLoaded = false;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isSending => _isSending;
  bool get isEmpty => _messages.isEmpty;

  Future<void> loadHistory() async {
    if (_historyLoaded) return;
    _historyLoaded = true;

    final history = await MenuService.instance.fetchChatHistory();
    if (history != null && history.messages.isNotEmpty) {
      _messages.insertAll(0, history.messages);
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    final userMsg = ChatMessage.user(text.trim());
    _messages.add(userMsg);

    final loadingMsg = ChatMessage.botLoading();
    _messages.add(loadingMsg);

    _isSending = true;
    notifyListeners();

    try {
      final reply = await MenuService.instance.sendChatMessage(text.trim());
      _messages.removeLast(); // remove loading
      _messages.add(ChatMessage.bot(reply));
    } on MenuApiException catch (e) {
      _messages.removeLast();
      _messages.add(ChatMessage.bot(
        'Sorry, I had trouble responding. ${e.message}',
      ));
    } catch (_) {
      _messages.removeLast();
      _messages.add(ChatMessage.bot(
        'Something went wrong. Please try again.',
      ));
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  void clearHistory() {
    _messages.clear();
    _historyLoaded = false;
    notifyListeners();
  }
}