import 'package:flutter/foundation.dart';
import '../models/cart_models.dart';
import '../models/geo_models.dart';
import '../models/menu_models.dart';
import '../mock/mock_data.dart';
import 'cart_service.dart';
import 'gcash_receipt_service.dart';

// delivery step removed — checkout is now: cart → payment → placing → confirmation
enum CheckoutStep { cart, payment, placing, confirmation }

enum CartError { none, profileIncomplete, suspended, itemUnavailable, network }

class CartProvider extends ChangeNotifier {
  // ─── Cart items ────────────────────────────────────────────────────────────
  final List<CartItem> _items = [];
  String? _orderNotes;

  List<CartItem> get items      => List.unmodifiable(_items);
  String? get orderNotes        => _orderNotes;
  bool get isEmpty              => _items.isEmpty;
  int get totalItemCount        => _items.fold(0, (sum, i) => sum + i.quantity);
  double get subtotal           => _items.fold(0, (sum, i) => sum + i.subtotal);
  double get totalAmount        => subtotal;

  // ─── Checkout state ────────────────────────────────────────────────────────
  CheckoutStep        _step          = CheckoutStep.cart;
  PaymentMethod       _paymentMethod = PaymentMethod.gcash;
  CustomerProfile?    _profile;
  PlaceOrderResponse? _lastOrder;
  CartError           _error         = CartError.none;
  String?             _errorMessage;
  bool                _isLoading     = false;

  // Delivery pin for this order. Defaults to the saved profile address and can
  // be changed on the checkout page (pin-drop picker).
  PickedAddress? _deliveryAddress;
  bool           _saveAddressToProfile = false;

  // GCash receipt extract result — set after extract-receipt, cleared on place/reset
  GcashExtractResult? _gcashExtractResult;

  CheckoutStep        get step               => _step;
  PaymentMethod       get paymentMethod      => _paymentMethod;
  CustomerProfile?    get profile            => _profile;
  PlaceOrderResponse? get lastOrder          => _lastOrder;
  CartError           get error              => _error;
  String?             get errorMessage       => _errorMessage;
  bool                get isLoading          => _isLoading;
  GcashExtractResult? get gcashExtractResult => _gcashExtractResult;
  PickedAddress?      get deliveryAddress    => _deliveryAddress;
  bool                get saveAddressToProfile => _saveAddressToProfile;

  /// True when GCash payment is ready to place:
  /// receipt uploaded and ref extracted (or ref is null but user chose to proceed anyway)
  bool get gcashReceiptReady =>
      _paymentMethod != PaymentMethod.gcash || _gcashExtractResult != null;

  bool get canUseCod    => _profile?.restrictionLevel.canUseCod ?? true;
  bool get isSuspended  => _profile?.restrictionLevel == RestrictionLevel.suspended;

  // ─── Cart Operations ───────────────────────────────────────────────────────

  void addItem(MenuItem menuItem, {MenuItemVariant? variant}) {
    // Two cart entries for the same item are SEPARATE if they have different
    // variants (e.g. Hot vs Cold Milk Tea should be distinct line items).
    final effectivePrice = variant?.price ?? menuItem.price;
    final variantId   = variant?.id;
    final variantName = variant?.name;

    final existing = _items.indexWhere(
          (i) => i.menuItemId == menuItem.id && i.variantId == variantId,
    );

    if (existing >= 0) {
      _items[existing] = _items[existing].copyWith(
        quantity: _items[existing].quantity + 1,
      );
    } else {
      _items.add(CartItem(
        menuItemId:  menuItem.id,
        name:        menuItem.name,
        price:       effectivePrice,
        photoUrl:    menuItem.photoUrl,
        variantId:   variantId,
        variantName: variantName,
      ));
    }
    _clearError();
    notifyListeners();
  }

  void removeItem(int menuItemId, {int? variantId}) {
    _items.removeWhere(
          (i) => i.menuItemId == menuItemId && i.variantId == variantId,
    );
    notifyListeners();
  }

  void incrementQuantity(int menuItemId, {int? variantId}) {
    final idx = _items.indexWhere(
          (i) => i.menuItemId == menuItemId && i.variantId == variantId,
    );
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + 1);
      notifyListeners();
    }
  }

  void decrementQuantity(int menuItemId, {int? variantId}) {
    final idx = _items.indexWhere(
          (i) => i.menuItemId == menuItemId && i.variantId == variantId,
    );
    if (idx >= 0) {
      if (_items[idx].quantity <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity - 1);
      }
      notifyListeners();
    }
  }

  void updateNote(int menuItemId, String note, {int? variantId}) {
    final idx = _items.indexWhere(
          (i) => i.menuItemId == menuItemId && i.variantId == variantId,
    );
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(note: note);
      notifyListeners();
    }
  }

  void setOrderNotes(String notes) {
    _orderNotes = notes;
    notifyListeners();
  }

  bool flagUnavailableItems(List<MenuItem> currentMenu) {
    bool anyFlagged = false;
    for (final item in _items) {
      final menuItem = currentMenu.where((m) => m.id == item.menuItemId).firstOrNull;
      if (menuItem != null && !menuItem.isAvailable) anyFlagged = true;
    }
    return anyFlagged;
  }

  List<int> getUnavailableItemIds(List<MenuItem> currentMenu) {
    return _items
        .where((item) {
      final menuItem = currentMenu.where((m) => m.id == item.menuItemId).firstOrNull;
      return menuItem != null && !menuItem.isAvailable;
    })
        .map((item) => item.menuItemId)
        .toList();
  }

  void clearCart() {
    _items.clear();
    _orderNotes         = null;
    _step               = CheckoutStep.cart;
    _lastOrder          = null;
    _gcashExtractResult = null;
    _deliveryAddress      = null;
    _saveAddressToProfile = false;
    _clearError();
    notifyListeners();
  }

  // ─── Checkout Flow ─────────────────────────────────────────────────────────

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    // Clear receipt state when switching payment method
    _gcashExtractResult = null;
    _clearError();
    notifyListeners();
  }

  void setGcashExtractResult(GcashExtractResult? result) {
    _gcashExtractResult = result;
    _clearError();
    notifyListeners();
  }

  void clearGcashReceipt() {
    _gcashExtractResult = null;
    notifyListeners();
  }

  /// Called when the user manually corrects the ref number shown in Order Summary.
  void overrideGcashRef(String ref) {
    if (_gcashExtractResult == null) return;
    _gcashExtractResult = GcashExtractResult(
      tempUrl:       _gcashExtractResult!.tempUrl,
      gcashRefNumber: ref,
      gcashAmount:   _gcashExtractResult!.gcashAmount,
      ocrConfidence: _gcashExtractResult!.ocrConfidence,
      refFound:      true,
      amountFound:   _gcashExtractResult!.amountFound,
    );
    notifyListeners();
  }

  /// Called when the user manually corrects the sent amount shown in Order Summary.
  void overrideGcashAmount(double amount) {
    if (_gcashExtractResult == null) return;
    _gcashExtractResult = GcashExtractResult(
      tempUrl:       _gcashExtractResult!.tempUrl,
      gcashRefNumber: _gcashExtractResult!.gcashRefNumber,
      gcashAmount:   amount,
      ocrConfidence: _gcashExtractResult!.ocrConfidence,
      refFound:      _gcashExtractResult!.refFound,
      amountFound:   true,
    );
    notifyListeners();
  }

  /// Set / change the delivery pin for this order (checkout page).
  void setDeliveryAddress(PickedAddress address) {
    _deliveryAddress = address;
    _clearError();
    notifyListeners();
  }

  /// Whether to also persist the chosen pin as the customer's default address.
  void setSaveAddressToProfile(bool value) {
    _saveAddressToProfile = value;
    notifyListeners();
  }

  void goToStep(CheckoutStep step) {
    _step = step;
    _clearError();
    notifyListeners();
  }

  void goBack() {
    // Only one back step now: payment → cart (pops the screen)
    if (_step == CheckoutStep.payment) {
      _step = CheckoutStep.cart;
      _clearError();
      notifyListeners();
    }
  }

  // ─── Profile Gate Check ────────────────────────────────────────────────────
  Future<bool> checkProfileGate() async {
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 600));
        _profile = CustomerProfile.fromJson(kMockProfile);
      } else {
        _profile = await CartService.instance.fetchProfile();
      }

      if (_profile!.restrictionLevel == RestrictionLevel.suspended) {
        _error        = CartError.suspended;
        _errorMessage = 'Your account has been restricted. Please contact Bingnondo Cafe.';
        _isLoading    = false;
        notifyListeners();
        return false;
      }

      if (!_profile!.profileCompleted) {
        _error     = CartError.profileIncomplete;
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // If COD-restricted and was on COD, switch to GCash automatically
      if (!_profile!.restrictionLevel.canUseCod && _paymentMethod == PaymentMethod.cod) {
        _paymentMethod = PaymentMethod.gcash;
      }

      // Seed the delivery pin from the saved profile address (unless the
      // customer already chose one at checkout).
      if (_deliveryAddress == null &&
          _profile!.address != null &&
          _profile!.address!.trim().isNotEmpty) {
        _deliveryAddress = PickedAddress(
          address:   _profile!.address!,
          latitude:  _profile!.latitude,
          longitude: _profile!.longitude,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } on CartApiException catch (e) {
      _error        = CartError.network;
      _errorMessage = e.message;
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Place Order ───────────────────────────────────────────────────────────
  Future<PlaceOrderResponse?> placeOrder() async {
    _step      = CheckoutStep.placing;
    _isLoading = true;
    _clearError();
    notifyListeners();

    try {
      final request = PlaceOrderRequest(
        items:               List.from(_items),
        paymentMethod:       _paymentMethod,
        orderNotes:          _orderNotes,
        gcashReceiptTempUrl: _gcashExtractResult?.tempUrl,
        gcashRefNumber:      _gcashExtractResult?.gcashRefNumber,
        gcashAmountSent:     _gcashExtractResult?.gcashAmount,
        deliveryAddress:     _deliveryAddress?.address,
        deliveryLatitude:    _deliveryAddress?.latitude,
        deliveryLongitude:   _deliveryAddress?.longitude,
      );

      // Persist the new pin as the default address, if the customer asked for it.
      // Best-effort: a failure here must not block placing the order.
      if (_saveAddressToProfile &&
          _deliveryAddress != null &&
          !_deliveryAddress!.isEmpty &&
          _profile != null) {
        try {
          final updated = await CartService.instance.updateProfile(
            firstName:    _profile!.firstName ?? '',
            lastName:     _profile!.lastName ?? '',
            mobileNumber: _profile!.mobileNumber ?? '',
            address:      _deliveryAddress!.address,
            latitude:     _deliveryAddress!.latitude,
            longitude:    _deliveryAddress!.longitude,
          );
          _profile = updated;
        } catch (_) {
          // ignore — order still carries the pin snapshot
        }
      }

      PlaceOrderResponse response;

      if (kUseMock) {
        await Future.delayed(const Duration(milliseconds: 1200));
        response = PlaceOrderResponse.fromJson(kMockOrderResponse);
      } else {
        response = await CartService.instance.placeOrder(request);
      }

      _lastOrder = response;
      _step      = CheckoutStep.confirmation;
      _isLoading = false;
      notifyListeners();
      return response;
    } on CartApiException catch (e) {
      _error        = CartError.network;
      _errorMessage = e.message;
      _step         = CheckoutStep.payment;
      _isLoading    = false;
      notifyListeners();
      return null;
    }
  }

  void _clearError() {
    _error        = CartError.none;
    _errorMessage = null;
  }
}