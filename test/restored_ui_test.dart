import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lakwatsa/app/views/home_view.dart';
import 'package:lakwatsa/app/views/items_view.dart';
import 'package:lakwatsa/app/views/lists_view.dart';
import 'package:lakwatsa/app/views/activities_view.dart';
import 'package:lakwatsa/app/widgets/retro_widgets.dart';
import 'package:lakwatsa/app/list_details_screen.dart';
import 'package:lakwatsa/domain/packing.dart';
import 'package:lakwatsa/repositories/packing_repository.dart';
import 'package:lakwatsa/theme/app_theme.dart';

import 'support/settled_firestore.dart';

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);
  final item = Belonging(
    id: 'keys',
    name: 'Keys',
    category: 'Other',
    quantity: 2,
  );
  final list = PackingList(
    id: 'daily',
    name: 'Daily essentials',
    quantities: {'keys': 2},
  );
  PackingActivity activity(ActivityStatus status) => PackingActivity(
    id: 'trip',
    name: 'Real trip',
    type: 'Trip',
    status: status,
    startsAt: DateTime(2026, 10, 3, 10),
    endsAt: DateTime(2026, 10, 3, 18),
    reminderMinutes: 30,
    items: {
      'keys': const PackedItem(
        id: 'keys',
        name: 'Keys',
        category: 'Other',
        quantity: 2,
      ),
    },
    draft: {'keys': CheckMethod.manual},
  );

  Future<void> show(
    WidgetTester tester,
    Widget child, {
    double scale = 1,
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('restored dashboard uses real progress and live callbacks', (
    tester,
  ) async {
    String? opened;
    await show(
      tester,
      PackingHomeView(
        lists: [list],
        activities: [activity(ActivityStatus.active)],
        now: DateTime(2026, 10, 3, 15),
        onItems: () {},
        onNewList: () {},
        onActivities: () {},
        onLists: () {},
        onNewActivity: () {},
        onList: (_) {},
        onActivity: (id) => opened = id,
      ),
    );
    expect(find.text('Good afternoon!'), findsOneWidget);
    expect(find.text('Real trip'), findsOneWidget);
    expect(find.text('1/1'), findsOneWidget);
    expect(find.text('Beach Trip'), findsNothing);
    await tester.tap(find.text('Continue'));
    expect(opened, 'trip');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'grouped items preserve QR and archive actions on a narrow phone',
    (tester) async {
      String? qr, archived;
      await show(
        tester,
        PackingItemsView(
          items: [item],
          query: '',
          category: 'All',
          archived: false,
          onCategory: (_) {},
          onEdit: (_) {},
          onQr: (i) => qr = i.id,
          onArchive: (i) => archived = i.id,
        ),
        scale: 1.3,
      );
      expect(find.text('Keys'), findsOneWidget);
      await tester.tap(find.text('QR'));
      expect(qr, 'keys');
      await tester.tap(find.byTooltip('Options for Keys'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive item'));
      await tester.pumpAndSettle();
      expect(archived, 'keys');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('list grid exposes deletion only in edit mode', (tester) async {
    String? opened, deleted;
    Widget view(bool editing) => PackingListsView(
      lists: [list],
      query: '',
      editing: editing,
      onOpen: (l) => opened = l.id,
      onDelete: (l) => deleted = l.id,
    );
    await show(tester, view(false));
    expect(find.byTooltip('Delete Daily essentials'), findsNothing);
    await tester.tap(find.text('Daily essentials'));
    expect(opened, 'daily');
    await show(tester, view(true));
    await tester.tap(find.byTooltip('Delete Daily essentials'));
    expect(deleted, 'daily');
    expect(tester.takeException(), isNull);
  });

  testWidgets('activity filters keep history separate', (tester) async {
    String? history;
    await show(
      tester,
      PackingActivitiesView(
        activities: [activity(ActivityStatus.completed)],
        query: '',
        filter: 'Upcoming',
        onFilter: (value) => history = value,
        onOpen: (_) {},
      ),
    );
    expect(find.text('Real trip'), findsNothing);
    await tester.tap(find.text('History'));
    expect(history, 'History');
    await show(
      tester,
      PackingActivitiesView(
        activities: [activity(ActivityStatus.completed)],
        query: '',
        filter: 'History',
        onFilter: (_) {},
        onOpen: (_) {},
      ),
    );
    expect(find.text('Real trip'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom bottom navigation remains actionable with larger text', (
    tester,
  ) async {
    int? selected;
    await show(
      tester,
      RetroBottomNavigation(index: 0, onChanged: (i) => selected = i),
      scale: 1.5,
    );
    await tester.tap(find.text('Lists'));
    expect(selected, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'list details reflects saved membership and retains edit navigation',
    (tester) async {
      final repository = PackingRepository(
        userId: 'alice',
        firestore: SettledFirestore(),
      );
      await repository.saveItem(item);
      await repository.saveList(list);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PackingListDetailsScreen(
            repository: repository,
            listId: list.id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Keys'), findsOneWidget);
      expect(find.text('Other / Qty 2'), findsOneWidget);
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Edit list'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
