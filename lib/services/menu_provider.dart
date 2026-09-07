import 'package:flutter/foundation.dart';
import '../models/menu_models.dart';
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
    // Hook into Socket.io real-time events
    SocketService.instance.onMenuUpdate = updateItemAvailability;
  }

  Future<void> loadMenu() async {
    if (_state == MenuLoadState.loading) return;

    _state = MenuLoadState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _data = await MenuService.instance.fetchMenu();
      _state = MenuLoadState.loaded;
      // Start socket after menu is loaded so we receive live updates
      await SocketService.instance.connect();
    } on MenuApiException catch (e) {
      _errorMessage = e.message;
      _state = MenuLoadState.error;
    } catch (_) {
      _errorMessage = 'Failed to load menu. Please try again.';
      _state = MenuLoadState.error;
    }

    notifyListeners();
  }

  /// Called by Socket.io `menu_update` event — updates a single item
  /// in-memory without a full network refetch. O(n) scan is fine for
  /// typical cafe menu sizes (<200 items).
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