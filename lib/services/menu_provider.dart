import 'package:flutter/foundation.dart';
import '../models/menu_models.dart';
import '../mock/mock_data.dart';
import 'menu_service.dart';
import 'socket_service.dart';

enum MenuLoadState { initial, loading, loaded, error }

class MenuProvider extends ChangeNotifier {
  MenuLoadState _state = MenuLoadState.initial;
  MenuData? _data;
  String? _errorMessage;

  MenuLoadState get state => _state;
  MenuData? get data => _data;
  String? get errorMessage => _errorMessage;
  bool get isLoaded => _state == MenuLoadState.loaded;

  List<MenuCategory> get categories => _data?.categories ?? [];
  List<MenuItem> get allItems => _data?.items ?? [];

  List<MenuItem> itemsForCategory(int categoryId) =>
      _data?.itemsForCategory(categoryId) ?? [];

  MenuProvider() {
    SocketService.instance.onMenuUpdate = updateItemAvailability;
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
        await SocketService.instance.connect();
      }
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

  void updateItemAvailability(int itemId, bool isAvailable) {
    if (_data == null) return;
    final updated = _data!.items.map((item) {
      return item.id == itemId ? item.copyWith(isAvailable: isAvailable) : item;
    }).toList();
    _data = MenuData(categories: _data!.categories, items: updated);
    notifyListeners();
  }

  Future<void> refresh() => loadMenu();

  @override
  void dispose() {
    SocketService.instance.onMenuUpdate = null;
    super.dispose();
  }
}