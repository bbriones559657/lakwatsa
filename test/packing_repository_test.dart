import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/domain/packing.dart';
import 'package:lakwatsa/repositories/packing_repository.dart';

import 'support/settled_firestore.dart';

void main() {
  late FakeFirebaseFirestore db;
  late PackingRepository repository;
  PackingActivity activity() => PackingActivity(
    id: 'trip',
    name: 'Trip',
    type: 'Trip',
    status: ActivityStatus.planned,
    startsAt: DateTime.now(),
    endsAt: DateTime.now().add(const Duration(hours: 4)),
    reminderMinutes: 30,
    items: {
      'keys': const PackedItem(
        id: 'keys',
        name: 'Keys',
        category: 'Other',
        quantity: 1,
      ),
      'coat': const PackedItem(
        id: 'coat',
        name: 'Coat',
        category: 'Clothing',
        quantity: 2,
      ),
    },
  );
  Future<PackingActivity> read() async =>
      (await repository.watchActivity('trip').first)!;
  setUp(() {
    db = SettledFirestore();
    repository = PackingRepository(userId: 'alice', firestore: db);
  });

  test(
    'item and list writes survive a new repository and stay user scoped',
    () async {
      await repository.saveItem(
        Belonging(id: 'keys', name: 'Keys', category: 'Other', quantity: 1),
      );
      await repository.saveList(
        PackingList(id: 'list', name: 'Daily', quantities: {'keys': 1}),
      );
      final restarted = PackingRepository(userId: 'alice', firestore: db);
      expect((await restarted.watchItems().first).single.name, 'Keys');
      expect((await restarted.watchLists().first).single.quantities, {
        'keys': 1,
      });
      expect(
        await PackingRepository(
          userId: 'bob',
          firestore: db,
        ).watchItems().first,
        isEmpty,
      );
      await repository.archiveItem('keys', true);
      expect((await repository.getItem('keys'))!.archived, isTrue);
      expect((await repository.watchLists().first).single.quantities, {
        'keys': 1,
      });
    },
  );
  test(
    'full manual and QR lifecycle, resumable drafts and immutable history',
    () async {
      await repository.createActivity(activity());
      await repository.markItem(
        'trip',
        ActivityStatus.planned,
        'keys',
        CheckMethod.qr,
      );
      final restarted = PackingRepository(userId: 'alice', firestore: db);
      expect(
        (await restarted.watchActivity('trip').first)!.draft['keys'],
        CheckMethod.qr,
      );
      final before = await read();
      await repository.completeCheck(before);
      expect((await read()).status, ActivityStatus.active);
      expect((await read()).before!.missingCount, 1);
      await expectLater(repository.completeCheck(before), throwsStateError);
      await repository.markItem(
        'trip',
        ActivityStatus.active,
        'coat',
        CheckMethod.manual,
      );
      await repository.completeCheck(await read());
      final completed = await read();
      expect(completed.status, ActivityStatus.completed);
      expect(completed.before!.found, {'keys': CheckMethod.qr});
      expect(completed.returned!.found, {'coat': CheckMethod.manual});
      await expectLater(
        repository.markItem(
          'trip',
          ActivityStatus.active,
          'keys',
          CheckMethod.manual,
        ),
        throwsStateError,
      );
      await expectLater(repository.cancelActivity('trip'), throwsStateError);
    },
  );
  test(
    'QR additions change only activity and preserve before denominator',
    () async {
      await repository.saveItem(
        Belonging(
          id: 'camera',
          name: 'Camera',
          category: 'Electronics',
          quantity: 1,
        ),
      );
      await repository.saveList(
        PackingList(id: 'list', name: 'Trip', quantities: {'keys': 1}),
      );
      await repository.createActivity(activity());
      await repository.completeCheck(await read());
      await repository.markItem(
        'trip',
        ActivityStatus.active,
        'camera',
        CheckMethod.qr,
        addition: await repository.getItem('camera'),
      );
      await repository.completeCheck(await read());
      final completed = await read();
      expect(completed.before!.itemIds.length, 2);
      expect(completed.returned!.itemIds.length, 3);
      expect(completed.items['camera']!.addedDuringActivity, isTrue);
      expect((await repository.watchLists().first).single.quantities, {
        'keys': 1,
      });
    },
  );
  test('stale confirmations do not silently save different results', () async {
    await repository.createActivity(activity());
    final stale = await read();
    await repository.markItem(
      'trip',
      ActivityStatus.planned,
      'keys',
      CheckMethod.manual,
    );
    await expectLater(repository.completeCheck(stale), throwsStateError);
    expect((await read()).status, ActivityStatus.planned);
  });
  test(
    'unchecking removes a saved result and rescheduling records its time',
    () async {
      await repository.createActivity(activity());
      await repository.markItem(
        'trip',
        ActivityStatus.planned,
        'keys',
        CheckMethod.qr,
      );
      await repository.markItem('trip', ActivityStatus.planned, 'keys', null);
      expect((await read()).draft, isEmpty);
      final end = DateTime.now().add(const Duration(hours: 8));
      await repository.reschedule('trip', end, 15);
      final changed = await read();
      expect(changed.endsAt.isAtSameMomentAs(end), isTrue);
      expect(changed.reminderMinutes, 15);
      expect(changed.reminderUpdatedAt, isNotNull);
    },
  );
  test(
    'unknown QR items cannot be added and cancelled activities cannot change',
    () async {
      await repository.createActivity(activity());
      await expectLater(
        repository.markItem(
          'trip',
          ActivityStatus.planned,
          'unknown',
          CheckMethod.qr,
        ),
        throwsStateError,
      );
      await repository.cancelActivity('trip');
      await expectLater(
        repository.reschedule(
          'trip',
          DateTime.now().add(const Duration(days: 1)),
          30,
        ),
        throwsStateError,
      );
    },
  );
  test('list and inventory changes never mutate activity snapshots', () async {
    await repository.createActivity(activity());
    await repository.saveItem(
      Belonging(
        id: 'keys',
        name: 'Renamed keys',
        category: 'Other',
        quantity: 99,
      ),
    );
    await repository.saveList(
      PackingList(id: 'list', name: 'Changed', quantities: {'keys': 99}),
    );
    await repository.deleteList('list');
    expect((await read()).items['keys']!.name, 'Keys');
    expect((await read()).items['keys']!.quantity, 1);
  });
}
