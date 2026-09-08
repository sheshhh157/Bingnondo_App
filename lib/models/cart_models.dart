// ─── Cart Models ──────────────────────────────────────────────────────────────

class CartItem {
  final int menuItemId;
  final String name;
  final double price;
  final String? photoUrl;
  int quantity;
  String? note; // per-item note

  CartItem({
    required this.menuItemId,
    required this.name,
    required this.price,
    this.photoUrl,
    this.quantity = 1,
    this.note,
  });

  double get subtotal => price * quantity;

  CartItem copyWith({int? quantity, String? note}) {
    return CartItem(
      menuItemId: menuItemId,
      name: name,
      price: price,
      photoUrl: photoUrl,
      quantity: quantity ?? this.quantity,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toOrderJson() => {
    'menu_item_id': menuItemId,
    'quantity': quantity,
    'unit_price': price,
    if (note != null && note!.isNotEmpty) 'note': note,
  };
}

// ─── Delivery Preference ──────────────────────────────────────────────────────

enum DeliveryPreference { ownDelivery, lalamove }

extension DeliveryPreferenceX on DeliveryPreference {
  String get label {
    switch (this) {
      case DeliveryPreference.ownDelivery:
        return 'Cafe Delivery';
      case DeliveryPreference.lalamove:
        return 'Lalamove';
    }
  }

  String get description {
    switch (this) {
      case DeliveryPreference.ownDelivery:
        return 'Rider arranged by Bingnondo Cafe';
      case DeliveryPreference.lalamove:
        return 'Book a Lalamove rider';
    }
  }

  String get apiValue {
    switch (this) {
      case DeliveryPreference.ownDelivery:
        return 'own_delivery';
      case DeliveryPreference.lalamove:
        return 'lalamove';
    }
  }
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
        return 'Pay securely via GCash (PayMongo)';
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

  bool get canOrder => this != RestrictionLevel.suspended;
  bool get canUseCod => this != RestrictionLevel.codRestricted && this != RestrictionLevel.suspended;
}

// ─── Customer Profile (needed for gate check) ─────────────────────────────────

class CustomerProfile {
  final int id;
  final String email;
  final bool profileCompleted;
  final String? firstName;
  final String? lastName;
  final String? mobileNumber;
  final String? address;
  final RestrictionLevel restrictionLevel;

  const CustomerProfile({
    required this.id,
    required this.email,
    required this.profileCompleted,
    this.firstName,
    this.lastName,
    this.mobileNumber,
    this.address,
    this.restrictionLevel = RestrictionLevel.none,
  });

  factory CustomerProfile.fromJson(Map<String, dynamic> json) {
    return CustomerProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      address: json['address'] as String?,
      restrictionLevel: RestrictionLevelX.fromString(
        json['restriction_level'] as String?,
      ),
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return email;
  }
}

// ─── Place Order Request / Response ───────────────────────────────────────────

class PlaceOrderRequest {
  final List<CartItem> items;
  final DeliveryPreference deliveryPreference;
  final PaymentMethod paymentMethod;
  final String? orderNotes;

  const PlaceOrderRequest({
    required this.items,
    required this.deliveryPreference,
    required this.paymentMethod,
    this.orderNotes,
  });

  Map<String, dynamic> toJson() => {
    'order_type': 'online',
    'order_channel': 'mobile_app',
    'delivery_preference': deliveryPreference.apiValue,
    'payment_method': paymentMethod.apiValue,
    'items': items.map((i) => i.toOrderJson()).toList(),
    if (orderNotes != null && orderNotes!.isNotEmpty) 'notes': orderNotes,
  };
}

class PlaceOrderResponse {
  final int orderId;
  final String orderNumber;
  final String status;
  final double totalAmount;
  final String? paymentUrl; // GCash PayMongo redirect URL

  const PlaceOrderResponse({
    required this.orderId,
    required this.orderNumber,
    required this.status,
    required this.totalAmount,
    this.paymentUrl,
  });

  factory PlaceOrderResponse.fromJson(Map<String, dynamic> json) {
    return PlaceOrderResponse(
      orderId: json['id'] as int,
      orderNumber: json['order_number'] as String,
      status: json['status'] as String,
      totalAmount: (json['total_amount'] as num).toDouble(),
      paymentUrl: json['payment_url'] as String?,
    );
  }
}