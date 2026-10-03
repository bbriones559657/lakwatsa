import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/domain/packing.dart';
import 'package:lakwatsa/domain/reminder_time.dart';

void main() {
  final start = DateTime.utc(2026, 10, 3, 12);
  final end = DateTime.utc(2026, 10, 3, 14);
  PackingActivity activity(ActivityStatus status, DateTime activated) =>
      PackingActivity(
        id: 'a',
        name: 'Trip',
        type: 'Trip',
        status: status,
        startsAt: start,
        endsAt: end,
        reminderMinutes: 30,
        items: {
          'i': const PackedItem(
            id: 'i',
            name: 'Keys',
            category: 'Other',
            quantity: 1,
          ),
        },
        before: CheckRecord(
          startedAt: start,
          completedAt: activated,
          itemIds: ['i'],
          found: {},
        ),
      );
  test('active activity schedules before end in absolute time', () {
    expect(
      nextReminderTime(activity(ActivityStatus.active, start), start),
      end.subtract(const Duration(minutes: 30)),
    );
  });
  test('past reminder is not replayed on resume', () {
    expect(
      nextReminderTime(
        activity(ActivityStatus.active, start),
        end.subtract(const Duration(minutes: 10)),
      ),
      isNull,
    );
  });
  test('rescheduling after the new reminder time uses the new end', () {
    final late = end.subtract(const Duration(minutes: 10));
    final changed = PackingActivity.fromMap('a', {
      ...activity(ActivityStatus.active, start).toMap(),
      'reminderUpdatedAt': late.toIso8601String(),
    });
    expect(nextReminderTime(changed, late), end);
  });
  test('late activation wins over an earlier schedule edit', () {
    final late = end.subtract(const Duration(minutes: 10));
    final changed = PackingActivity.fromMap('a', {
      ...activity(ActivityStatus.active, late).toMap(),
      'reminderUpdatedAt': start.toIso8601String(),
    });
    expect(nextReminderTime(changed, late), end);
  });
  test(
    'late activation uses end time while completed and expired have no alarm',
    () {
      final late = end.subtract(const Duration(minutes: 10));
      expect(
        nextReminderTime(activity(ActivityStatus.active, late), late),
        end,
      );
      expect(
        nextReminderTime(activity(ActivityStatus.completed, start), start),
        isNull,
      );
      expect(
        nextReminderTime(activity(ActivityStatus.active, start), end),
        isNull,
      );
    },
  );
}
