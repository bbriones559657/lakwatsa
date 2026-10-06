import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item_category.dart';

void main() {
  test('built-in Item categories are recognized case-insensitively', () {
    expect(ItemCategory.isBuiltInName('Electronics'), isTrue);
    expect(ItemCategory.isBuiltInName(' electronics '), isTrue);
    expect(ItemCategory.isBuiltInName('Travel Gear'), isFalse);
  });

  test('custom Item category names are normalized for storage', () {
    expect(ItemCategory.validateCustomName('  Travel Gear  '), 'Travel Gear');
    expect(
      ItemCategory.documentIdForCustomName('  Travel Gear  '),
      'travel gear',
    );
  });

  test('reserved and unsafe custom Item category names are rejected', () {
    for (final name in ['All', 'Other', 'electronics', '.', '..', 'Trip/Bag']) {
      expect(
        () => ItemCategory.validateCustomName(name),
        throwsArgumentError,
      );
    }
  });

  test('custom Item category names have a length limit', () {
    expect(
      () => ItemCategory.validateCustomName(List.filled(41, 'x').join()),
      throwsArgumentError,
    );
  });

  test('Item category name comparison ignores case and surrounding spaces', () {
    expect(ItemCategory.sameName('Travel Gear', ' travel gear '), isTrue);
    expect(ItemCategory.sameName('Travel Gear', 'Travel Bags'), isFalse);
  });
}
