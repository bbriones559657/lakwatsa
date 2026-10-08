import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/services/activity_reminder_policy.dart';

void main() {
  final now = DateTime(2026, 10, 8, 12);

  Activity activity({
    bool reminderEnabled = true,
    int reminderMinutes = 30,
    String status = 'UPCOMING',
    DateTime? endAt,
  }) {
    return Activity(
      id: 'activity-1',
      listId: '',
      name: 'Davao Trip',
      type: 'Trip',
      activityDate: DateTime(2026, 10, 8),
      startAt: DateTime(2026, 10, 8, 13),
      endAt: endAt ?? DateTime(2026, 10, 8, 17),
      reminderEnabled: reminderEnabled,
      reminderMinutes: reminderMinutes,
      status: status,
    );
  }

  test('schedules enabled reminder before Activity end time', () {
    expect(
      ActivityReminderPolicy.scheduledAt(activity(), now: now),
      DateTime(2026, 10, 8, 16, 30),
    );
  });

  test('does not schedule when reminder is disabled', () {
    expect(
      ActivityReminderPolicy.scheduledAt(
        activity(reminderEnabled: false),
        now: now,
      ),
      isNull,
    );
  });

  test('does not schedule completed or cancelled Activities', () {
    expect(
      ActivityReminderPolicy.scheduledAt(
        activity(status: 'COMPLETED'),
        now: now,
      ),
      isNull,
    );
    expect(
      ActivityReminderPolicy.scheduledAt(
        activity(status: 'CANCELLED'),
        now: now,
      ),
      isNull,
    );
  });

  test('does not schedule when reminder time has already passed', () {
    expect(
      ActivityReminderPolicy.scheduledAt(
        activity(endAt: DateTime(2026, 10, 8, 12, 20)),
        now: now,
      ),
      isNull,
    );
  });

  test('ACTIVE Activity can still have a future return reminder', () {
    expect(
      ActivityReminderPolicy.scheduledAt(activity(status: 'ACTIVE'), now: now),
      DateTime(2026, 10, 8, 16, 30),
    );
  });

  test('notification id is deterministic and positive', () {
    final first = ActivityReminderPolicy.notificationId(
      userId: 'user-1',
      activityId: 'activity-1',
    );
    final second = ActivityReminderPolicy.notificationId(
      userId: 'user-1',
      activityId: 'activity-1',
    );

    expect(second, first);
    expect(first, greaterThan(0));
  });

  test('different Activity identity produces a different id', () {
    final first = ActivityReminderPolicy.notificationId(
      userId: 'user-1',
      activityId: 'activity-1',
    );
    final second = ActivityReminderPolicy.notificationId(
      userId: 'user-1',
      activityId: 'activity-2',
    );

    expect(second, isNot(first));
  });

  test('recognizes only Lakwatsa Activity reminder payloads', () {
    final payload = ActivityReminderPolicy.payload(
      userId: 'user-1',
      activityId: 'activity-1',
    );

    expect(ActivityReminderPolicy.isActivityReminderPayload(payload), isTrue);
    expect(
      ActivityReminderPolicy.isActivityReminderPayload('other:payload'),
      isFalse,
    );
    expect(ActivityReminderPolicy.isActivityReminderPayload(null), isFalse);
  });

  test('scheduled payload changes when reminder time changes', () {
    final first = ActivityReminderPolicy.payload(
      userId: 'user-1',
      activityId: 'activity-1',
      scheduledAt: DateTime(2026, 10, 8, 16, 30),
    );
    final second = ActivityReminderPolicy.payload(
      userId: 'user-1',
      activityId: 'activity-1',
      scheduledAt: DateTime(2026, 10, 8, 17),
    );

    expect(first, isNot(second));
    expect(ActivityReminderPolicy.isActivityReminderPayload(first), isTrue);
  });
}
