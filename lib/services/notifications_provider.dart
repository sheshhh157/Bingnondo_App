import 'package:flutter/foundation.dart';
import '../models/notification_settings_models.dart';
import '../mock/mock_data.dart';
import 'notifications_settings_service.dart';
import 'socket_service.dart';

enum NotifLoadState { initial, loading, loaded, error }

class NotificationsProvider extends ChangeNotifier {
  List<AppNotification> _notifications = [];
  NotifLoadState _state = NotifLoadState.initial;
  String? _errorMessage;

  List<AppNotification> get notifications =>
      List.unmodifiable(_notifications);
  NotifLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _state == NotifLoadState.loaded;

  int get unreadCount =>
      _notifications.where((n) => !n.isRead).length;

  NotificationsProvider() {
    // Hook into Socket.io `new_notification` event from backend
    SocketService.instance.onNewNotification = _handleIncomingNotification;
  }

  Future<void> load() async {
    if (_state == NotifLoadState.loading) return;
    _state = NotifLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 600));
        _notifications = kMockNotifications
            .map((n) => AppNotification.fromJson(n as Map<String, dynamic>))
            .toList();
      } else {
        _notifications = await NotificationsSettingsService.instance
            .fetchNotifications();
      }
      _state = NotifLoadState.loaded;
    } on SettingsApiException catch (e) {
      _errorMessage = e.message;
      _state = NotifLoadState.error;
    } catch (_) {
      _errorMessage = 'Could not load notifications.';
      _state = NotifLoadState.error;
    }
    notifyListeners();
  }

  Future<void> markRead(int id) async {
    final idx = _notifications.indexWhere((n) => n.id == id);
    if (idx < 0 || _notifications[idx].isRead) return;

    // Optimistic update
    _notifications[idx] = AppNotification(
      id: _notifications[idx].id,
      type: _notifications[idx].type,
      message: _notifications[idx].message,
      isRead: true,
      relatedOrderId: _notifications[idx].relatedOrderId,
      relatedOrderNumber: _notifications[idx].relatedOrderNumber,
      createdAt: _notifications[idx].createdAt,
    );
    notifyListeners();

    if (!kUseMock) {
      NotificationsSettingsService.instance.markRead(id);
    }
  }

  Future<void> markAllRead() async {
    _notifications = _notifications
        .map((n) => AppNotification(
      id: n.id,
      type: n.type,
      message: n.message,
      isRead: true,
      relatedOrderId: n.relatedOrderId,
      relatedOrderNumber: n.relatedOrderNumber,
      createdAt: n.createdAt,
    ))
        .toList();
    notifyListeners();

    if (!kUseMock) {
      NotificationsSettingsService.instance.markAllRead();
    }
  }

  // Called by Socket.io `new_notification` event
  void _handleIncomingNotification(Map<String, dynamic> data) {
    try {
      final notif = AppNotification.fromJson(data);
      _notifications.insert(0, notif);
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refresh() => load();

  @override
  void dispose() {
    SocketService.instance.onNewNotification = null;
    super.dispose();
  }
}