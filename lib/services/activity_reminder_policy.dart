import '../models/activity.dart';

class ActivityReminderPolicy {
  static const String payloadPrefix = 'lakwatsa:return:';

  const ActivityReminderPolicy._();

  static DateTime? scheduledAt(Activity activity, {DateTime? now}) {
    if (!activity.reminderEnabled ||
        activity.isFinished ||
        activity.reminderMinutes <= 0) {
      return null;
    }

    final scheduled = activity.endAt.subtract(
      Duration(minutes: activity.reminderMinutes),
    );
    final current = now ?? DateTime.now();

    return scheduled.isAfter(current) ? scheduled : null;
  }

  static int notificationId({
    required String userId,
    required String activityId,
  }) {
    final value = '$userId|$activityId';
    var hash = 0x811c9dc5;

    for (final codeUnit in value.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }

    final positive = hash & 0x7fffffff;
    return positive == 0 ? 1 : positive;
  }

  static String payload({
    required String userId,
    required String activityId,
    DateTime? scheduledAt,
  }) {
    final base = '$payloadPrefix$userId:$activityId';

    if (scheduledAt == null) {
      return base;
    }

    return '$base:${scheduledAt.toUtc().millisecondsSinceEpoch}';
  }

  static bool isActivityReminderPayload(String? payload) {
    return payload != null && payload.startsWith(payloadPrefix);
  }
}
