import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';
import '../mock/mock_data.dart';
import 'tracking_service.dart';
import 'socket_service.dart';

enum TrackingLoadState { initial, loading, loaded, error }

class OrderTrackingProvider extends ChangeNotifier {
  OrderDetail?   _order;
  OrderTimeline? _timeline;         // §1.6 NEW
  TrackingLoadState _state = TrackingLoadState.initial;
  String? _errorMessage;
  bool _isCancelling = false;

  OrderDetail?   get order       => _order;
  OrderTimeline? get timeline    => _timeline;   // §1.6 NEW
  TrackingLoadState get state    => _state;
  String?        get errorMessage => _errorMessage;
  bool get isCancelling          => _isCancelling;
  bool get isLoaded              => _state == TrackingLoadState.loaded;

  // §1.6 polling fallback — runs every 15 s when socket is disconnected
  Timer?        _pollTimer;
  VoidCallback? _unsubOrderStatus; // returned by listenOrderStatus, called in dispose
  static const _pollInterval = Duration(seconds: 15);

  OrderTrackingProvider() {
    // Hook into Socket.io `order_status_update` events.
    // listenOrderStatus() returns an unsubscribe callback — store it for dispose().
    _unsubOrderStatus =
        SocketService.instance.listenOrderStatus(_handleSocketData);
  }

  void _handleSocketData(Map<String, dynamic> data) {
    try {
      final orderId  = (data['order_id'] ?? data['id']) as int?;
      final statusStr = (data['status'] ?? data['order_status']) as String?;
      if (orderId != null && statusStr != null) {
        _handleSocketUpdate(orderId, statusStr);
      }
    } catch (_) {}
  }

  // ── loadOrder ───────────────────────────────────────────────────────────────
  // Called by order_tracking_screen.dart on init and from notifications/orders list.
  // Loads detail + timeline in parallel. §1.6: timeline added.

  Future<void> loadOrder(int orderId) async {
    _state        = TrackingLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 700));
        _order    = OrderDetail.fromJson(kMockOrderDetail);
        _timeline = _buildMockTimeline(_order!);
      } else {
        // Parallel fetch — detail + timeline
        final results = await Future.wait([
          TrackingService.instance.fetchOrder(orderId),
          TrackingService.instance.fetchOrderTimeline(orderId),
        ]);
        _order    = results[0] as OrderDetail;
        _timeline = results[1] as OrderTimeline;
      }
      _state = TrackingLoadState.loaded;
      _startPollFallback(orderId); // §1.6: start polling after successful load
    } on TrackingApiException catch (e) {
      _errorMessage = e.message;
      _state        = TrackingLoadState.error;
    } catch (_) {
      _errorMessage = 'Could not load order. Please try again.';
      _state        = TrackingLoadState.error;
    }
    notifyListeners();
  }

  // ── Socket update handler ───────────────────────────────────────────────────
  // Called by Socket.io `order_status_update` — payload: { order_id, status }

  void _handleSocketUpdate(int orderId, String newStatus) {
    if (_order == null || _order!.id != orderId) return;

    final updated = OrderStatusX.fromString(newStatus);
    _order = OrderDetail(
      id:            _order!.id,
      orderNumber:   _order!.orderNumber,
      status:        updated,
      paymentMethod: _order!.paymentMethod,
      totalAmount:   _order!.totalAmount,
      items:         _order!.items,
      notes:         _order!.notes,
      delivery:      _order!.delivery,
      createdAt:     _order!.createdAt,
      updatedAt:     DateTime.now(),
    );

    // §1.6: refresh timeline from server so the stepper reflects the new step
    _refreshTimeline(orderId);
    notifyListeners();

    // Stop polling once terminal
    if (updated.isFinal) _stopPollFallback();
  }

  // §1.6: fetch fresh timeline (non-blocking — failure is silent)
  Future<void> _refreshTimeline(int orderId) async {
    try {
      if (!kUseMock) {
        _timeline = await TrackingService.instance.fetchOrderTimeline(orderId);
      } else {
        if (_order != null) _timeline = _buildMockTimeline(_order!);
      }
      notifyListeners();
    } catch (_) {}
  }

  // ── §1.6 Polling fallback ───────────────────────────────────────────────────
  // Runs every 15 s as a safety net when Socket.io is disconnected.

  void _startPollFallback(int orderId) {
    _stopPollFallback();
    if (_order?.status.isFinal ?? false) return; // nothing to poll
    _pollTimer = Timer.periodic(_pollInterval, (_) => _pollStatus(orderId));
  }

  void _stopPollFallback() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollStatus(int orderId) async {
    if (_order == null || _order!.status.isFinal) {
      _stopPollFallback();
      return;
    }
    try {
      if (kUseMock) return; // mock: socket simulation covers it
      final poll        = await TrackingService.instance.fetchOrderStatus(orderId);
      final pollStatus  = OrderStatusX.fromString(poll.status);
      if (pollStatus != _order!.status) {
        // Status changed between socket pings — do a full reload
        await loadOrder(orderId);
      }
    } catch (_) {
      // Silent — socket will cover it
    }
  }

  // ── Cancel order ────────────────────────────────────────────────────────────

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
        // Actual status change will arrive via Socket.io
      }
      _isCancelling = false;
      notifyListeners();
      return true;
    } on TrackingApiException catch (e) {
      _errorMessage  = e.message;
      _isCancelling  = false;
      notifyListeners();
      return false;
    }
  }

  // ── Refresh (pull-to-refresh / retry button) ────────────────────────────────

  Future<void> refresh() async {
    if (_order == null) return;
    await loadOrder(_order!.id);
  }

  // ── Mock timeline builder ───────────────────────────────────────────────────
  // Generates a plausible timeline from the mock OrderDetail status.

  OrderTimeline _buildMockTimeline(OrderDetail order) {
    final allStatuses = [
      ('pending',          'Order Placed'),
      ('confirmed',        'Order Confirmed'),
      ('preparing',        'Being Prepared'),
      ('ready',            'Ready for Pickup / Delivery'),
      ('out_for_delivery', 'Out for Delivery'),
      ('completed',        'Delivered'),
    ];

    final currentIdx = order.status.timelineIndex;
    final now        = DateTime.now();

    final steps = allStatuses.asMap().entries.map((e) {
      final idx        = e.key;
      final statusKey  = e.value.$1;
      final statusLabel = e.value.$2;
      final isCompleted = idx <= currentIdx;
      final isCurrent   = idx == currentIdx;

      return TimelineStep(
        status:      statusKey,
        label:       statusLabel,
        changedAt:   isCompleted
            ? now.subtract(Duration(minutes: (currentIdx - idx) * 5 + 2))
            : null,
        isCompleted: isCompleted,
        isCurrent:   isCurrent,
      );
    }).toList();

    if (order.status == OrderStatus.cancelled) {
      return OrderTimeline(
        orderId:       order.id,
        orderNumber:   order.orderNumber,
        currentStatus: 'cancelled',
        steps: [
          TimelineStep(
            status:      'pending',
            label:       'Order Placed',
            changedAt:   now.subtract(const Duration(minutes: 10)),
            isCompleted: true,
            isCurrent:   false,
          ),
          TimelineStep(
            status:      'cancelled',
            label:       'Cancelled',
            changedAt:   now,
            isCompleted: true,
            isCurrent:   true,
          ),
        ],
      );
    }

    return OrderTimeline(
      orderId:       order.id,
      orderNumber:   order.orderNumber,
      currentStatus: order.status.toString().split('.').last,
      steps:         steps,
    );
  }

  // ── Dispose ─────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stopPollFallback();
    _unsubOrderStatus?.call(); // unregister from socket listener list
    super.dispose();
  }
}