// lib/services/socket_service.dart
// §1.7 UPDATE — added join_support / support_message / support_chat_status / new_notification
// All other logic (menu, order, esp32) is unchanged from the previous version.

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

const String _kDefaultBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

typedef MenuUpdateCallback      = void Function(Map<String, dynamic>);
typedef OrderStatusCallback     = void Function(Map<String, dynamic>);
typedef SupportMessageCallback  = void Function(Map<String, dynamic>);
typedef SupportStatusCallback   = void Function(Map<String, dynamic>);
typedef NotificationCallback    = void Function(Map<String, dynamic>);

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  IO.Socket? _socket;

  // Callbacks registered by providers
  MenuUpdateCallback?     onMenuUpdate;
  OrderStatusCallback?    onOrderStatusUpdate;
  SupportMessageCallback? onSupportMessage;    // §1.7
  SupportStatusCallback?  onSupportChatStatus; // §1.7 — lock/unlock events
  NotificationCallback?   onNewNotification;

  // ── Connect ─────────────────────────────────────────────────────────────────
  void connect([String? baseUrl]) {
    final targetUrl = (baseUrl != null && baseUrl.isNotEmpty) ? baseUrl : _kDefaultBaseUrl;
    if (_socket != null && _socket!.connected) return;

    _socket = IO.io(
      targetUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('[Socket] connected to $targetUrl');
      // Join the shared menu room automatically on connect
      _socket!.emit('join_menu');
    });

    _socket!.on('menu_update', (data) {
      try {
        onMenuUpdate?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] menu_update error: $e');
      }
    });

    _socket!.on('order_status_update', (data) {
      try {
        onOrderStatusUpdate?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] order_status_update error: $e');
      }
    });

    // §1.7 — real-time support message from staff
    _socket!.on('support_message', (data) {
      try {
        onSupportMessage?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] support_message error: $e');
      }
    });

    // §1.7 — chat locked / unlocked (triggered by order status changes)
    _socket!.on('support_chat_status', (data) {
      try {
        onSupportChatStatus?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] support_chat_status error: $e');
      }
    });

    // Real-time new notification event
    _socket!.on('new_notification', (data) {
      try {
        onNewNotification?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] new_notification error: $e');
      }
    });

    _socket!.on('notification', (data) {
      try {
        onNewNotification?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] notification error: $e');
      }
    });

    _socket!.onDisconnect((_) => debugPrint('[Socket] disconnected'));
    _socket!.onError((e) => debugPrint('[Socket] error: $e'));

    _socket!.connect();
  }

  // ── Rooms ───────────────────────────────────────────────────────────────────

  /// Call after login — joins the customer's personal support room so they
  /// receive real-time staff replies and lock/unlock state changes.
  void joinSupportRoom(int customerId) {
    _socket?.emit('join_support', {'customer_id': customerId});
  }

  /// Call when opening the order tracking screen.
  void joinOrderRoom(int orderId) {
    _socket?.emit('join_order', {'order_id': orderId});
  }

  // ── Disconnect ──────────────────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket?.connected ?? false;
}
