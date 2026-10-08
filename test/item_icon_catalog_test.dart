import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item_category.dart';
import 'package:lakwatsa/screens/items/item_icon_catalog.dart';

void main() {
  test('built-in categories receive stable suggested icons', () {
    expect(defaultItemIconKeyForCategory('Electronics'), 'electronics');
    expect(defaultItemIconKeyForCategory('Documents'), 'documents');
    expect(defaultItemIconKeyForCategory('Clothing'), 'clothing');
    expect(defaultItemIconKeyForCategory('Toiletries'), 'toiletries');
  });

  test('custom categories start generic but can use picker alternatives', () {
    expect(defaultItemIconKeyForCategory('Facial care'), 'inventory');
    expect(
      itemIconOptions.any((option) => option.key == 'toiletries'),
      isTrue,
    );
    expect(
      itemIconOptions.map((option) => option.key).toSet().length,
      itemIconOptions.length,
    );
  });
  test('camera search returns several camera choices', () {
    final results = searchItemIconOptions('camera');
    final keys = results.map((option) => option.key).toSet();

    expect(keys, contains('camera'));
    expect(keys, contains('camera_alt'));
    expect(keys, contains('camera_front'));
    expect(keys, contains('camera_rear'));
    expect(keys, contains('video_camera'));
    expect(results.length, greaterThanOrEqualTo(5));
  });

  test('icon search supports related terms and multiple words', () {
    expect(
      searchItemIconOptions('bag').map((option) => option.key),
      containsAll(['luggage', 'backpack']),
    );
    expect(
      searchItemIconOptions('camera video').map((option) => option.key),
      contains('video_camera'),
    );
    expect(searchItemIconOptions(''), hasLength(itemIconOptions.length));
  });

  test('picker catalog and category whitelist stay in sync', () {
    expect(
      itemIconOptions.map((option) => option.key).toSet(),
      ItemCategory.allowedIconKeys.toSet(),
    );
  });

  test('expanded library covers common personal and travel use cases', () {
    expect(itemIconOptions.length, greaterThanOrEqualTo(90));
    final keys = itemIconOptions.map((option) => option.key).toSet();

    expect(
      keys,
      containsAll([
        'gamepad',
        'calculator',
        'plane',
        'laundry',
        'shopping_bag',
        'hiking',
        'receipt',
        'plant',
      ]),
    );
    expect(
      searchItemIconOptions('gaming').map((option) => option.key),
      contains('gamepad'),
    );
    expect(
      searchItemIconOptions('grocery').map((option) => option.key),
      containsAll(['shopping_bag', 'shopping_cart']),
    );
  });

}
