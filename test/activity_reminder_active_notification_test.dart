import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/services/activity_reminder_service.dart';

void main() {
  test(
    'Android identifies delivered Activity reminder by dedicated channel',
    () {
      const notification = ActiveNotification(
        id: 1,
        channelId: ActivityReminderService.activityReminderChannelId,
        payload: null,
      );

      expect(
        ActivityReminderService.isActivityReminderActiveNotification(
          notification,
          platform: TargetPlatform.android,
        ),
        isTrue,
      );
    },
  );

  test('Android leaves delivered notification from another channel alone', () {
    const notification = ActiveNotification(
      id: 2,
      channelId: 'some_other_channel',
      payload: null,
    );

    expect(
      ActivityReminderService.isActivityReminderActiveNotification(
        notification,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
  });

  test('iOS identifies delivered Activity reminder by payload', () {
    const notification = ActiveNotification(
      id: 3,
      payload: 'lakwatsa:return:user-1:activity-1:1791472020000',
    );

    expect(
      ActivityReminderService.isActivityReminderActiveNotification(
        notification,
        platform: TargetPlatform.iOS,
      ),
      isTrue,
    );
  });

  test('iOS leaves unrelated delivered notification alone', () {
    const notification = ActiveNotification(
      id: 4,
      payload: 'other:notification',
    );

    expect(
      ActivityReminderService.isActivityReminderActiveNotification(
        notification,
        platform: TargetPlatform.iOS,
      ),
      isFalse,
    );
  });

  test('Android API 24-25 identifies reminder when channel is null', () {
    const notification = ActiveNotification(
      id: 5,
      channelId: null,
      groupKey: ActivityReminderService.activityReminderGroupKey,
      payload: null,
    );

    expect(
      ActivityReminderService.isActivityReminderActiveNotification(
        notification,
        platform: TargetPlatform.android,
      ),
      isTrue,
    );
  });

  test('Android null channel with unrelated group remains untouched', () {
    const notification = ActiveNotification(
      id: 6,
      channelId: null,
      groupKey: 'some_other_group',
      payload: null,
    );

    expect(
      ActivityReminderService.isActivityReminderActiveNotification(
        notification,
        platform: TargetPlatform.android,
      ),
      isFalse,
    );
  });
}
