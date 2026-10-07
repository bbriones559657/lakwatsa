import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/activity_check_draft.dart';
import 'package:lakwatsa/models/activity_item.dart';
import 'package:lakwatsa/repositories/activity_repository.dart';
import 'package:lakwatsa/screens/activities/activity_details_screen.dart';

class _FakeActivityRepository extends Fake implements ActivityRepository {
  final ActivityCheckDraft? draft;
  final Completer<void>? cancellation;
  final List<ActivityItem> items;
  int cancellationCalls = 0;

  _FakeActivityRepository({
    this.draft,
    this.cancellation,
    this.items = const [
      ActivityItem(
        id: 'item-1',
        itemId: 'item-1',
        itemName: 'Camera',
        category: 'Electronics',
        quantity: 1,
        icon: 'electronics',
        addedDuringActivity: false,
      ),
    ],
  });

  @override
  Stream<List<ActivityItem>> watchActivityItems(String activityId) {
    return Stream.value(items);
  }

  @override
  Stream<ActivityCheckDraft?> watchCheckDraft({
    required String activityId,
    required String checkType,
  }) {
    return Stream.value(draft);
  }

  @override
  Future<void> cancelActivity(String activityId) {
    cancellationCalls++;
    return cancellation?.future ?? Future<void>.value();
  }
}

Activity _cancelledActivity() {
  final date = DateTime(2026, 10, 5, 8);

  return Activity(
    id: 'activity-cancelled',
    listId: 'list-1',
    name: 'Cancelled trip',
    type: 'Trip',
    activityDate: date,
    startAt: date,
    endAt: DateTime(2026, 10, 5, 17),
    reminderEnabled: true,
    reminderMinutes: 30,
    status: 'CANCELLED',
  );
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
  testWidgets('cancelled Activity is read-only and exposes check history', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailsScreen(
          activity: _cancelledActivity(),
          activityRepository: _FakeActivityRepository(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('View Check History'), findsOneWidget);
    expect(find.text('Add'), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.textContaining('cancelled'), findsWidgets);
  });

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

  testWidgets('Activity actions stay disabled while cancellation is pending', (
    tester,
  ) async {
    final cancellation = Completer<void>();
    final repository = _FakeActivityRepository(cancellation: cancellation);
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailsScreen(
          activity: _activeActivity(),
          activityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Cancel Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Activity'));
    await tester.pump();

    expect(repository.cancellationCalls, 1);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.text('Cancelling...'), findsOneWidget);
    await tester.tap(find.text('Check Items Before Going Home'));
    await tester.tap(find.text('Add'));
    await tester.pump();
    expect(find.text('Scan QR Codes'), findsNothing);
    expect(find.text('Add Items'), findsNothing);
    expect(repository.cancellationCalls, 1);

    cancellation.completeError(StateError('network failed'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    expect(find.text('Cancel Activity'), findsOneWidget);
  });

  testWidgets('Upcoming Item removal is hidden while cancellation is pending', (
    tester,
  ) async {
    final cancellation = Completer<void>();
    final repository = _FakeActivityRepository(
      cancellation: cancellation,
      items: [
        ..._FakeActivityRepository().items,
        const ActivityItem(
          id: 'item-2',
          itemId: 'item-2',
          itemName: 'Shirt',
          category: 'Clothing',
          quantity: 1,
          icon: 'clothing',
          addedDuringActivity: false,
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ActivityDetailsScreen(
          activity: _activeActivity().copyWith(status: 'UPCOMING'),
          activityRepository: repository,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.delete_outline), findsNWidgets(2));

    await tester.ensureVisible(find.text('Cancel Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel Activity'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cancel Activity'));
    await tester.pump();
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    cancellation.complete();
    await tester.pumpAndSettle();
    expect(find.text('View Check History'), findsOneWidget);
  });
}
