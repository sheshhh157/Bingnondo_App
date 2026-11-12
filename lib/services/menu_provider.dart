import 'package:flutter/foundation.dart';
import '../models/menu_models.dart';
import '../mock/mock_data.dart';
import 'menu_service.dart';
import 'socket_service.dart';

enum MenuLoadState { initial, loading, loaded, error }

class MenuProvider extends ChangeNotifier {
  MenuLoadState _state = MenuLoadState.initial;
  MenuData? _data;
  Map<int, List<MenuItem>> _itemsByCategory = {};
  String? _errorMessage;

  MenuLoadState get state => _state;
  MenuData? get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _state == MenuLoadState.loaded;

  List<MenuCategory> get categories => _data?.categories ?? [];
  List<MenuItem> get allItems => _data?.items ?? [];
  Map<int, List<MenuItem>> get itemsByCategory => _itemsByCategory;

  List<MenuItem> itemsForCategory(int categoryId) =>
      _itemsByCategory[categoryId] ?? const [];

  List<MenuItem> searchItems(String query) =>
      _data?.searchItems(query) ?? [];

  MenuProvider() {
    SocketService.instance.onMenuUpdate = _handleMenuUpdate;
  }

  void _handleMenuUpdate(Map<String, dynamic> data) {
    try {
      final itemId = (data['item_id'] ?? data['id']) as int?;
      final isAvailable = (data['is_available'] ?? data['available']) as bool?;
      if (itemId != null && isAvailable != null) {
        updateItemAvailability(itemId, isAvailable);
      }
    } catch (_) {}
  }

  Future<void> loadMenu() async {
    if (_state == MenuLoadState.loading) return;

    _state = MenuLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (kUseMock) {
        await _loadMockMenu();
      } else {
        _data = await MenuService.instance.fetchMenu();
      }
      _cacheItemsByCategory();
      if (!kUseMock) SocketService.instance.connect();
      _state = MenuLoadState.loaded;
    } on MenuApiException catch (e) {
      _errorMessage = e.message;
      _state = MenuLoadState.error;
    } catch (_) {
      _errorMessage = 'Failed to load menu. Please try again.';
      _state = MenuLoadState.error;
    }

    notifyListeners();
  }

  Future<void> _loadMockMenu() async {
    await Future.delayed(const Duration(milliseconds: 900));
    _data = MenuData.fromJson(kMockMenuData);
  }

  // Called per item by SocketService.onMenuUpdate (single-item callback, batched
  // by socket_service.dart iterating the incoming items array).
  void updateItemAvailability(int itemId, bool isAvailable) {
    if (_data == null) return;
    final itemIndex = _data!.items.indexWhere((item) => item.id == itemId);
    if (itemIndex == -1 || _data!.items[itemIndex].isAvailable == isAvailable) {
      return;
    }

    final item = _data!.items[itemIndex].copyWith(isAvailable: isAvailable);
    final categoryItems = _itemsByCategory[item.categoryId];
    if (categoryItems == null) return;
    final categoryItemIndex =
        categoryItems.indexWhere((categoryItem) => categoryItem.id == itemId);
    if (categoryItemIndex == -1) return;

    final updatedItems = List<MenuItem>.of(_data!.items)..[itemIndex] = item;
    final updatedCategoryItems = List<MenuItem>.of(categoryItems)
      ..[categoryItemIndex] = item;

    _data = MenuData(categories: _data!.categories, items: updatedItems);
    _itemsByCategory = Map<int, List<MenuItem>>.of(_itemsByCategory)
      ..[item.categoryId] = updatedCategoryItems;
    notifyListeners();
  }

  void _cacheItemsByCategory() {
    final grouped = <int, List<MenuItem>>{};
    for (final item in _data?.items ?? const <MenuItem>[]) {
      grouped.putIfAbsent(item.categoryId, () => []).add(item);
    }
    _itemsByCategory = {
      for (final entry in grouped.entries)
        entry.key: List<MenuItem>.unmodifiable(entry.value),
    };
  }

  // § 1.5 pre-checkout gate — checks live availability for a list of item IDs.
  // Returns IDs of items that are NOW unavailable so CartScreen can warn the user.
  // Falls back to local state when mock mode is on or the request fails.
  Future<List<int>> checkCartAvailability(List<int> itemIds) async {
    if (kUseMock || itemIds.isEmpty) {
      // In mock mode, use local state
      return _data?.items
          .where((i) => itemIds.contains(i.id) && !i.isAvailable)
          .map((i) => i.id)
          .toList() ??
          [];
    }

    try {
      final results = await MenuService.instance.checkAvailability(itemIds);
      // Update local cache while we're here — free sync
      for (final r in results) {
        updateItemAvailability(r['id'] as int, r['is_available'] as bool);
      }
      return results
          .where((r) => r['is_available'] == false)
          .map((r) => r['id'] as int)
          .toList();
    } catch (_) {
      // Network error — fall back to cached local state; don't block checkout
      return _data?.items
          .where((i) => itemIds.contains(i.id) && !i.isAvailable)
          .map((i) => i.id)
          .toList() ??
          [];
    }
  }

  Future<void> refresh() => loadMenu();

  @override
  void dispose() {
    SocketService.instance.onMenuUpdate = null;
    super.dispose();
  }
}
