import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

const String _wsBaseUrl = String.fromEnvironment(
  'WS_BASE_URL',
  defaultValue: 'http://10.0.2.2:3000',
);

// Callback type for menu item availability changes
typedef MenuUpdateCallback = void Function(int itemId, bool isAvailable);

/// Manages the Socket.io connection for real-time events.
/// Currently handles:
///   - `menu_update`  → fired by backend when a menu item's availability changes
///   - `connect_error` → logs auth failures without crashing
class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  io.Socket? _socket;
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  MenuUpdateCallback? onMenuUpdate;

  bool get isConnected => _socket?.connected ?? false;

  /// Call once after login — wires up the socket with the stored access token.
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
        debugPrint('[Socket] Connected to $_wsBaseUrl');
      })
      ..on('menu_update', (data) {
        // Expected payload: { item_id: int, is_available: bool }
        try {
          final itemId = data['item_id'] as int;
          final isAvailable = data['is_available'] as bool;
          onMenuUpdate?.call(itemId, isAvailable);
        } catch (e) {
          debugPrint('[Socket] menu_update parse error: $e');
        }
      })
      ..onConnectError((e) {
        debugPrint('[Socket] Connection error: $e');
      })
      ..onDisconnect((_) {
        debugPrint('[Socket] Disconnected');
      });

    _socket!.connect();
  }

  void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }
}