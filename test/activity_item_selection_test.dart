import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/screens/activities/activity_item_selection.dart';

Item item(String id, {int quantity = 1, String name = 'Item'}) {
  return Item(
    id: id,
    name: name,
    category: 'Other',
    quantity: quantity,
    icon: 'inventory',
  );
}

void main() {
  test('overlapping List Items keep the highest quantity without summing', () {
    final result = dedupeActivityItems([
      [item('a'), item('b', quantity: 2)],
      [item('b', quantity: 5), item('c')],
      [item('b', quantity: 3)],
    ]);

    expect(result.map((value) => value.id).toList(), ['a', 'b', 'c']);
    final shared = result.singleWhere((value) => value.id == 'b');
    expect(shared.quantity, 5);
    expect(shared.quantity, isNot(10));
  });

  test('manual Items merge with imported Items without duplicates', () {
    final result = buildActivityItemSelection(
      importedItems: [item('a'), item('b', quantity: 4)],
      manuallyAddedItems: [item('b', quantity: 2), item('c')],
    );

    expect(result.map((value) => value.id).toList(), ['a', 'b', 'c']);
    expect(result.singleWhere((value) => value.id == 'b').quantity, 4);
  });

  test('removal and quantity overrides affect only Activity selection', () {
    final source = item('a', quantity: 2);
    final result = buildActivityItemSelection(
      importedItems: [source, item('b')],
      manuallyAddedItems: const [],
      removedItemIds: {'b'},
      quantityOverrides: {'a': 5},
    );

    expect(result, hasLength(1));
    expect(result.single.id, 'a');
    expect(result.single.quantity, 5);
    expect(source.quantity, 2);
  });
}
