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
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'ready_for_pickup':
        return OrderStatus.ready;
      case 'out_for_delivery':
        return OrderStatus.outForDelivery;
      case 'picked_up':
        return OrderStatus.completed;
      case 'delivered':
        return OrderStatus.completed;
      case 'completed':
        return OrderStatus.completed;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.outForDelivery:
        return 'Out for Delivery';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
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

  int get timelineIndex {
    switch (this) {
      case OrderStatus.pending:
        return 0;
      case OrderStatus.confirmed:
        return 1;
      case OrderStatus.preparing:
        return 2;
      case OrderStatus.ready:
        return 3;
      case OrderStatus.outForDelivery:
        return 4;
      case OrderStatus.completed:
        return 5;
      case OrderStatus.cancelled:
        return -1;
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
    menuItemId: json['menu_item_id'] as int? ?? json['id'] as int? ?? 0,
    name: json['name'] as String? ?? 'Item',
    quantity: json['quantity'] as int? ?? 1,
    unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
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
  final String? deliveryAddress;
  final double? destinationLatitude;
  final double? destinationLongitude;

  const DeliveryInfo({
    required this.preference,
    required this.status,
    this.riderName,
    this.riderContact,
    this.lalamoveBookingId,
    this.deliveryAddress,
    this.destinationLatitude,
    this.destinationLongitude,
  });

  factory DeliveryInfo.fromJson(Map<String, dynamic> json) => DeliveryInfo(
    preference: json['preference'] as String? ?? 'own_delivery',
    status: json['status'] as String? ?? 'pending_assignment',
    riderName: json['rider_name'] as String?,
    riderContact: json['rider_contact'] as String?,
    lalamoveBookingId: json['lalamove_booking_id'] as String?,
    deliveryAddress:
        json['delivery_address'] as String? ?? json['address'] as String?,
    destinationLatitude: _parseCoordinate(
      json['delivery_latitude'] ??
          json['destination_latitude'] ??
          json['latitude'],
    ),
    destinationLongitude: _parseCoordinate(
      json['delivery_longitude'] ??
          json['destination_longitude'] ??
          json['longitude'],
    ),
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
  final String? paymentStatus;
  final String? rejectionReason;
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
    this.paymentStatus,
    this.rejectionReason,
    required this.totalAmount,
    required this.items,
    this.notes,
    this.delivery,
    required this.createdAt,
    this.updatedAt,
  });

  bool get isGcash => paymentMethod.toLowerCase() == 'gcash';
  bool get isPaymentRejected => paymentStatus == 'rejected';

  factory OrderDetail.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];

    final statusStr = json['status'] as String? ?? 'pending';
    OrderStatus mappedStatus = OrderStatusX.fromString(statusStr);
    final rawDelivery = json['delivery'];
    final deliveryData = rawDelivery is Map<String, dynamic>
        ? rawDelivery
        : null;
    final hasDeliveryData =
        deliveryData != null ||
        json.containsKey('delivery_address') ||
        json.containsKey('delivery_latitude') ||
        json.containsKey('delivery_longitude');
    final deliveryJson = <String, dynamic>{
      ...json,
      ...?deliveryData,
    };

    return OrderDetail(
      id: json['id'] as int? ?? 0,
      orderNumber: json['order_number'] as String? ?? 'BNG-00000000-0000',
      status: mappedStatus,
      paymentMethod: json['payment_method'] as String? ?? 'cod',
      paymentStatus: json['payment_status'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0.0,
      items: rawItems
          .map((i) => OrderedItem.fromJson(i as Map<String, dynamic>))
          .toList(),
      notes: json['notes'] as String?,
      delivery: hasDeliveryData ? DeliveryInfo.fromJson(deliveryJson) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

double? _parseCoordinate(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
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
    id: json['id'] as int? ?? 0,
    content: json['content'] as String? ?? '',
    isFromCustomer: json['sender_type'] == 'customer',
    relatedOrderId: json['related_order_id'] as int?,
    sentAt: json['sent_at'] != null
        ? DateTime.tryParse(json['sent_at'] as String) ?? DateTime.now()
        : DateTime.now(),
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
      id: json['id'] as int? ?? 0,
      status: (json['status'] as String?) == 'locked'
          ? ChatStatus.locked
          : ChatStatus.unlocked,
      messages: msgs,
      activeOrderId: json['active_order_id'] as int?,
    );
  }

  bool get isLocked => status == ChatStatus.locked;
}

// ─── Timeline Models ──────────────────────────────────────────────────────────

class TimelineStep {
  final String status;
  final String label;
  final DateTime? changedAt;
  final bool isCompleted;
  final bool isCurrent;

  const TimelineStep({
    required this.status,
    required this.label,
    this.changedAt,
    required this.isCompleted,
    required this.isCurrent,
  });

  factory TimelineStep.fromJson(Map<String, dynamic> json) => TimelineStep(
    status: json['status'] as String? ?? 'pending',
    label: json['label'] as String? ?? 'Step',
    changedAt: json['changed_at'] != null
        ? DateTime.tryParse(json['changed_at'] as String)
        : null,
    isCompleted: json['is_completed'] as bool? ?? false,
    isCurrent: json['is_current'] as bool? ?? false,
  );
}

class OrderTimeline {
  final int orderId;
  final String orderNumber;
  final String currentStatus;
  final String? deliveryPreference;
  final List<TimelineStep> steps;

  const OrderTimeline({
    required this.orderId,
    required this.orderNumber,
    required this.currentStatus,
    this.deliveryPreference,
    required this.steps,
  });

  factory OrderTimeline.fromJson(Map<String, dynamic> json) {
    final delivery = json['delivery'] as Map<String, dynamic>?;
    return OrderTimeline(
      orderId: json['order_id'] as int? ?? 0,
      orderNumber: json['order_number'] as String? ?? '',
      currentStatus: json['current_status'] as String? ?? 'pending',
      deliveryPreference:
          json['delivery_preference'] as String? ??
          delivery?['preference'] as String?,
      steps: (json['timeline'] as List<dynamic>? ?? [])
          .map((e) => TimelineStep.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  TimelineStep? get currentStep => steps.where((s) => s.isCurrent).firstOrNull;
}

class OrderStatusPoll {
  final int id;
  final String status;
  final bool canCancel;
  final String? paymentStatus;

  const OrderStatusPoll({
    required this.id,
    required this.status,
    required this.canCancel,
    this.paymentStatus,
  });

  factory OrderStatusPoll.fromJson(Map<String, dynamic> json) =>
      OrderStatusPoll(
        id: json['id'] as int? ?? 0,
        status: json['status'] as String? ?? 'pending',
        canCancel: json['can_cancel'] as bool? ?? false,
        paymentStatus: json['payment_status'] as String?,
      );
}

// ─── §1.9 Rider Live Location Model ───────────────────────────────────────────

class RiderLocation {
  final int orderId;
  final int riderId;
  final double latitude;
  final double longitude;
  final double? accuracy;
  final DateTime? updatedAt;

  const RiderLocation({
    required this.orderId,
    required this.riderId,
    required this.latitude,
    required this.longitude,
    this.accuracy,
    this.updatedAt,
  });

  factory RiderLocation.fromJson(Map<String, dynamic> json) => RiderLocation(
    orderId: json['order_id'] as int? ?? 0,
    riderId: json['rider_id'] as int? ?? 0,
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    accuracy: json['accuracy'] != null
        ? (json['accuracy'] as num).toDouble()
        : null,
    updatedAt: json['updated_at'] != null
        ? DateTime.tryParse(json['updated_at'] as String)
        : null,
  );
}
