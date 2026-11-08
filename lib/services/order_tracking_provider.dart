import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/tracking_models.dart';
import '../mock/mock_data.dart';
import 'tracking_service.dart';
import 'socket_service.dart';

enum TrackingLoadState { initial, loading, loaded, error }

class OrderTrackingProvider extends ChangeNotifier {
  OrderDetail?    _order;
  OrderTimeline?  _timeline;
  RiderLocation?  _riderLocation;        // §1.9 NEW

  TrackingLoadState _state = TrackingLoadState.initial;
  String? _errorMessage;
  bool _isCancelling = false;

  OrderDetail?   get order          => _order;
  OrderTimeline? get timeline       => _timeline;
  RiderLocation? get riderLocation  => _riderLocation; // §1.9 NEW
  TrackingLoadState get state       => _state;
  String?        get errorMessage   => _errorMessage;
  bool get isCancelling             => _isCancelling;
  bool get isLoaded                 => _state == TrackingLoadState.loaded;

  // §1.9 — true when map should be shown (order is out_for_delivery + has fix)
  bool get showRiderMap =>
      _order?.status == OrderStatus.outForDelivery && _riderLocation != null;

  // ── Polling / Socket unsubs ───────────────────────────────────────────────
  Timer?        _pollTimer;
  Timer?        _locationPollTimer;        // §1.9 — location poll fallback
  VoidCallback? _unsubOrderStatus;
  VoidCallback? _unsubRiderLocation;      // §1.9 NEW

  static const _pollInterval         = Duration(seconds: 15);
  static const _locationPollInterval = Duration(seconds: 10); // §1.9

  OrderTrackingProvider() {
    _unsubOrderStatus =
        SocketService.instance.listenOrderStatus(_handleSocketData);
    _unsubRiderLocation =                               // §1.9 NEW
    SocketService.instance.listenRiderLocation(_handleRiderLocationData);
  }

  // ── Socket handlers ───────────────────────────────────────────────────────

  void _handleSocketData(Map<String, dynamic> data) {
    try {
      final orderId   = (data['order_id'] ?? data['id']) as int?;
      final statusStr = (data['status'] ?? data['order_status']) as String?;
      if (orderId != null && statusStr != null) {
        _handleSocketUpdate(orderId, statusStr);
      }
    } catch (_) {}
  }

  // §1.9 — called by Socket.io `rider_location_update`
  void _handleRiderLocationData(Map<String, dynamic> data) {
    try {
      if (_order == null) return;
      final orderId = (data['order_id'] as num?)?.toInt();
      if (orderId != _order!.id) return;

      _riderLocation = RiderLocation.fromJson({
        'order_id':  _order!.id,
        'rider_id':  data['rider_id'],
        'latitude':  data['latitude'],
        'longitude': data['longitude'],
        'accuracy':  data['accuracy'],
        'updated_at': data['updated_at'],
      });
      notifyListeners();
    } catch (_) {}
  }

  // ── loadOrder ─────────────────────────────────────────────────────────────

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
        final results = await Future.wait([
          TrackingService.instance.fetchOrder(orderId),
          TrackingService.instance.fetchOrderTimeline(orderId),
        ]);
        _order    = results[0] as OrderDetail;
        _timeline = results[1] as OrderTimeline;
      }
      _state = TrackingLoadState.loaded;
      _startPollFallback(orderId);

      // §1.9 — kick off rider location fetch if order is already out_for_delivery
      if (_order?.status == OrderStatus.outForDelivery) {
        await _fetchRiderLocation(orderId);
        _startLocationPoll(orderId);
      }
    } on TrackingApiException catch (e) {
      _errorMessage = e.message;
      _state        = TrackingLoadState.error;
    } catch (_) {
      _errorMessage = 'Could not load order. Please try again.';
      _state        = TrackingLoadState.error;
    }
    notifyListeners();
  }

  // ── Socket order status update ────────────────────────────────────────────

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

    _refreshTimeline(orderId);

    // §1.9 — start/stop location tracking based on new status
    if (updated == OrderStatus.outForDelivery) {
      _fetchRiderLocation(orderId);
      _startLocationPoll(orderId);
    } else {
      _stopLocationPoll();
      if (updated.isFinal) {
        _riderLocation = null; // clear map when order is done
      }
    }

    notifyListeners();
    if (updated.isFinal) _stopPollFallback();
  }

  // ── §1.9 Rider location helpers ───────────────────────────────────────────

  Future<void> _fetchRiderLocation(int orderId) async {
    if (kUseMock) {
      // Mock: place rider 300 m north of a fixed Manila coord
      _riderLocation = RiderLocation(
        orderId:   orderId,
        riderId:   1,
        latitude:  14.5995 + 0.003,
        longitude: 120.9842,
        accuracy:  10.0,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }
    try {
      final loc = await TrackingService.instance.fetchRiderLocation(orderId);
      if (loc != null) {
        _riderLocation = loc;
        notifyListeners();
      }
    } catch (_) {
      // Silent — socket will cover it
    }
  }

  void _startLocationPoll(int orderId) {
    _stopLocationPoll();
    _locationPollTimer = Timer.periodic(
      _locationPollInterval,
          (_) => _fetchRiderLocation(orderId),
    );
  }

  void _stopLocationPoll() {
    _locationPollTimer?.cancel();
    _locationPollTimer = null;
  }

  // ── Polling fallback (order status) ──────────────────────────────────────

  void _startPollFallback(int orderId) {
    _stopPollFallback();
    if (_order?.status.isFinal ?? false) return;
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
      if (kUseMock) return;
      final poll       = await TrackingService.instance.fetchOrderStatus(orderId);
      final pollStatus = OrderStatusX.fromString(poll.status);
      if (pollStatus != _order!.status) {
        await loadOrder(orderId);
      }
    } catch (_) {}
  }

  // ── Timeline refresh ──────────────────────────────────────────────────────

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

  // ── Cancel order ──────────────────────────────────────────────────────────

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

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> refresh() async {
    if (_order == null) return;
    await loadOrder(_order!.id);
  }

  // ── Mock timeline builder ─────────────────────────────────────────────────

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
      final idx         = e.key;
      final statusKey   = e.value.$1;
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

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _stopPollFallback();
    _stopLocationPoll();              // §1.9
    _unsubOrderStatus?.call();
    _unsubRiderLocation?.call();      // §1.9
    super.dispose();
  }
}