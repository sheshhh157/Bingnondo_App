import 'package:flutter/foundation.dart';
import '../models/menu_models.dart';
import '../mock/mock_data.dart';
import 'menu_service.dart';

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
    if (kUseMock) return;
    final history = await MenuService.instance.fetchChatHistory();
    if (history != null && history.messages.isNotEmpty) {
      _messages.insertAll(0, history.messages);
      notifyListeners();
    }
  }

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _isSending) return;

    _messages.add(ChatMessage.user(text.trim()));
    _messages.add(ChatMessage.botLoading());
    _isSending = true;
    notifyListeners();

    try {
      String reply;
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 1200));
        reply = getMockBotReply(text.trim());
      } else {
        reply = await MenuService.instance.sendChatMessage(text.trim());
      }
      _messages.removeLast();
      _messages.add(ChatMessage.bot(reply));
    } on MenuApiException catch (e) {
      _messages.removeLast();
      _messages.add(ChatMessage.bot('Sorry, I had trouble responding. ${e.message}'));
    } catch (_) {
      _messages.removeLast();
      _messages.add(ChatMessage.bot('Something went wrong. Please try again.'));
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