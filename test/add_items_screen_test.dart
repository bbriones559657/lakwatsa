import 'package:flutter_test/flutter_test.dart';

import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/models/item_category.dart';
import 'package:lakwatsa/screens/lists/add_items_screen.dart';

void main() {
  test('selector categories include dynamic and stored Item categories', () {
    const items = [
      Item(
        id: '1',
        name: 'First aid kit',
        category: 'Medicine',
        quantity: 1,
        icon: 'inventory',
      ),
      Item(
        id: '2',
        name: 'Power bank',
        category: 'electronics',
        quantity: 1,
        icon: 'electronics',
      ),
    ];

    const customCategories = [
      ItemCategory(id: 'camping', name: 'Camping'),
      ItemCategory(id: 'medicine', name: 'medicine'),
    ];

    final names = buildAddItemsCategoryNames(
      items: items,
      customCategories: customCategories,
    );

    expect(
      names,
      [
        'All',
        'Electronics',
        'Documents',
        'Clothing',
        'Toiletries',
        'Other',
        'Camping',
        'medicine',
      ],
    );
  });
}
