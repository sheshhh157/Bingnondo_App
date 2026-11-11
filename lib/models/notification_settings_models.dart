// ─── §1.8 Notification Models ─────────────────────────────────────────────────

enum NotificationType {
  orderConfirmed,
  orderPreparing,
  orderReady,
  orderOutForDelivery,
  orderCompleted,
  orderCancelled,
  paymentReceived,
  paymentFailed,
  supportMessage,
  system,
}

extension NotificationTypeX on NotificationType {
  static NotificationType fromString(String v) {
    switch (v) {
      case 'order_confirmed':        return NotificationType.orderConfirmed;
      case 'order_pending':          return NotificationType.orderConfirmed;
      case 'pending':                return NotificationType.orderConfirmed;
      case 'order_preparing':        return NotificationType.orderPreparing;
      case 'order_ready':            return NotificationType.orderReady;
      case 'order_out_for_delivery': return NotificationType.orderOutForDelivery;
      case 'out_for_delivery':       return NotificationType.orderOutForDelivery;
      case 'order_completed':        return NotificationType.orderCompleted;
      case 'completed':              return NotificationType.orderCompleted;
      case 'order_cancelled':        return NotificationType.orderCancelled;
      case 'cancelled':              return NotificationType.orderCancelled;
      case 'payment_received':       return NotificationType.paymentReceived;
      case 'payment_verified':       return NotificationType.paymentReceived;
      case 'approved':               return NotificationType.paymentReceived;
      case 'payment_failed':         return NotificationType.paymentFailed;
      case 'rejected':               return NotificationType.paymentFailed;
      case 'payment_rejected':       return NotificationType.paymentFailed;
      case 'support_message':        return NotificationType.supportMessage;
      case 'order_status':           return NotificationType.orderConfirmed; // fallback
      case 'payment_status':         return NotificationType.paymentReceived;
      default:                       return NotificationType.system;
    }
  }

  String get title {
    switch (this) {
      case NotificationType.orderConfirmed:       return 'Order Confirmed';
      case NotificationType.orderPreparing:       return 'Being Prepared';
      case NotificationType.orderReady:           return 'Ready for Delivery';
      case NotificationType.orderOutForDelivery:  return 'Rider is On the Way';
      case NotificationType.orderCompleted:       return 'Order Delivered';
      case NotificationType.orderCancelled:       return 'Order Cancelled';
      case NotificationType.paymentReceived:      return 'Payment Received';
      case NotificationType.paymentFailed:        return 'Payment Failed';
      case NotificationType.supportMessage:       return 'New Message from Staff';
      case NotificationType.system:               return 'Bingnondo';
    }
  }

  // Which icon painter to use — index maps to _NotifIconPainter types
  int get iconIndex {
    switch (this) {
      case NotificationType.orderConfirmed:
      case NotificationType.orderPreparing:
      case NotificationType.orderReady:
      case NotificationType.orderOutForDelivery:
      case NotificationType.orderCompleted:
      case NotificationType.orderCancelled:
        return 0; // order icon
      case NotificationType.paymentReceived:
      case NotificationType.paymentFailed:
        return 1; // payment icon
      case NotificationType.supportMessage:
        return 2; // chat icon
      case NotificationType.system:
        return 3; // lantern icon
    }
  }

  bool get isOrderRelated {
    return this == NotificationType.orderConfirmed ||
        this == NotificationType.orderPreparing ||
        this == NotificationType.orderReady ||
        this == NotificationType.orderOutForDelivery ||
        this == NotificationType.orderCompleted ||
        this == NotificationType.orderCancelled;
  }
}

class AppNotification {
  final int id;
  final NotificationType type;
  final String message;
  final bool isRead;
  final int? relatedOrderId;
  final String? relatedOrderNumber;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    required this.message,
    required this.isRead,
    this.relatedOrderId,
    this.relatedOrderNumber,
    required this.createdAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final int? relatedId = json['related_order_id'] as int? ??
        json['reference_id'] as int? ??
        json['order_id'] as int? ??
        (json['relatedOrderId'] as int?);
    final String? relatedNum = json['related_order_number'] as String? ??
        json['order_number'] as String? ??
        (json['relatedOrderNumber'] as String?);
    String typeStr = json['type'] as String? ?? json['event'] as String? ?? 'system';
    if (typeStr == 'order_status_update' || typeStr == 'order_status') {
      final status = (json['status'] as String?)?.toLowerCase();
      if (status != null) {
        switch (status) {
          case 'confirmed':
            typeStr = 'order_confirmed';
            break;
          case 'preparing':
            typeStr = 'order_preparing';
            break;
          case 'ready':
            typeStr = 'order_ready';
            break;
          case 'out_for_delivery':
            typeStr = 'order_out_for_delivery';
            break;
          case 'completed':
            typeStr = 'order_completed';
            break;
          case 'cancelled':
            typeStr = 'order_cancelled';
            break;
          default:
            break;
        }
      }
    } else if (typeStr == 'payment:verified' || typeStr == 'payment_verified') {
      typeStr = 'payment_received';
    } else if (typeStr == 'payment:rejected' || typeStr == 'payment_rejected') {
      typeStr = 'payment_failed';
    }
    return AppNotification(
      id: json['id'] as int,
      type: NotificationTypeX.fromString(typeStr),
      message: json['message'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      relatedOrderId: relatedId,
      relatedOrderNumber: relatedNum,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ─── §1.9 Account Settings Models ─────────────────────────────────────────────

class AccountProfile {
  final int id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? mobileNumber;
  final String? address;
  final double? latitude;
  final double? longitude;
  final bool profileCompleted;
  final bool hasSavedPayment;
  final String? savedPaymentLast4;
  final String? savedPaymentType; // 'gcash' | 'card'

  const AccountProfile({
    required this.id,
    required this.email,
    this.firstName,
    this.lastName,
    this.mobileNumber,
    this.address,
    this.latitude,
    this.longitude,
    this.profileCompleted = false,
    this.hasSavedPayment = false,
    this.savedPaymentLast4,
    this.savedPaymentType,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    final lat = json['latitude'];
    final lng = json['longitude'];
    return AccountProfile(
      id: json['id'] as int,
      email: json['email'] as String?,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      address: json['address'] as String?,
      latitude: lat is num ? lat.toDouble() : null,
      longitude: lng is num ? lng.toDouble() : null,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      hasSavedPayment: json['has_saved_payment'] as bool? ?? false,
      savedPaymentLast4: json['saved_payment_last4'] as String?,
      savedPaymentType: json['saved_payment_type'] as String?,
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
    return mobileNumber ?? 'Complete your profile';
  }

  String get initials {
    final first = firstName?.trim();
    final last = lastName?.trim();
    if (first != null && first.isNotEmpty && last != null && last.isNotEmpty) {
      return '${first[0]}${last[0]}'.toUpperCase();
    }
    if (first != null && first.isNotEmpty) return first[0].toUpperCase();
    final contactEmail = email?.trim();
    if (contactEmail != null && contactEmail.isNotEmpty) {
      return contactEmail[0].toUpperCase();
    }
    return 'M';
  }
}

class ChangePasswordRequest {
  final String currentPassword;
  final String newPassword;

  const ChangePasswordRequest({
    required this.currentPassword,
    required this.newPassword,
  });

  Map<String, dynamic> toJson() => {
    'current_password': currentPassword,
    'new_password': newPassword,
  };
}

class UpdateProfileRequest {
  final String firstName;
  final String lastName;
  final String? mobileNumber;
  final String? address;
  final double? latitude;
  final double? longitude;

  const UpdateProfileRequest({
    required this.firstName,
    required this.lastName,
    this.mobileNumber,
    this.address,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    if (mobileNumber != null) 'mobile_number': mobileNumber,
    if (address != null) 'address': address,
    if (latitude != null) 'latitude': latitude,
    if (longitude != null) 'longitude': longitude,
  };
}