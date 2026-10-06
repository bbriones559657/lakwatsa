import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/activity_check_draft.dart';
import 'package:lakwatsa/models/activity_item.dart';
import 'package:lakwatsa/repositories/activity_repository.dart';
import 'package:lakwatsa/screens/activities/activity_details_screen.dart';

class _FakeActivityRepository extends Fake implements ActivityRepository {
  final ActivityCheckDraft? draft;

  _FakeActivityRepository({this.draft});

  @override
  Stream<List<ActivityItem>> watchActivityItems(String activityId) {
    return Stream.value(const [
      ActivityItem(
        id: 'item-1',
        itemId: 'item-1',
        itemName: 'Camera',
        category: 'Electronics',
        quantity: 1,
        icon: 'electronics',
        addedDuringActivity: false,
      ),
    ]);
  }

  @override
  Stream<ActivityCheckDraft?> watchCheckDraft({
    required String activityId,
    required String checkType,
  }) {
    return Stream.value(draft);
  }
}

Activity _activeActivity() {
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

void main() {
  testWidgets('active Activity says Continue Checking when a draft exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailsScreen(
          activity: _activeActivity(),
          activityRepository: _FakeActivityRepository(
            draft: ActivityCheckDraft(
              startedAt: DateTime(2026, 10, 6, 20),
              foundMethods: const {'item-1': 'MANUAL'},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final continueLabel = find.text('Continue Checking');
    await tester.ensureVisible(continueLabel);
    expect(continueLabel, findsOneWidget);
    expect(find.text('Check Items Before Going Home'), findsNothing);
  });
}
