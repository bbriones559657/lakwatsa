import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/domain/packing.dart';

void main() {
  test('inventory validates names and quantities', () {
    expect(
      () => Belonging(id: 'a', name: ' ', category: 'Other', quantity: 1),
      throwsArgumentError,
    );
    expect(
      () => Belonging(id: 'a', name: 'Keys', category: 'Other', quantity: 0),
      throwsArgumentError,
    );
    expect(
      () => Belonging(id: 'a', name: 'Keys', category: 'Other', quantity: 1000),
      throwsArgumentError,
    );
    expect(
      Belonging(id: 'a', name: ' Keys ', category: 'Other', quantity: 1).name,
      'Keys',
    );
  });
  test(
    'QR payload round trips and rejects another owner and malformed paths',
    () {
      expect(parseItemQr(itemQrPayload('alice', 'keys'), 'alice'), 'keys');
      for (final payload in [
        'https://example.com',
        'lakwatsa://item/bob/keys',
        'lakwatsa://item/alice/a/b',
        'lakwatsa://item/alice/a?x=1',
        'lakwatsa://item/alice/a%2Fb',
      ]) {
        expect(() => parseItemQr(payload, 'alice'), throwsFormatException);
      }
    },
  );
  test('check history retains its own denominator and methods', () {
    final check = CheckRecord(
      startedAt: DateTime.utc(2026),
      completedAt: DateTime.utc(2026, 1, 1, 1),
      itemIds: ['a', 'b'],
      found: {'a': CheckMethod.qr},
    );
    final restored = CheckRecord.fromMap(check.toMap());
    expect(restored.itemIds, ['a', 'b']);
    expect(restored.missingCount, 1);
    expect(restored.found['a'], CheckMethod.qr);
    expect(
      () => restored.found['b'] = CheckMethod.manual,
      throwsUnsupportedError,
    );
    expect(
      () => CheckRecord(
        startedAt: DateTime.now(),
        completedAt: DateTime.now(),
        itemIds: ['a'],
        found: {'b': CheckMethod.qr},
      ),
      throwsArgumentError,
    );
  });
  test('lists copy quantities so later changes cannot mutate them', () {
    final original = {'a': 2};
    final list = PackingList(id: 'l', name: 'Trip', quantities: original);
    original['a'] = 99;
    expect(list.quantities['a'], 2);
    expect(
      () => PackingList(id: 'l', name: 'Trip', quantities: {'a': -1}),
      throwsArgumentError,
    );
  });
}
