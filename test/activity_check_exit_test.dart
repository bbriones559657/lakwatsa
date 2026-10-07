import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/activity_check_draft.dart';
import 'package:lakwatsa/models/activity_item.dart';
import 'package:lakwatsa/repositories/activity_repository.dart';
import 'package:lakwatsa/screens/activities/activity_check_screen.dart';
import 'package:lakwatsa/screens/activities/activity_return_check_screen.dart';

class _DraftRepository extends Fake implements ActivityRepository {
  final List<Future<void> Function()> saveResponses;
  final Future<void> Function()? completionResponse;
  final List<Map<String, String>> savedSnapshots = [];
  int saveCalls = 0;
  int completionCalls = 0;

  _DraftRepository(
    this.saveResponses, {
    this.completionResponse,
  });

  @override
  Future<ActivityCheckDraft?> getCheckDraft({
    required String activityId,
    required String checkType,
  }) async => ActivityCheckDraft(
    startedAt: DateTime(2026, 10, 8),
    foundMethods: const {},
  );

  @override
  Stream<List<ActivityItem>> watchActivityItems(String activityId) =>
      Stream.value(const [
        ActivityItem(
          id: 'shirt',
          itemId: 'shirt',
          itemName: 'Shirt',
          category: 'Clothing',
          quantity: 1,
          icon: 'clothing',
          addedDuringActivity: false,
        ),
      ]);

  @override
  Future<void> saveCheckDraft({
    required String activityId,
    required String checkType,
    required DateTime startedAt,
    required Map<String, String> foundMethods,
  }) {
    savedSnapshots.add(Map<String, String>.from(foundMethods));
    final index = saveCalls++;
    return index < saveResponses.length
        ? saveResponses[index]()
        : Future<void>.value();
  }

  @override
  Future<void> completeBeforeActivityCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  }) {
    completionCalls++;
    return completionResponse?.call() ?? Future<void>.value();
  }

  @override
  Future<void> completeReturnCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  }) {
    completionCalls++;
    return completionResponse?.call() ?? Future<void>.value();
  }
}

class _CheckObserver extends NavigatorObserver {
  int checkPops = 0;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route.settings.name == 'check') checkPops++;
    super.didPop(route, previousRoute);
  }
}

Activity _activity(bool isReturn) {
  final date = DateTime(2026, 10, 8, 8);
  return Activity(
    id: 'activity-1',
    listId: 'list-1',
    name: 'Trip',
    type: 'Trip',
    activityDate: date,
    startAt: date,
    endAt: DateTime(2026, 10, 8, 17),
    reminderEnabled: true,
    reminderMinutes: 30,
    status: isReturn ? 'ACTIVE' : 'UPCOMING',
  );
}

Future<void> _openCheck(
  WidgetTester tester, {
  required bool isReturn,
  required _DraftRepository repository,
  required _CheckObserver observer,
  ValueNotifier<bool?>? popResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [observer],
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute<bool>(
                  settings: const RouteSettings(name: 'check'),
                  builder: (_) => isReturn
                      ? ActivityReturnCheckScreen(
                          activity: _activity(true),
                          activityRepository: repository,
                        )
                      : ActivityCheckScreen(
                          activity: _activity(false),
                          activityRepository: repository,
                        ),
                ),
              );
              popResult?.value = result;
            },
            child: const Text('Open check'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open check'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Shirt'));
  await tester.pumpAndSettle();
  expect(repository.saveCalls, 1);
}

void main() {
  for (final isReturn in [false, true]) {
    final phase = isReturn ? 'Return' : 'Before';

    testWidgets('$phase Check completion still exits once', (tester) async {
      final repository = _DraftRepository([() => Future<void>.value()]);
      final observer = _CheckObserver();
      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      final finishLabel = isReturn ? 'Finish Activity' : 'Finish Checking';
      await tester.tap(find.text(finishLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, finishLabel));
      await tester.pumpAndSettle();

      expect(repository.completionCalls, 1);
      expect(observer.checkPops, 1);
      expect(find.text('Open check'), findsOneWidget);
    });

    testWidgets('$phase Check saves and exits on Android Back', (tester) async {
      final repository = _DraftRepository([() => Future<void>.value()]);
      final observer = _CheckObserver();
      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Draft save not confirmed'), findsNothing);
      expect(find.text('Open check'), findsOneWidget);
      expect(observer.checkPops, 1);
    });

    testWidgets('$phase Check retries a failed save before exiting', (
      tester,
    ) async {
      final repository = _DraftRepository([
        () => Future<void>.error(StateError('save failed')),
        () => Future<void>.value(),
      ]);
      final observer = _CheckObserver();
      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Draft save not confirmed'), findsOneWidget);
      expect(observer.checkPops, 0);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
      await tester.pumpAndSettle();
      expect(repository.saveCalls, 2);
      expect(find.text('Open check'), findsOneWidget);
      expect(observer.checkPops, 1);
    });

    testWidgets('$phase Check can leave after a failed save', (tester) async {
      final repository = _DraftRepository([
        () => Future<void>.error(StateError('save failed')),
      ]);
      final observer = _CheckObserver();
      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.textContaining('may be lost'), findsOneWidget);
      await tester.tap(find.text('Leave without saving'));
      await tester.pumpAndSettle();

      expect(repository.saveCalls, 1);
      expect(find.text('Open check'), findsOneWidget);
      expect(observer.checkPops, 1);
    });

    testWidgets('$phase Check does not open duplicate exit dialogs', (
      tester,
    ) async {
      final pending = Completer<void>();
      final repository = _DraftRepository([() => pending.future]);
      final observer = _CheckObserver();
      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.tap(find.byIcon(Icons.arrow_back));
      pending.completeError(StateError('save failed'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await tester.tap(find.text('Leave without saving'));
      await tester.pumpAndSettle();
      expect(observer.checkPops, 1);
      expect(find.text('Open check'), findsOneWidget);
    });

    testWidgets('$phase Check can leave when saving never completes', (
      tester,
    ) async {
      final pending = Completer<void>();
      final repository = _DraftRepository([() => pending.future]);
      final observer = _CheckObserver();
      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();
      expect(find.text('Draft save not confirmed'), findsOneWidget);

      await tester.tap(find.text('Leave without saving'));
      await tester.pumpAndSettle();
      pending.complete();
      await tester.pump();
      expect(observer.checkPops, 1);
    });

    testWidgets('$phase Check ignores Back while completion is pending', (
      tester,
    ) async {
      final completion = Completer<void>();
      final repository = _DraftRepository(
        [() => Future<void>.value()],
        completionResponse: () => completion.future,
      );
      final observer = _CheckObserver();
      final popResult = ValueNotifier<bool?>(null);

      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
        popResult: popResult,
      );

      final finishLabel = isReturn ? 'Finish Activity' : 'Finish Checking';
      await tester.tap(find.text(finishLabel));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, finishLabel));
      await tester.pump();

      expect(repository.completionCalls, 1);
      expect(observer.checkPops, 0);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(observer.checkPops, 0);
      expect(find.text('Saving...'), findsOneWidget);

      completion.complete();
      await tester.pumpAndSettle();

      expect(observer.checkPops, 1);
      expect(popResult.value, isTrue);
      popResult.dispose();
    });

    testWidgets('$phase Check locks selection while exit flush is pending', (
      tester,
    ) async {
      final pending = Completer<void>();
      final repository = _DraftRepository([() => pending.future]);
      final observer = _CheckObserver();

      await _openCheck(
        tester,
        isReturn: isReturn,
        repository: repository,
        observer: observer,
      );

      expect(repository.savedSnapshots, [
        {'shirt': 'MANUAL'},
      ]);

      await tester.binding.handlePopRoute();
      await tester.pump();

      await tester.tap(find.text('Shirt'));
      await tester.pump();

      expect(repository.saveCalls, 1);
      expect(repository.savedSnapshots, [
        {'shirt': 'MANUAL'},
      ]);
      expect(find.text('0 / 1'), findsNothing);
      expect(find.text('1 / 1'), findsOneWidget);

      pending.complete();
      await tester.pumpAndSettle();

      expect(observer.checkPops, 1);
    });
  }
}
