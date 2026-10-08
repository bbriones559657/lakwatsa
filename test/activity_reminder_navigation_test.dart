import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/services/activity_reminder_navigation.dart';
import 'package:lakwatsa/services/activity_reminder_service.dart';

Activity _activity(String id) => Activity(
  id: id,
  listId: 'list',
  name: id,
  type: 'Trip',
  activityDate: DateTime(2026, 10, 8),
  startAt: DateTime(2026, 10, 8, 8),
  endAt: DateTime(2026, 10, 8, 17),
  reminderEnabled: true,
  reminderMinutes: 30,
  status: 'ACTIVE',
);

ActivityReminderTapTarget _tap(String id, [String userId = 'user']) =>
    ActivityReminderTapTarget(userId: userId, activityId: id);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'missing target is consumed once and the next valid tap opens',
    () async {
      final loaded = <String>[];
      final opened = <String>[];
      final messages = <String>[];
      final navigation = ActivityReminderNavigation(
        userId: 'user',
        loadActivity: (id) async {
          loaded.add(id);
          return id == 'missing' ? null : _activity(id);
        },
        openActivity: (activity) async => opened.add(activity.id),
        showMessage: messages.add,
      );
      navigation.handleTap(_tap('missing'));
      await _settle();
      navigation.setPaused(true);
      navigation.setPaused(false);
      await _settle();
      expect(loaded, ['missing']);
      expect(messages, ['This Activity is no longer available.']);
      navigation.handleTap(_tap('valid'));
      await _settle();
      expect(opened, ['valid']);
      navigation.dispose();
    },
  );

  test('lookup errors do not stick or trigger automatic retries', () async {
    var reads = 0;
    final messages = <String>[];
    final navigation = ActivityReminderNavigation(
      userId: 'user',
      loadActivity: (_) async {
        reads++;
        throw StateError('offline');
      },
      openActivity: (_) async {},
      showMessage: messages.add,
    );
    navigation.handleTap(_tap('bad'));
    await _settle();
    navigation.setPaused(false);
    await _settle();
    expect(reads, 1);
    expect(messages.single, contains('Could not open'));
    navigation.dispose();
  });

  test(
    'ignores other users and prevents duplicate routes while open',
    () async {
      final closing = Completer<void>();
      final opened = <String>[];
      final navigation = ActivityReminderNavigation(
        userId: 'user',
        loadActivity: (id) async => _activity(id),
        openActivity: (activity) {
          opened.add(activity.id);
          return closing.future;
        },
        showMessage: (_) {},
      );
      navigation.handleTap(_tap('foreign', 'someone-else'));
      navigation.handleTap(_tap('first'));
      await _settle();
      navigation.handleTap(_tap('first'));
      navigation.handleTap(_tap('second'));
      await _settle();
      expect(opened, ['first']);
      closing.complete();
      await _settle();
      expect(opened, ['first', 'second']);
      navigation.dispose();
    },
  );

  test(
    'logout pauses navigation and disposal invalidates in-flight lookup',
    () async {
      final loading = Completer<Activity?>();
      final opened = <String>[];
      final navigation = ActivityReminderNavigation(
        userId: 'user',
        loadActivity: (_) => loading.future,
        openActivity: (activity) async => opened.add(activity.id),
        showMessage: (_) => fail('Disposed session must not show a message'),
      );
      navigation.handleTap(_tap('first'));
      navigation.setPaused(true);
      loading.complete(_activity('first'));
      await _settle();
      expect(opened, isEmpty);
      navigation.dispose();
      navigation.setPaused(false);
      await _settle();
      expect(opened, isEmpty);
    },
  );

  test('cancelled logout resumes a pending tap', () async {
    final opened = <String>[];
    final navigation = ActivityReminderNavigation(
      userId: 'user',
      loadActivity: (id) async => _activity(id),
      openActivity: (activity) async => opened.add(activity.id),
      showMessage: (_) {},
    );
    navigation.setPaused(true);
    navigation.handleTap(_tap('first'));
    await _settle();
    expect(opened, isEmpty);
    navigation.setPaused(false);
    await _settle();
    expect(opened, ['first']);
    navigation.dispose();
  });
}
