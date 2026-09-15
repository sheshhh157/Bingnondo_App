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
      case 'order_preparing':        return NotificationType.orderPreparing;
      case 'order_ready':            return NotificationType.orderReady;
      case 'order_out_for_delivery': return NotificationType.orderOutForDelivery;
      case 'order_completed':        return NotificationType.orderCompleted;
      case 'order_cancelled':        return NotificationType.orderCancelled;
      case 'payment_received':       return NotificationType.paymentReceived;
      case 'payment_failed':         return NotificationType.paymentFailed;
      case 'support_message':        return NotificationType.supportMessage;
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
    return AppNotification(
      id: json['id'] as int,
      type: NotificationTypeX.fromString(json['type'] as String),
      message: json['message'] as String,
      isRead: json['is_read'] as bool? ?? false,
      relatedOrderId: json['related_order_id'] as int?,
      relatedOrderNumber: json['related_order_number'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ─── §1.9 Account Settings Models ─────────────────────────────────────────────

class AccountProfile {
  final int id;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? mobileNumber;
  final String? address;
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
    this.profileCompleted = false,
    this.hasSavedPayment = false,
    this.savedPaymentLast4,
    this.savedPaymentType,
  });

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      mobileNumber: json['mobile_number'] as String?,
      address: json['address'] as String?,
      profileCompleted: json['profile_completed'] as bool? ?? false,
      hasSavedPayment: json['has_saved_payment'] as bool? ?? false,
      savedPaymentLast4: json['saved_payment_last4'] as String?,
      savedPaymentType: json['saved_payment_type'] as String?,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) return '$firstName $lastName';
    if (firstName != null) return firstName!;
    return email;
  }

  String get initials {
    if (firstName != null && lastName != null) {
      return '${firstName![0]}${lastName![0]}'.toUpperCase();
    }
    if (firstName != null) return firstName![0].toUpperCase();
    return email[0].toUpperCase();
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

  const UpdateProfileRequest({
    required this.firstName,
    required this.lastName,
    this.mobileNumber,
    this.address,
  });

  Map<String, dynamic> toJson() => {
    'first_name': firstName,
    'last_name': lastName,
    if (mobileNumber != null) 'mobile_number': mobileNumber,
    if (address != null) 'address': address,
  };
}