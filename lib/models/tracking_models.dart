// ─── Order Status ─────────────────────────────────────────────────────────────

enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  outForDelivery,
  completed,
  cancelled,
}

extension OrderStatusX on OrderStatus {
  static OrderStatus fromString(String v) {
    switch (v) {
      case 'confirmed':       return OrderStatus.confirmed;
      case 'preparing':       return OrderStatus.preparing;
      case 'ready':           return OrderStatus.ready;
      case 'out_for_delivery':return OrderStatus.outForDelivery;
      case 'completed':       return OrderStatus.completed;
      case 'cancelled':       return OrderStatus.cancelled;
      default:                return OrderStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:        return 'Pending';
      case OrderStatus.confirmed:      return 'Confirmed';
      case OrderStatus.preparing:      return 'Preparing';
      case OrderStatus.ready:          return 'Ready';
      case OrderStatus.outForDelivery: return 'Out for Delivery';
      case OrderStatus.completed:      return 'Completed';
      case OrderStatus.cancelled:      return 'Cancelled';
    }
  }

  String get description {
    switch (this) {
      case OrderStatus.pending:
        return 'Waiting for confirmation';
      case OrderStatus.confirmed:
        return 'Order confirmed, payment received';
      case OrderStatus.preparing:
        return 'Kitchen is preparing your food';
      case OrderStatus.ready:
        return 'Food is ready — assigning rider';
      case OrderStatus.outForDelivery:
        return 'Rider is on the way to you';
      case OrderStatus.completed:
        return 'Order delivered. Enjoy!';
      case OrderStatus.cancelled:
        return 'Order was cancelled';
    }
  }

  // Index in timeline (0-based, excluding cancelled)
  int get timelineIndex {
    switch (this) {
      case OrderStatus.pending:        return 0;
      case OrderStatus.confirmed:      return 1;
      case OrderStatus.preparing:      return 2;
      case OrderStatus.ready:          return 3;
      case OrderStatus.outForDelivery: return 4;
      case OrderStatus.completed:      return 5;
      case OrderStatus.cancelled:      return -1;
    }
  }

  bool get isFinal =>
      this == OrderStatus.completed || this == OrderStatus.cancelled;
  bool get canCancel => this == OrderStatus.pending;
}

// ─── Ordered Item (within order detail) ───────────────────────────────────────

class OrderedItem {
  final int menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final String? note;

  const OrderedItem({
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.note,
  });

  double get subtotal => unitPrice * quantity;

  factory OrderedItem.fromJson(Map<String, dynamic> json) => OrderedItem(
    menuItemId: json['menu_item_id'] as int,
    name: json['name'] as String,
    quantity: json['quantity'] as int,
    unitPrice: (json['unit_price'] as num).toDouble(),
    note: json['note'] as String?,
  );
}

// ─── Delivery Info ─────────────────────────────────────────────────────────────

class DeliveryInfo {
  final String preference; // 'own_delivery' | 'lalamove'
  final String status;
  final String? riderName;
  final String? riderContact;
  final String? lalamoveBookingId;

  const DeliveryInfo({
    required this.preference,
    required this.status,
    this.riderName,
    this.riderContact,
    this.lalamoveBookingId,
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) => DeliveryInfo(
    preference: json['preference'] as String? ?? 'own_delivery',
    status: json['status'] as String? ?? 'pending_assignment',
    riderName: json['rider_name'] as String?,
    riderContact: json['rider_contact'] as String?,
    lalamoveBookingId: json['lalamove_booking_id'] as String?,
  );

  bool get isLalamove => preference == 'lalamove';
  bool get hasRider => riderName != null || lalamoveBookingId != null;
}

// ─── Order Detail ─────────────────────────────────────────────────────────────

class OrderDetail {
  final int id;
  final String orderNumber;
  final OrderStatus status;
  final String paymentMethod;
  final double totalAmount;
  final List<OrderedItem> items;
  final String? notes;
  final DeliveryInfo? delivery;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.totalAmount,
    required this.items,
    this.notes,
    this.delivery,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    
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

    return OrderDetail(
      id: json['id'] as int,
      orderNumber: json['order_number'] as String,
      status: mappedStatus,
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      totalAmount: (json['total_amount'] as num).toDouble(),
      items: rawItems
          .map((i) => OrderedItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      delivery: json['delivery'] != null
          ? DeliveryInfo.fromJson(json['delivery'] as Map<String, dynamic>)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}

// ─── Support Chat Models ───────────────────────────────────────────────────────

enum ChatStatus { unlocked, locked }

class SupportMessage {
  final int id;
  final String content;
  final bool isFromCustomer;
  final int? relatedOrderId;
  final DateTime sentAt;
  final bool isRead;

  const SupportMessage({
    required this.id,
    required this.content,
    required this.isFromCustomer,
    this.relatedOrderId,
    required this.sentAt,
    this.isRead = false,
  });

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
    id: json['id'] as int,
    content: json['content'] as String,
    isFromCustomer: json['sender_type'] == 'customer',
    relatedOrderId: json['related_order_id'] as int?,
    sentAt: DateTime.parse(json['sent_at'] as String),
    isRead: json['is_read'] as bool? ?? false,
  );
}

class SupportChat {
  final int id;
  final ChatStatus status;
  final List<SupportMessage> messages;
  final int? activeOrderId;

  const SupportChat({
    required this.id,
    required this.status,
    required this.messages,
    this.activeOrderId,
  });

  factory SupportChat.fromJson(Map<String, dynamic> json) {
    final msgs = (json['messages'] as List<dynamic>? ?? [])
        .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
        .toList();
    return SupportChat(
      id: json['id'] as int,
      status: (json['status'] as String?) == 'locked'
          ? ChatStatus.locked
          : ChatStatus.unlocked,
      messages: msgs,
      activeOrderId: json['active_order_id'] as int?,
    );
  }

  bool get isLocked => status == ChatStatus.locked;
}