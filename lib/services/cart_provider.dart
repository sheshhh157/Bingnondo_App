import 'package:flutter/foundation.dart';
import '../models/cart_models.dart';
import '../models/menu_models.dart';
import '../mock/mock_data.dart';
import 'cart_service.dart';

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
  CheckoutStep      _step          = CheckoutStep.cart;
  PaymentMethod     _paymentMethod = PaymentMethod.gcash;
  CustomerProfile?  _profile;
  PlaceOrderResponse? _lastOrder;
  CartError         _error         = CartError.none;
  String?           _errorMessage;
  bool              _isLoading     = false;

  CheckoutStep      get step          => _step;
  PaymentMethod     get paymentMethod => _paymentMethod;
  CustomerProfile?  get profile       => _profile;
  PlaceOrderResponse? get lastOrder   => _lastOrder;
  CartError         get error         => _error;
  String?           get errorMessage  => _errorMessage;
  bool              get isLoading     => _isLoading;

  bool get canUseCod    => _profile?.restrictionLevel.canUseCod ?? true;
  bool get isSuspended  => _profile?.restrictionLevel == RestrictionLevel.suspended;

  // ─── Cart Operations ───────────────────────────────────────────────────────

  void addItem(MenuItem menuItem) {
    final existing = _items.indexWhere((i) => i.menuItemId == menuItem.id);
    if (existing >= 0) {
      _items[existing] = _items[existing].copyWith(
        quantity: _items[existing].quantity + 1,
      );
    } else {
      _items.add(CartItem(
        menuItemId: menuItem.id,
        name:       menuItem.name,
        price:      menuItem.price,
        photoUrl:   menuItem.photoUrl,
      ));
    }
    _clearError();
    notifyListeners();
  }

  void removeItem(int menuItemId) {
    _items.removeWhere((i) => i.menuItemId == menuItemId);
    notifyListeners();
  }

  void incrementQuantity(int menuItemId) {
    final idx = _items.indexWhere((i) => i.menuItemId == menuItemId);
    if (idx >= 0) {
      _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity + 1);
      notifyListeners();
    }
  }

  void decrementQuantity(int menuItemId) {
    final idx = _items.indexWhere((i) => i.menuItemId == menuItemId);
    if (idx >= 0) {
      if (_items[idx].quantity <= 1) {
        _items.removeAt(idx);
      } else {
        _items[idx] = _items[idx].copyWith(quantity: _items[idx].quantity - 1);
      }
      notifyListeners();
    }
  }

  void updateNote(int menuItemId, String note) {
    final idx = _items.indexWhere((i) => i.menuItemId == menuItemId);
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
    _orderNotes = null;
    _step       = CheckoutStep.cart;
    _lastOrder  = null;
    _clearError();
    notifyListeners();
  }

  // ─── Checkout Flow ─────────────────────────────────────────────────────────

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
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
        items:        List.from(_items),
        paymentMethod: _paymentMethod,
        orderNotes:   _orderNotes,
      );

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