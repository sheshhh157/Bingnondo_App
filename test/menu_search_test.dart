import 'package:flutter_test/flutter_test.dart';

import 'package:bingnondo_app/models/menu_models.dart';

void main() {
  final menu = MenuData(
    categories: const [
      MenuCategory(id: 1, name: 'Drinks', sortOrder: 0),
      MenuCategory(id: 2, name: 'Rice Meals', sortOrder: 1),
    ],
    items: const [
      MenuItem(
        id: 1,
        categoryId: 1,
        name: 'Iced Milk Tea',
        description: 'Classic black tea with milk',
        price: 99,
        isAvailable: true,
      ),
      MenuItem(
        id: 2,
        categoryId: 2,
        name: 'Shanghai Roll',
        description: 'Crispy pork rolls with rice',
        price: 120,
        isAvailable: true,
      ),
    ],
  );

  test('searches item names without case sensitivity', () {
    expect(menu.searchItems('MILK').map((item) => item.name), [
      'Iced Milk Tea',
    ]);
  });

  test('searches item descriptions and category names', () {
    expect(menu.searchItems('crispy').map((item) => item.name), [
      'Shanghai Roll',
    ]);
    expect(menu.searchItems('drinks').map((item) => item.name), [
      'Iced Milk Tea',
    ]);
  });

  test(
    'returns no matches for an unknown query and all items for empty query',
    () {
      expect(menu.searchItems('unlisted dish'), isEmpty);
      expect(menu.searchItems('  '), hasLength(2));
    },
  );
}
