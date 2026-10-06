import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';
import '../mock/mock_data.dart';
import 'tracking_service.dart';
import 'socket_service.dart';

enum TrackingLoadState { initial, loading, loaded, error }

class OrderTrackingProvider extends ChangeNotifier {
  OrderDetail? _order;
  TrackingLoadState _state = TrackingLoadState.initial;
  String? _errorMessage;
  bool _isCancelling = false;

  OrderDetail? get order => _order;
  TrackingLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isCancelling => _isCancelling;
  bool get isLoaded => _state == TrackingLoadState.loaded;

  OrderTrackingProvider() {
    // Hook into Socket.io `order_status_update` events
    SocketService.instance.onOrderStatusUpdate = _handleSocketData;
  }

  void _handleSocketData(Map<String, dynamic> data) {
    try {
      final orderId = (data['order_id'] ?? data['id']) as int?;
      final statusStr = (data['status'] ?? data['order_status']) as String?;
      if (orderId != null && statusStr != null) {
        _handleSocketUpdate(orderId, statusStr);
      }
    } catch (_) {}
  }

  Future<void> loadOrder(int orderId) async {
    _state = TrackingLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 700));
        _order = OrderDetail.fromJson(kMockOrderDetail);
      } else {
        _order = await TrackingService.instance.fetchOrder(orderId);
      }
      _state = TrackingLoadState.loaded;
    } on TrackingApiException catch (e) {
      _errorMessage = e.message;
      _state = TrackingLoadState.error;
    } catch (_) {
      _errorMessage = 'Could not load order. Please try again.';
      _state = TrackingLoadState.error;
    }
    notifyListeners();
  }

  // Called by Socket.io `order_status_update` — payload: { order_id, status }
  void _handleSocketUpdate(int orderId, String newStatus) {
    if (_order == null || _order!.id != orderId) return;
    final updated = OrderStatusX.fromString(newStatus);
    _order = OrderDetail(
      id: _order!.id,
      orderNumber: _order!.orderNumber,
      status: updated,
      paymentMethod: _order!.paymentMethod,
      totalAmount: _order!.totalAmount,
      items: _order!.items,
      notes: _order!.notes,
      delivery: _order!.delivery,
      createdAt: _order!.createdAt,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  Future<bool> cancelOrder() async {
    if (_order == null) return false;
    _isCancelling = true;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 700));
        _handleSocketUpdate(_order!.id, 'cancelled');
      } else {
        await TrackingService.instance.cancelOrder(_order!.id);
        // Actual status change will come via Socket.io
      }
      _isCancelling = false;
      notifyListeners();
      return true;
    } on TrackingApiException catch (e) {
      _errorMessage = e.message;
      _isCancelling = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> refresh() async {
    if (_order == null) return;
    await loadOrder(_order!.id);
  }

  @override
  void dispose() {
    SocketService.instance.onOrderStatusUpdate = null;
    super.dispose();
  }
}
