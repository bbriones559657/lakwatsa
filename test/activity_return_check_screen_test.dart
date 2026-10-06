import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/activity_check_draft.dart';
import 'package:lakwatsa/models/activity_item.dart';
import 'package:lakwatsa/repositories/activity_repository.dart';
import 'package:lakwatsa/screens/activities/activity_return_check_screen.dart';

class _FakeActivityRepository extends Fake implements ActivityRepository {
  final ActivityCheckDraft? draft;
  final List<ActivityItem> items;

  _FakeActivityRepository({required this.draft, required this.items});

  @override
  Future<ActivityCheckDraft?> getCheckDraft({
    required String activityId,
    required String checkType,
  }) async {
    return draft;
  }

  @override
  Stream<List<ActivityItem>> watchActivityItems(String activityId) {
    return Stream.value(items);
  }
}

Activity _activity() {
  final date = DateTime(2026, 10, 5, 8);

  return Activity(
    id: 'activity-1',
    listId: 'list-1',
    name: 'Coffee trip',
    type: 'Trip',
    activityDate: date,
    startAt: date,
    endAt: DateTime(2026, 10, 5, 17),
    reminderEnabled: true,
    reminderMinutes: 30,
    status: 'ACTIVE',
  );
}

const _items = [
  ActivityItem(
    id: 'item-1',
    itemId: 'item-1',
    itemName: 'Shirt',
    category: 'Clothing',
    quantity: 1,
    icon: 'clothing',
    addedDuringActivity: false,
  ),
  ActivityItem(
    id: 'item-2',
    itemId: 'item-2',
    itemName: 'Camera',
    category: 'Electronics',
    quantity: 1,
    icon: 'electronics',
    addedDuringActivity: false,
  ),
  ActivityItem(
    id: 'item-3',
    itemId: 'item-3',
    itemName: 'Macbook M2',
    category: 'Electronics',
    quantity: 1,
    icon: 'laptop',
    addedDuringActivity: false,
  ),
];

void main() {
  testWidgets('return check restores saved draft progress', (tester) async {
    final repository = _FakeActivityRepository(
      draft: ActivityCheckDraft(
        startedAt: DateTime(2026, 10, 6, 20),
        foundMethods: const {
          'item-1': 'MANUAL',
          'item-2': 'QR',
        },
      ),
      items: _items,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ActivityReturnCheckScreen(
          activity: _activity(),
          activityRepository: repository,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.text('Shirt'), findsOneWidget);
    expect(find.text('Camera'), findsOneWidget);
    expect(find.text('Macbook M2'), findsOneWidget);
  });
}
