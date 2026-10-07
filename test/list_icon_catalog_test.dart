import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/screens/lists/list_icon_catalog.dart';

void main() {
  test('list icon catalog preserves all existing keys without duplicates', () {
    final keys = listIconOptions.map((option) => option.key).toList();

    expect(listIconOptions, hasLength(48));
    expect(keys.toSet(), hasLength(keys.length));
    expect(
      keys,
      containsAll(<String>[
        'beach',
        'flight',
        'school',
        'work',
        'fitness',
        'grocery',
        'list',
        'camera',
      ]),
    );
  });

  test('list icon search matches labels, categories, and aliases', () {
    expect(
      searchListIconOptions('plane').map((option) => option.key),
      contains('flight'),
    );
    expect(
      searchListIconOptions('college').map((option) => option.key),
      contains('school'),
    );
    expect(
      searchListIconOptions('grocery').map((option) => option.key),
      containsAll(<String>['cart', 'grocery']),
    );
    expect(
      searchListIconOptions('fitness'),
      isNotEmpty,
    );
  });

  test('list icon keys resolve to icons and labels with safe fallbacks', () {
    for (final option in listIconOptions) {
      expect(listIconDataForKey(option.key), option.icon);
      expect(listIconLabelForKey(option.key), option.label);
    }

    expect(listIconLabelForKey('unknown-key'), 'General List');
    expect(listIconDataForKey('unknown-key'), listIconDataForKey('list'));
  });
}
