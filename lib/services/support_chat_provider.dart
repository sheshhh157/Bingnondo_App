import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';
import '../mock/mock_data.dart';
import 'tracking_service.dart';
import 'socket_service.dart';

enum ChatLoadState { initial, loading, loaded, error, noActiveOrder }

class SupportChatProvider extends ChangeNotifier {
  SupportChat? _chat;
  ChatLoadState _state = ChatLoadState.initial;
  String? _errorMessage;
  bool _isSending = false;
  int? _activeOrderId; // passed when opening from order screen

  SupportChat? get chat => _chat;
  ChatLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isSending => _isSending;
  bool get isLoaded => _state == ChatLoadState.loaded;
  List<SupportMessage> get messages => _chat?.messages ?? [];
  bool get isLocked => _chat?.isLocked ?? false;

  SupportChatProvider() {
    SocketService.instance.onSupportMessage = _handleIncomingMessage;
  }

  void setActiveOrderId(int? orderId) {
    _activeOrderId = orderId;
  }

  Future<void> loadChat() async {
    _state = ChatLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 600));
        _chat = SupportChat.fromJson(kMockSupportChat);
        _state = _chat!.isLocked
            ? ChatLoadState.loaded
            : ChatLoadState.loaded;
      } else {
        final result = await TrackingService.instance.fetchSupportChat();
        if (result == null) {
          _state = ChatLoadState.noActiveOrder;
        } else {
          _chat = result;
          _state = ChatLoadState.loaded;
          // Mark messages read
          TrackingService.instance.markMessagesRead();
        }
      }
    } on TrackingApiException catch (e) {
      _errorMessage = e.message;
      _state = ChatLoadState.error;
    } catch (_) {
      _errorMessage = 'Could not load chat. Please try again.';
      _state = ChatLoadState.error;
    }
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isSending || isLocked) return;

    _isSending = true;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 700));
        final msg = SupportMessage(
          id: DateTime.now().millisecondsSinceEpoch,
          content: content.trim(),
          isFromCustomer: true,
          relatedOrderId: _activeOrderId,
          sentAt: DateTime.now(),
        );
        _appendMessage(msg);

        // Simulate staff reply after 2s
        await Future.delayed(const Duration(seconds: 2));
        _appendMessage(SupportMessage(
          id: DateTime.now().millisecondsSinceEpoch + 1,
          content: kMockStaffReply(content),
          isFromCustomer: false,
          sentAt: DateTime.now(),
        ));
      } else {
        final msg = await TrackingService.instance.sendSupportMessage(
          content: content.trim(),
          relatedOrderId: _activeOrderId,
        );
        _appendMessage(msg);
      }
    } on TrackingApiException catch (e) {
      _errorMessage = e.message;
    } catch (_) {
      _errorMessage = 'Message not sent. Please try again.';
    } finally {
      _isSending = false;
      notifyListeners();
    }
  }

  // Called by Socket.io `support_message` event
  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final msg = SupportMessage.fromJson(data);
      if (!msg.isFromCustomer) {
        _appendMessage(msg);
      }
    } catch (_) {}
  }

  void _appendMessage(SupportMessage msg) {
    if (_chat == null) return;
    final updated = List<SupportMessage>.from(_chat!.messages)..add(msg);
    _chat = SupportChat(
      id: _chat!.id,
      status: _chat!.status,
      messages: updated,
      activeOrderId: _chat!.activeOrderId,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    SocketService.instance.onSupportMessage = null;
    super.dispose();
  }
}