import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/models/item_list.dart';
import 'package:lakwatsa/repositories/activity_repository.dart';
import 'package:lakwatsa/repositories/firestore_activity_repository.dart';
import 'package:lakwatsa/repositories/item_repository.dart';
import 'package:lakwatsa/repositories/list_repository.dart';
import 'package:lakwatsa/screens/activities/create_activity_screen.dart';

const _items = [
  Item(
    id: 'camera',
    name: 'Camera',
    category: 'Electronics',
    quantity: 1,
    icon: 'camera',
  ),
  Item(
    id: 'bottle',
    name: 'Bottle',
    category: 'Other',
    quantity: 1,
    icon: 'bottle',
  ),
];

class _ListRepository extends Fake implements ListRepository {
  @override
  Stream<List<ItemList>> watchLists() => Stream.value(const [
    ItemList(id: 'packing-list', name: 'Weekend pack', icon: 'list'),
  ]);

  @override
  Future<List<String>> getListItemIds(String listId) async => [
    'camera',
    'bottle',
  ];
}

class _ItemRepository extends Fake implements ItemRepository {
  @override
  Future<Item?> getItem(String itemId) async =>
      _items.where((item) => item.id == itemId).firstOrNull;
}

class _ActivityRepository extends Fake implements ActivityRepository {
  final Completer<Activity>? createPending;
  final Completer<void>? retryPending;
  final bool failAfterFirstItem;
  int createCalls = 0;
  int retryCalls = 0;
  Activity? submittedActivity;
  String? retryActivityId;
  List<String>? retryItemIds;

  _ActivityRepository({
    this.createPending,
    this.retryPending,
    this.failAfterFirstItem = false,
  });

  @override
  Future<Activity> addActivityWithItems({
    required Activity activity,
    required List<Item> items,
  }) {
    createCalls++;
    submittedActivity = activity;
    if (failAfterFirstItem) {
      return Future<Activity>.error(
        PartialActivityCreationException(
          'created-activity',
          StateError('network failed'),
          missingItems: [items.last],
        ),
      );
    }
    return createPending!.future;
  }

  @override
  Future<void> retryActivityCreationItems({
    required String activityId,
    required List<Item> items,
  }) {
    retryCalls++;
    retryActivityId = activityId;
    retryItemIds = items.map((item) => item.id).toList();
    return retryPending!.future;
  }
}

Finder get _createButton => find
    .ancestor(
      of: find.text('Create Activity'),
      matching: find.byType(GestureDetector),
    )
    .first;

Future<void> _prepareScreen(
  WidgetTester tester,
  _ActivityRepository activityRepository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(
                builder: (_) => CreateActivityScreen(
                  activityRepository: activityRepository,
                  itemRepository: _ItemRepository(),
                  listRepository: _ListRepository(),
                  requestReminderPermission: () async => true,
                ),
              ),
            ),
            child: const Text('Open creator'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open creator'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'Weekend trip');
  await tester.tap(find.text('Choose'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Weekend pack'));
  await tester.pump();
  await tester.tap(find.text('Import 1 List'));
  await tester.pumpAndSettle();
  expect(find.text('Camera'), findsWidgets);
  expect(
    tester.widget<TextField>(find.byType(TextField).first).controller!.text,
    'Weekend trip',
  );
  await tester.scrollUntilVisible(
    find.byType(ValueListenableBuilder<TextEditingValue>),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(_createButton);
  await tester.pumpAndSettle();
  expect(find.text('Create Activity'), findsNWidgets(2));
  final createButton = tester.widget<GestureDetector>(_createButton);
  expect(createButton.onTap, isNotNull);
}

void main() {
  testWidgets('rapid Create taps start one Activity creation', (tester) async {
    final pending = Completer<Activity>();
    final repository = _ActivityRepository(createPending: pending);
    await _prepareScreen(tester, repository);

    await tester.tap(_createButton);
    await tester.tap(_createButton);
    await tester.pump();
    expect(repository.createCalls, 1);
    expect(find.text('Creating...'), findsOneWidget);

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .onChanged,
      isNull,
    );

    await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).first).enabled,
      false,
    );
    expect(
      tester
          .widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          )
          .onChanged,
      isNull,
    );
    await tester.scrollUntilVisible(
      find.byIcon(Icons.calendar_today_outlined),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(
      tester
          .widget<GestureDetector>(
            find
                .ancestor(
                  of: find.byIcon(Icons.calendar_today_outlined),
                  matching: find.byType(GestureDetector),
                )
                .first,
          )
          .onTap,
      isNull,
    );

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Creating...'), findsOneWidget);
    expect(find.text('Open creator'), findsNothing);

    pending.complete(
      repository.submittedActivity!.copyWith(id: 'created-activity'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Open creator'), findsOneWidget);
  });

  testWidgets('partial creation retries only missing Items on the same ID', (
    tester,
  ) async {
    final retry = Completer<void>();
    final repository = _ActivityRepository(
      failAfterFirstItem: true,
      retryPending: retry,
    );
    await _prepareScreen(tester, repository);

    await tester.tap(_createButton);
    await tester.pumpAndSettle();
    expect(repository.createCalls, 1);
    expect(find.text('Retry Missing Items'), findsOneWidget);
    expect(find.textContaining('Bottle (Qty 1)'), findsOneWidget);

    await tester.tap(find.text('Retry Missing Items'));
    await tester.tap(find.text('Retry Missing Items'));
    await tester.pump();
    expect(repository.retryCalls, 1);
    expect(repository.retryActivityId, 'created-activity');
    expect(repository.retryItemIds, ['bottle']);
    expect(repository.createCalls, 1);

    retry.complete();
    await tester.pumpAndSettle();
    expect(find.text('Open creator'), findsOneWidget);
  });

  testWidgets('leaving partial creation warns about missing Items', (
    tester,
  ) async {
    final repository = _ActivityRepository(
      failAfterFirstItem: true,
      retryPending: Completer<void>(),
    );
    await _prepareScreen(tester, repository);
    await tester.tap(_createButton);
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Leave unfinished Activity?'), findsOneWidget);
    await tester.tap(find.text('Keep retrying'));
    await tester.pumpAndSettle();
    expect(find.text('Retry Missing Items'), findsOneWidget);

    await tester.tap(find.text('Back to Activities'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Leave Activity'));
    await tester.pumpAndSettle();
    expect(find.text('Open creator'), findsOneWidget);
    expect(repository.createCalls, 1);
  });
}
