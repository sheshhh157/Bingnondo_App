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
      ..onConnect((_) => debugPrint('[Socket] Connected'))

    // §1.3 — menu availability changes
      ..on('menu_update', (data) {
        try {
          onMenuUpdate?.call(
              data['item_id'] as int, data['is_available'] as bool);
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