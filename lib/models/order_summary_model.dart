// ─── Order Summary (for list view) ───────────────────────────────────────────
// Lighter model than OrderDetail — only what's needed for the orders list.

import 'tracking_models.dart';

// Postgres NUMERIC comes through JSON as a String ("250.00"); accept both.
double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

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
      id: _toInt(json['id']),
      orderNumber: json['order_number']?.toString() ?? '',
      status: mappedStatus,
      totalAmount: _toDouble(json['total_amount']),
      itemCount: _toInt(json['item_count']),
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isActive =>
      status != OrderStatus.completed && status != OrderStatus.cancelled;
}