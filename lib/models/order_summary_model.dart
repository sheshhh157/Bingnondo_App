// ─── Order Summary (for list view) ───────────────────────────────────────────
// Lighter model than OrderDetail — only what's needed for the orders list.

import 'tracking_models.dart';

class OrderSummary {
  final int id;
  final String orderNumber;
  final OrderStatus status;
  final double totalAmount;
  final int itemCount;
  final String paymentMethod;
  final DateTime createdAt;

  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    required this.itemCount,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final statusStr = json['status'] as String? ?? 'pending';
    OrderStatus mappedStatus;
    switch (statusStr) {
      case 'confirmed': mappedStatus = OrderStatus.confirmed; break;
      case 'preparing': mappedStatus = OrderStatus.preparing; break;
      case 'ready':     mappedStatus = OrderStatus.ready; break;
      case 'out_for_delivery': mappedStatus = OrderStatus.outForDelivery; break;
      case 'completed': mappedStatus = OrderStatus.completed; break;
      case 'cancelled': mappedStatus = OrderStatus.cancelled; break;
      default:          mappedStatus = OrderStatus.pending;
    }

    return OrderSummary(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      status: mappedStatus,
      totalAmount: (json['total_amount'] as num).toDouble(),
      itemCount: json['item_count'] as int? ?? 0,
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isActive =>
      status != OrderStatus.completed && status != OrderStatus.cancelled;
}