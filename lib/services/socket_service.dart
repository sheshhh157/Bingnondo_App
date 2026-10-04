import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const String _wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

typedef MenuUpdateCallback       = void Function(int itemId, bool isAvailable);
typedef OrderStatusCallback      = void Function(int orderId, String newStatus);
typedef SupportMessageCallback   = void Function(Map<String, dynamic> data);
typedef NewNotificationCallback  = void Function(Map<String, dynamic> data);

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Registered callbacks
  MenuUpdateCallback?       onMenuUpdate;
  OrderStatusCallback?      onOrderStatusUpdate;
  SupportMessageCallback?   onSupportMessage;
  NewNotificationCallback?  onNewNotification;  // §1.8

  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect() async {
    if (_socket?.connected == true) return;

    final token = await _storage.read(key: 'access_token');

    _socket = io.io(
      _wsBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .setAuth({'token': token ?? ''})
          .build(),
    );

    _socket!
      ..onConnect((_) {
        debugPrint('[Socket] Connected');
        // § 1.3 — join the shared menu room so we receive menu_update events.
        // Must be emitted AFTER connection is established.
        _socket!.emit('join_menu');
      })

    // § 1.3 — real-time menu availability patch
    // Backend payload: { items: [{ id: int, is_available: bool }, ...] }
    // The backend may update multiple items in one event (e.g. when an
    // ingredient runs out and affects several dishes at once).
      ..on('menu_update', (data) {
        try {
          final raw = data as Map<String, dynamic>;
          final itemsList = raw['items'] as List<dynamic>? ?? [];
          for (final entry in itemsList) {
            final item = entry as Map<String, dynamic>;
            onMenuUpdate?.call(
              item['id'] as int,
              item['is_available'] as bool,
            );
          }
        } catch (e) {
          debugPrint('[Socket] menu_update error: $e');
        }
      })

    // §1.6 — order status changes
      ..on('order_status_update', (data) {
        try {
          onOrderStatusUpdate?.call(
              data['order_id'] as int, data['status'] as String);
        } catch (e) {
          debugPrint('[Socket] order_status_update error: $e');
        }
      })

    // §1.7 — incoming staff message
      ..on('support_message', (data) {
        try {
          onSupportMessage?.call(data as Map<String, dynamic>);
        } catch (e) {
          debugPrint('[Socket] support_message error: $e');
        }
      })

    // §1.8 — push notification to in-app notification center
      ..on('new_notification', (data) {
        try {
          onNewNotification?.call(data as Map<String, dynamic>);
        } catch (e) {
          debugPrint('[Socket] new_notification error: $e');
        }
      })

      ..onConnectError((e) => debugPrint('[Socket] Connect error: $e'))
      ..onDisconnect((_) => debugPrint('[Socket] Disconnected'));

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}