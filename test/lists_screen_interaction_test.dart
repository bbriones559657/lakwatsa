import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item_list.dart';
import 'package:lakwatsa/repositories/list_repository.dart';
import 'package:lakwatsa/screens/lists/lists_screen.dart';

class _ListRepository extends Fake implements ListRepository {
  final List<ItemList> lists;
  final Completer<ItemList>? createPending;
  int createCalls = 0;
  int updateCalls = 0;
  ItemList? updatedList;

  _ListRepository({this.lists = const [], this.createPending});

  @override
  Stream<List<ItemList>> watchLists() => Stream.value(lists);

  @override
  Stream<List<String>> watchListItemIds(String listId) =>
      Stream.value(const []);

  @override
  Future<ItemList> addList(ItemList list) {
    createCalls++;
    return createPending?.future ??
        Future<ItemList>.value(list.copyWith(id: 'new'));
  }

  @override
  Future<void> updateList(ItemList list) async {
    updateCalls++;
    updatedList = list;
  }
}

void main() {
  testWidgets('fresh Home shortcut opens Create even after visiting Lists', (
    tester,
  ) async {
    final repository = _ListRepository();
    Widget screen({bool fromHome = false}) => MaterialApp(
      home: ListsScreen(
        key: fromHome ? UniqueKey() : null,
        openCreateOnStart: fromHome,
        listRepository: repository,
      ),
    );

    await tester.pumpWidget(screen());
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    for (var attempt = 0; attempt < 2; attempt++) {
      await tester.pumpWidget(screen(fromHome: true));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ElevatedButton, 'Create'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }
  });

  testWidgets('List dialog stays usable with a short viewport and keyboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 600);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 290);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
    });

    final repository = _ListRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: ListsScreen(openCreateOnStart: true, listRepository: repository),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).last, 'Weekend pack');
    await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -120),
    );
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ElevatedButton, 'Create'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create'));
    await tester.pumpAndSettle();
    expect(repository.createCalls, 1);
  });

  testWidgets('rapid List Create taps start only one write', (tester) async {
    final pending = Completer<ItemList>();
    final repository = _ListRepository(createPending: pending);
    await tester.pumpWidget(
      MaterialApp(
        home: ListsScreen(openCreateOnStart: true, listRepository: repository),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Weekend pack');

    final create = find.widgetWithText(ElevatedButton, 'Create');
    await tester.tap(create);
    await tester.tap(create);
    await tester.pump();
    expect(repository.createCalls, 1);

    pending.complete(
      const ItemList(id: 'new', name: 'Weekend pack', icon: 'list'),
    );
    await tester.pumpAndSettle();
    expect(find.text('New List'), findsNothing);
  });

  testWidgets('closing icon search does not reuse a disposed text controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ListsScreen(
          openCreateOnStart: true,
          listRepository: _ListRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Choose list icon',
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).last, 'camera');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear icon search'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller!.text,
      '',
    );
    await tester.tap(find.byTooltip('Close icon picker'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('New List'), findsOneWidget);
  });

  testWidgets(
    'List delete has a 48px labelled target and keeps edit behavior',
    (tester) async {
      final repository = _ListRepository(
        lists: const [
          ItemList(id: 'list-1', name: 'Weekend pack', icon: 'list'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(home: ListsScreen(listRepository: repository)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      final delete = find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Delete Weekend pack',
      );
      expect(delete, findsOneWidget);
      expect(tester.getSize(delete), const Size(48, 48));
      final target = tester.getRect(delete);
      await tester.tapAt(Offset(target.left + 3, target.top + 3));
      await tester.pumpAndSettle();
      expect(find.text('Delete List?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Weekend pack'));
      await tester.pumpAndSettle();
      expect(find.text('Edit List'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        'Weekend pack',
      );
      await tester.enterText(find.byType(TextField).last, 'Week trip');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Save Changes'));
      await tester.pumpAndSettle();
      expect(repository.updateCalls, 1);
      expect(repository.updatedList?.name, 'Week trip');
    },
  );
}
