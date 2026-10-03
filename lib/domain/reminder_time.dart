import 'packing.dart';

/// Never replay a reminder that was due while the activity was already active.
/// Starting after the reminder time instead schedules a reminder at the end.
DateTime? nextReminderTime(PackingActivity activity, DateTime now) {
  if (activity.status != ActivityStatus.active ||
      !activity.endsAt.isAfter(now)) {
    return null;
  }
  if (activity.reminderAt.isAfter(now)) return activity.reminderAt;
  final startedAt = activity.before?.completedAt;
  final updatedAt = activity.reminderUpdatedAt;
  final activatedAt =
      updatedAt != null && (startedAt == null || updatedAt.isAfter(startedAt))
      ? updatedAt
      : startedAt;
  if (activatedAt != null && !activatedAt.isBefore(activity.reminderAt)) {
    return activity.endsAt;
  }
  return null;
}
