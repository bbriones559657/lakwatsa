import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/activity_item.dart';
import 'package:lakwatsa/models/activity_check_draft.dart';
import 'package:lakwatsa/models/item_list.dart';
import 'package:lakwatsa/repositories/activity_repository.dart';
import 'package:lakwatsa/repositories/list_repository.dart';
import 'package:lakwatsa/screens/home/home_screen.dart';
import 'package:lakwatsa/theme/app_theme.dart';

class _FakeActivityRepository extends Fake implements ActivityRepository {
  final List<Activity> activities;
  final Map<String, List<ActivityItem>> itemsByActivity;
  final Map<String, ActivityCheckDraft> returnDraftsByActivity;

  _FakeActivityRepository({
    required this.activities,
    this.itemsByActivity = const {},
    this.returnDraftsByActivity = const {},
  });

  @override
  Stream<List<Activity>> watchActivities() => Stream.value(activities);

  @override
  Stream<List<ActivityItem>> watchActivityItems(String activityId) {
    return Stream.value(itemsByActivity[activityId] ?? const []);
  }

  @override
  Stream<ActivityCheckDraft?> watchCheckDraft({
    required String activityId,
    required String checkType,
  }) {
    return Stream.value(returnDraftsByActivity[activityId]);
  }
}

class _FakeListRepository extends Fake implements ListRepository {
  final List<ItemList> lists;
  final Map<String, List<String>> itemIdsByList;

  _FakeListRepository({
    required this.lists,
    this.itemIdsByList = const {},
  });

  @override
  Stream<List<ItemList>> watchLists() => Stream.value(lists);

  @override
  Stream<List<String>> watchListItemIds(String listId) {
    return Stream.value(itemIdsByList[listId] ?? const []);
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
  testWidgets('dashboard actions forward to the intended destinations', (
    tester,
  ) async {
    var itemsCount = 0;
    var listsCount = 0;
    var activitiesCount = 0;
    var openedActivityCount = 0;
    var openedListCount = 0;

    final activity = _activeActivity();
    final recentList = ItemList(
      id: 'list-1',
      name: 'Coffee essentials',
      icon: 'list',
      createdAt: DateTime(2026, 10, 1),
      updatedAt: DateTime(2026, 10, 6),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 800,
            child: HomeScreen(
              activityRepository: _FakeActivityRepository(
                activities: [activity],
                itemsByActivity: {
                  activity.id: const [
                    ActivityItem(
                      id: 'item-1',
                      itemId: 'item-1',
                      itemName: 'Cup',
                      category: 'Other',
                      quantity: 1,
                      icon: 'inventory',
                      addedDuringActivity: false,
                    ),
                  ],
                },
              ),
              listRepository: _FakeListRepository(lists: [recentList]),
              profileInitial: 'T',
              onOpenItems: () => itemsCount++,
              onCreateList: () => listsCount++,
              onOpenLists: () => listsCount++,
              onOpenActivities: () => activitiesCount++,
              onContinueActivity: (_) => openedActivityCount++,
              onOpenList: (_) => openedListCount++,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.text('My Items'));
    expect(itemsCount, 1);

    await tester.tap(find.text('New List'));
    expect(listsCount, 1);

    await tester.tap(find.text('Activities'));
    expect(activitiesCount, 1);

    final continueButton = find.text('Start Return Check →');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    expect(openedActivityCount, 1);

    final recentListTitle = find.text('Coffee essentials');
    await tester.ensureVisible(recentListTitle);
    await tester.tap(recentListTitle);
    expect(openedListCount, 1);

    final seeAllButton = find.text('See all');
    await tester.ensureVisible(seeAllButton);
    await tester.tap(seeAllButton);
    expect(listsCount, 2);
  });

  testWidgets('dashboard stays usable on a narrow screen with larger text', (
    tester,
  ) async {
    final activity = _activeActivity();

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            textScaler: TextScaler.linear(1.5),
          ),
          child: Scaffold(
            body: SizedBox(
              width: 320,
              height: 640,
              child: HomeScreen(
                activityRepository: _FakeActivityRepository(
                  activities: [activity],
                  itemsByActivity: {
                    activity.id: const [
                      ActivityItem(
                        id: 'item-1',
                        itemId: 'item-1',
                        itemName: 'Passport',
                        category: 'Documents',
                        quantity: 1,
                        icon: 'documents',
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
                    ],
                  },
                ),
                listRepository: _FakeListRepository(lists: const []),
                profileInitial: 'T',
                onOpenItems: () {},
                onCreateList: () {},
                onOpenLists: () {},
                onOpenActivities: () {},
                onContinueActivity: (_) {},
                onOpenList: (_) {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final actionText = find.text('Start Return Check →');
    await tester.ensureVisible(actionText);
    final actionInkWell = find.ancestor(
      of: actionText,
      matching: find.byType(InkWell),
    );
    expect(actionInkWell, findsOneWidget);
    expect(
      tester.getSize(actionInkWell).height,
      greaterThanOrEqualTo(AppMetrics.touchTarget),
    );
  });

  testWidgets(
    'dashboard renders active activity and recent lists from repositories',
    (tester) async {
      final activity = _activeActivity();
      final recentList = ItemList(
        id: 'list-2',
        name: 'Actual database list',
        icon: 'list',
        createdAt: DateTime(2026, 10, 2),
        updatedAt: DateTime(2026, 10, 6),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              height: 800,
              child: HomeScreen(
                activityRepository: _FakeActivityRepository(
                  activities: [activity],
                  itemsByActivity: {
                    activity.id: const [
                      ActivityItem(
                        id: 'item-1',
                        itemId: 'item-1',
                        itemName: 'Cup',
                        category: 'Other',
                        quantity: 1,
                        icon: 'inventory',
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
                        itemName: 'Jacket',
                        category: 'Clothing',
                        quantity: 1,
                        icon: 'clothing',
                        addedDuringActivity: false,
                      ),
                    ],
                  },
                  returnDraftsByActivity: {
                    activity.id: ActivityCheckDraft(
                      startedAt: DateTime(2026, 10, 6, 20),
                      foundMethods: const {
                        'item-1': 'MANUAL',
                        'item-2': 'QR',
                      },
                    ),
                  },
                ),
                listRepository: _FakeListRepository(
                  lists: [recentList],
                  itemIdsByList: {
                    recentList.id: const ['item-1', 'item-2'],
                  },
                ),
                profileInitial: 'T',
                onOpenItems: () {},
                onCreateList: () {},
                onOpenLists: () {},
                onOpenActivities: () {},
                onContinueActivity: (_) {},
                onOpenList: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Coffee trip'), findsOneWidget);
      expect(find.text('Packing'), findsOneWidget);
      expect(find.text('2/3'), findsOneWidget);
      expect(find.text('Continue Checking →'), findsOneWidget);
      expect(
        find.byKey(const Key('dashboard-activity-progress')),
        findsOneWidget,
      );
      expect(find.text('Actual database list'), findsOneWidget);
      expect(find.text('2 items'), findsOneWidget);
      expect(find.text('Beach Trip'), findsNothing);
      expect(find.text('Boracay 2025'), findsNothing);
    },
  );
}
