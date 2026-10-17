// lib/services/socket_service.dart
// §1.6 UPDATE — added leaveOrderRoom + multi-listener onOrderStatusUpdate
// §1.7 UPDATE — added join_support / support_message / support_chat_status
// §1.8 UPDATE — added joinCustomerRoom + new_notification listener

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
  SupportMessageCallback? onSupportMessage;    // §1.7
  SupportStatusCallback?  onSupportChatStatus; // §1.7 — lock/unlock events
  NotificationCallback?   onNewNotification;   // §1.8

  // §1.6 — multi-listener list so multiple providers can subscribe simultaneously
  final List<OrderStatusCallback> _orderStatusListeners = [];

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

    // §1.6 — fan-out to all registered listeners
    _socket!.on('order_status_update', (data) {
      try {
        for (final cb in List.of(_orderStatusListeners)) {
          cb(data as Map<String, dynamic>);
        }
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

    // §1.8 — real-time new notification push
    _socket!.on('new_notification', (data) {
      try {
        onNewNotification?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] new_notification error: $e');
      }
    });

    // fallback alias (some backends emit 'notification')
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

  /// §1.7 — Call after login: joins the customer's personal support room so
  /// they receive real-time staff replies and lock/unlock state changes.
  void joinSupportRoom(int customerId) {
    _socket?.emit('join_support', {'customer_id': customerId});
  }

  /// §1.8 — Call after login: joins the customer's personal notification room
  /// so the app receives real-time `new_notification` events for badge updates.
  void joinCustomerRoom(int customerId) {
    _socket?.emit('join_customer', {'customer_id': customerId});
  }

  /// §1.6 — Call when opening the order tracking screen.
  void joinOrderRoom(int orderId) {
    _socket?.emit('join_order', {'order_id': orderId});
  }

  /// §1.6 — Call when leaving the order tracking screen (in Provider.dispose).
  void leaveOrderRoom(int orderId) {
    _socket?.emit('leave_order', {'order_id': orderId});
  }

  // ── Listeners ───────────────────────────────────────────────────────────────

  /// §1.6 — Register a callback for order_status_update events.
  /// Returns a VoidCallback — call it in your provider's dispose() to unsubscribe.
  ///
  /// Usage:
  ///   late final VoidCallback _unsub;
  ///   _unsub = SocketService.instance.listenOrderStatus((data) { ... });
  ///   // in dispose:
  ///   _unsub();
  VoidCallback listenOrderStatus(OrderStatusCallback cb) {
    _orderStatusListeners.add(cb);
    return () => _orderStatusListeners.remove(cb);
  }

  // ── Disconnect ──────────────────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket?.connected ?? false;
}