// socket_service_patch.dart  —  §1.6 patch for lib/services/socket_service.dart
// ─────────────────────────────────────────────────────────────────────────────
// Two small additions needed by OrderTrackingProvider.
// Apply both changes to lib/services/socket_service.dart.
// ─────────────────────────────────────────────────────────────────────────────
//
// ① In the ROOMS section, add leaveOrderRoom() right after joinOrderRoom():
//
//   /// Call when leaving the order tracking screen (Provider.dispose).
//   void leaveOrderRoom(int orderId) {
//     _socket?.emit('leave_order', {'order_id': orderId});
//   }
//
// ② Replace the single-callback onOrderStatusUpdate field + its _socket!.on
//   handler with a multi-listener version so multiple providers can listen
//   without clobbering each other's callbacks.
//
//   REMOVE these two lines from the field declarations:
//     OrderStatusCallback?    onOrderStatusUpdate;
//
//   ADD this field instead:
//     final List<OrderStatusCallback> _orderStatusListeners = [];
//
//   ADD these two methods to the public API (below joinOrderRoom):
//
//     /// Register a listener for order_status_update events.
//     /// Returns a VoidCallback that unregisters it — call it in dispose().
//     VoidCallback onOrderStatusUpdate(OrderStatusCallback cb) {
//       _orderStatusListeners.add(cb);
//       return () => _orderStatusListeners.remove(cb);
//     }
//
//   REPLACE the _socket!.on handler in connect():
//     _socket!.on('order_status_update', (data) {
//       try {
//         for (final cb in List.of(_orderStatusListeners)) {
//           cb(data as Map<String, dynamic>);
//         }
//       } catch (e) {
//         debugPrint('[Socket] order_status_update error: $e');
//       }
//     });
//
// ─────────────────────────────────────────────────────────────────────────────
// FULL UPDATED socket_service.dart (copy this file over the existing one)
// ─────────────────────────────────────────────────────────────────────────────

// lib/services/socket_service.dart
// §1.6 UPDATE — added leaveOrderRoom + multi-listener onOrderStatusUpdate
// §1.7 UPDATE — added join_support / support_message / support_chat_status / new_notification

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
  NotificationCallback?   onNewNotification;

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

  /// Call when leaving the order tracking screen (in Provider.dispose).
  /// §1.6 NEW
  void leaveOrderRoom(int orderId) {
    _socket?.emit('leave_order', {'order_id': orderId});
  }

  // ── Listeners ───────────────────────────────────────────────────────────────

  /// Register a callback for order_status_update events.
  /// Returns a VoidCallback — call it in your provider's dispose() to unsubscribe.
  ///
  /// §1.6 NEW — replaces the single `onOrderStatusUpdate` field with a list
  /// so OrderTrackingProvider and any other listener can coexist.
  ///
  /// Usage:
  ///   late final VoidCallback _unsub;
  ///   _unsub = SocketService.instance.onOrderStatusUpdate((data) { ... });
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