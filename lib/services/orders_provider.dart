import 'package:flutter/foundation.dart';
import '../models/order_summary_model.dart';
import '../models/tracking_models.dart';
import '../mock/mock_data.dart';
import 'orders_service.dart';

enum OrdersLoadState { initial, loading, loaded, error }

class OrdersProvider extends ChangeNotifier {
  List<OrderSummary> _orders = [];
  OrdersLoadState _state = OrdersLoadState.initial;
  String? _errorMessage;

  List<OrderSummary> get orders => List.unmodifiable(_orders);
  OrdersLoadState get state => _state;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _state == OrdersLoadState.loaded;

  List<OrderSummary> get activeOrders =>
      _orders.where((o) => o.isActive).toList();
  List<OrderSummary> get pastOrders =>
      _orders.where((o) => !o.isActive).toList();

  Future<void> loadOrders() async {
    if (_state == OrdersLoadState.loading) return;
    _state = OrdersLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 700));
        _orders = kMockOrderList
            .map((o) => OrderSummary.fromJson(o as Map<String, dynamic>))
            .toList();
      } else {
        _orders = await OrdersService.instance.fetchOrders();
      }
      _state = OrdersLoadState.loaded;
    } on OrdersApiException catch (e) {
      _errorMessage = e.message;
      _state = OrdersLoadState.error;
    } catch (e, st) {
      debugPrint('[OrdersProvider] loadOrders failed: $e\n$st');
      _errorMessage = 'Could not load orders. Please try again.';
      _state = OrdersLoadState.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => loadOrders();

  /// Call on logout so the next account doesn't inherit stale orders.
  void clear() {
    _orders = [];
    _state = OrdersLoadState.initial;
    _errorMessage = null;
    notifyListeners();
  }

  void patchOrderStatus(int orderId, String newStatus) {
    final idx = _orders.indexWhere((o) => o.id == orderId);
    if (idx < 0) return;
    final old = _orders[idx];

    OrderStatus mappedStatus;
    switch (newStatus) {
      case 'confirmed': mappedStatus = OrderStatus.confirmed; break;
      case 'preparing': mappedStatus = OrderStatus.preparing; break;
      case 'ready':     mappedStatus = OrderStatus.ready; break;
      case 'out_for_delivery': mappedStatus = OrderStatus.outForDelivery; break;
      case 'completed': mappedStatus = OrderStatus.completed; break;
      case 'cancelled': mappedStatus = OrderStatus.cancelled; break;
      default:          mappedStatus = OrderStatus.pending;
    }

    _orders[idx] = OrderSummary(
      id: old.id,
      orderNumber: old.orderNumber,
      status: mappedStatus,
      totalAmount: old.totalAmount,
      itemCount: old.itemCount,
      paymentMethod: old.paymentMethod,
      createdAt: old.createdAt,
    );
    notifyListeners();
  }
}