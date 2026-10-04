class ActivityCheck {
  final String id;
  final String type;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const ActivityCheck({
    required this.id,
    required this.type,
    required this.status,
    this.startedAt,
    this.completedAt,
  });
}
