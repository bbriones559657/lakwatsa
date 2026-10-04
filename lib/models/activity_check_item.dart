class ActivityCheckItem {
  final String id;
  final String activityItemId;
  final String status;
  final String? method;
  final DateTime? checkedAt;

  const ActivityCheckItem({
    required this.id,
    required this.activityItemId,
    required this.status,
    this.method,
    this.checkedAt,
  });
}