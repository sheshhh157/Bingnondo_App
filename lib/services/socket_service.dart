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
typedef RiderLocationCallback   = void Function(Map<String, dynamic>);

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  IO.Socket? _socket;

  // Single-callback handlers registered by providers
  MenuUpdateCallback?     onMenuUpdate;
  OrderStatusCallback?    onOrderStatusUpdate;
  SupportMessageCallback? onSupportMessage;
  SupportStatusCallback?  onSupportChatStatus;
  NotificationCallback?   onNewNotification;

  // Multi-listener callback lists
  final List<OrderStatusCallback>   _orderStatusListeners = [];
  final List<RiderLocationCallback>  _riderLocationListeners = [];

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
        final map = data as Map<String, dynamic>;
        onOrderStatusUpdate?.call(map);
        for (final cb in List.of(_orderStatusListeners)) {
          cb(map);
        }
      } catch (e) {
        debugPrint('[Socket] order_status_update error: $e');
      }
    });

    _socket!.on('rider_location_update', (data) {
      try {
        final map = data as Map<String, dynamic>;
        for (final cb in List.of(_riderLocationListeners)) {
          cb(map);
        }
      } catch (e) {
        debugPrint('[Socket] rider_location_update error: $e');
      }
    });

    _socket!.on('support_message', (data) {
      try {
        onSupportMessage?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] support_message error: $e');
      }
    });

    _socket!.on('support_chat_status', (data) {
      try {
        onSupportChatStatus?.call(data as Map<String, dynamic>);
      } catch (e) {
        debugPrint('[Socket] support_chat_status error: $e');
      }
    });

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

  // ── Listener subscriptions ───────────────────────────────────────────────

  VoidCallback listenOrderStatus(OrderStatusCallback cb) {
    _orderStatusListeners.add(cb);
    return () => _orderStatusListeners.remove(cb);
  }

  VoidCallback listenRiderLocation(RiderLocationCallback cb) {
    _riderLocationListeners.add(cb);
    return () => _riderLocationListeners.remove(cb);
  }

  // ── Rooms ───────────────────────────────────────────────────────────────────

  void joinSupportRoom(int customerId) {
    _socket?.emit('join_support', {'customer_id': customerId});
  }

  void joinCustomerRoom(int customerId) {
    _socket?.emit('join_customer', {'customer_id': customerId});
  }

  void joinOrderRoom(int orderId) {
    _socket?.emit('join_order', {'order_id': orderId});
  }

  void leaveOrderRoom(int orderId) {
    _socket?.emit('leave_order', {'order_id': orderId});
  }

  // ── Disconnect ──────────────────────────────────────────────────────────────
  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  bool get isConnected => _socket?.connected ?? false;
}
