import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/repositories/firestore_activity_repository.dart';

const _items = [
  Item(
    id: 'camera',
    name: 'Camera',
    category: 'Electronics',
    quantity: 1,
    icon: 'camera',
  ),
  Item(
    id: 'shirt',
    name: 'Shirt',
    category: 'Clothing',
    quantity: 2,
    icon: 'clothing',
  ),
  Item(
    id: 'bottle',
    name: 'Bottle',
    category: 'Other',
    quantity: 1,
    icon: 'bottle',
  ),
];

void main() {
  test(
    'partial creation retains the exact unwritten suffix and Activity ID',
    () async {
      final written = <String>[];
      late PartialActivityCreationException failure;

      try {
        await writeRemainingActivityItems(
          activityId: 'created-activity',
          items: _items,
          writeItem: (item) async {
            if (item.id == 'shirt') throw StateError('network failed');
            written.add(item.id);
          },
        );
        fail('Expected a partial creation error');
      } on PartialActivityCreationException catch (error) {
        failure = error;
      }

      expect(written, ['camera']);
      expect(failure.activityId, 'created-activity');
      expect(failure.missingItems.map((item) => item.id), ['shirt', 'bottle']);

      await writeRemainingActivityItems(
        activityId: failure.activityId,
        items: failure.missingItems,
        writeItem: (item) async => written.add(item.id),
      );
      expect(written, ['camera', 'shirt', 'bottle']);
    },
  );

  test('a repeated retry keeps only the still-missing Items', () async {
    try {
      await writeRemainingActivityItems(
        activityId: 'created-activity',
        items: _items.skip(1).toList(),
        writeItem: (item) async {
          if (item.id == 'bottle') throw StateError('network failed again');
        },
      );
      fail('Expected a partial creation error');
    } on PartialActivityCreationException catch (error) {
      expect(error.activityId, 'created-activity');
      expect(error.missingItems.map((item) => item.id), ['bottle']);
    }
  });
}
