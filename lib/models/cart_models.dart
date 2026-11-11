// ─── Cart Models ──────────────────────────────────────────────────────────────

class CartItem {
  final int menuItemId;
  final String name;
  final double price;
  final String? photoUrl;
  int quantity;
  String? note; // per-item note
  // Variant selection — null means no variant chosen / item has no variants.
  final int? variantId;
  final String? variantName;

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.photoUrl,
    this.quantity = 1,
    this.note,
    this.variantId,
    this.variantName,
  });

  double get subtotal => price * quantity;

  CartItem copyWith({int? quantity, String? note}) {
    return CartItem(
      menuItemId:  menuItemId,
      name:        name,
      price:       price,
      photoUrl:    photoUrl,
      quantity:    quantity ?? this.quantity,
      note:        note ?? this.note,
      variantId:   variantId,
      variantName: variantName,
    );
  }

  Map<String, dynamic> toOrderJson() => {
    'menu_item_id': menuItemId,
    'quantity':     quantity,
    'unit_price':   price,
    if (variantId != null)                       'variant_id':   variantId,
    if (variantName != null)                     'variant_name': variantName,
    if (note != null && note!.isNotEmpty)        'note':         note,
  };
}

// ─── Payment Method ───────────────────────────────────────────────────────────

enum PaymentMethod { gcash, cod }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.gcash:
        return 'GCash';
      case PaymentMethod.cod:
        return 'Cash on Delivery';
    }
  }

  String get description {
    switch (this) {
      case PaymentMethod.gcash:
        return 'Pay securely via GCash';
      case PaymentMethod.cod:
        return 'Pay cash when your order arrives';
    }
  }

  String get apiValue {
    switch (this) {
      case PaymentMethod.gcash:
        return 'gcash';
      case PaymentMethod.cod:
        return 'cod';
    }
  }
}

// ─── Customer Restriction Level ───────────────────────────────────────────────

enum RestrictionLevel { none, warned, codRestricted, suspended }

extension RestrictionLevelX on RestrictionLevel {
  static RestrictionLevel fromString(String? value) {
    switch (value) {
      case 'warned':
        return RestrictionLevel.warned;
      case 'cod_restricted':
        return RestrictionLevel.codRestricted;
      case 'suspended':
        return RestrictionLevel.suspended;
      default:
        return RestrictionLevel.none;
    }
  }

  bool get canOrder  => this != RestrictionLevel.suspended;
  bool get canUseCod => this != RestrictionLevel.codRestricted && this != RestrictionLevel.suspended;
}

// ─── Customer Profile (needed for gate check) ─────────────────────────────────

class CustomerProfile {
  final int id;
  final String? email;
  final bool profileCompleted;
  final String? firstName;
  final String? lastName;
  final String? mobileNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
  final RestrictionLevel restrictionLevel;

  const CustomerProfile({
    required this.id,
    required this.email,
    required this.profileCompleted,
    this.firstName,
    this.lastName,
    this.mobileNumber,
    this.address,
    this.latitude,
    this.longitude,
    this.restrictionLevel = RestrictionLevel.none,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    return CustomerProfile(
      id:               json['id'] as int,
      email:            json['email'] as String?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      firstName:        json['first_name'] as String?,
      lastName:         json['last_name'] as String?,
      mobileNumber:     json['mobile_number'] as String?,
      address:          json['address'] as String?,
      latitude:         lat is num ? lat.toDouble() : null,
      longitude:        lng is num ? lng.toDouble() : null,
      restrictionLevel: RestrictionLevelX.fromString(
        json['restriction_level'] as String?,
      ),
    );
  }

  String get displayName {
    final first = firstName?.trim();
    final last = lastName?.trim();
    if (first != null && first.isNotEmpty && last != null && last.isNotEmpty) {
      return '$first $last';
    }
    if (first != null && first.isNotEmpty) return first;
    final contactEmail = email?.trim();
    if (contactEmail != null && contactEmail.isNotEmpty) return contactEmail;
    return mobileNumber ?? 'Customer';
  }
}

// ─── Place Order Request / Response ───────────────────────────────────────────

class PlaceOrderRequest {
  final List<CartItem> items;
  final PaymentMethod  paymentMethod;
  final String?        orderNotes;
  // GCash only — from extract-receipt step
  final String?        gcashReceiptTempUrl;
  final String?        gcashRefNumber;
  final double?        gcashAmountSent;
  // Per-order delivery pin (chosen / changed at checkout)
  final String?        deliveryAddress;
  final double?        deliveryLatitude;
  final double?        deliveryLongitude;
  // Delivery fee snapshot
  final double?        deliveryFee;
  // 'own_delivery' (default) or 'pickup' (when no riders are online).
  // CartProvider sets this automatically based on ridersAvailable.
  final String         deliveryPreference;

  const PlaceOrderRequest({
    required this.items,
    required this.paymentMethod,
    this.orderNotes,
    this.gcashReceiptTempUrl,
    this.gcashRefNumber,
    this.gcashAmountSent,
    this.deliveryAddress,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.deliveryFee,
    this.deliveryPreference = 'own_delivery',   // ← default unchanged
  });

  Map<String, dynamic> toJson() => {
    'order_type':          'online',
    'order_channel':       'mobile_app',
    'delivery_preference': deliveryPreference,  // ← was hardcoded 'own_delivery'
    'payment_method':      paymentMethod.apiValue,
    'items':               items.map((i) => i.toOrderJson()).toList(),
    if (orderNotes != null && orderNotes!.isNotEmpty)
      'notes': orderNotes,
    if (gcashReceiptTempUrl != null)
      'gcash_receipt_temp_url': gcashReceiptTempUrl,
    if (gcashRefNumber != null)
      'gcash_ref_number': gcashRefNumber,
    if (gcashAmountSent != null)
      'gcash_amount_sent': gcashAmountSent,
    if (deliveryAddress != null && deliveryAddress!.trim().isNotEmpty)
      'delivery_address': deliveryAddress,
    if (deliveryLatitude != null)
      'delivery_latitude': deliveryLatitude,
    if (deliveryLongitude != null)
      'delivery_longitude': deliveryLongitude,
    if (deliveryFee != null)
      'delivery_fee': deliveryFee,
  };
}

class PlaceOrderResponse {
  final int orderId;
  final String orderNumber;
  final String status;
  final double subtotal;
  final double deliveryFee;
  final double totalAmount;
  final String? paymentUrl;

  const PlaceOrderResponse({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.subtotal,
    required this.deliveryFee,
    required this.totalAmount,
    this.paymentUrl,
  });

  factory PlaceOrderResponse.fromJson(Map<String, dynamic> json) {
    final subtotal    = (json['subtotal']     as num?)?.toDouble() ?? (json['total_amount'] as num).toDouble();
    final deliveryFee = (json['delivery_fee'] as num?)?.toDouble() ?? 0.0;
    final total       = (json['total_amount'] as num).toDouble();
    return PlaceOrderResponse(
      orderId:     json['id'] as int,
      orderNumber: json['order_number'] as String,
      status:      json['status'] as String,
      subtotal:    subtotal,
      deliveryFee: deliveryFee,
      totalAmount: total,
      paymentUrl:  json['payment_url'] as String?,
    );
  }
}