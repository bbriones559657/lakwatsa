import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/services/activity_reminder_service.dart';

void main() {
  test('parses current Activity reminder payload with schedule timestamp', () {
    final target = ActivityReminderService.parseTapTarget(
      'lakwatsa:return:user-1:activity-1:1791456420000',
    );

    expect(target, isNotNull);
    expect(target!.userId, 'user-1');
    expect(target.activityId, 'activity-1');
  });

  test('parses legacy Activity reminder payload without timestamp', () {
    final target = ActivityReminderService.parseTapTarget(
      'lakwatsa:return:user-1:activity-1',
    );

    expect(target, isNotNull);
    expect(target!.userId, 'user-1');
    expect(target.activityId, 'activity-1');
  });

  test('rejects unrelated notification payload', () {
    expect(
      ActivityReminderService.parseTapTarget('other:user-1:activity-1'),
      isNull,
    );
  });

  test('rejects incomplete Activity reminder payload', () {
    expect(
      ActivityReminderService.parseTapTarget('lakwatsa:return:user-1:'),
      isNull,
    );
  });
}
