class Activity {
  final String id;
  final String listId;
  final String name;
  final String type;

  final DateTime activityDate;
  final DateTime startAt;
  final DateTime endAt;

  final bool reminderEnabled;
  final int reminderMinutes;

  final String status;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Activity({
    required this.id,
    required this.listId,
    required this.name,
    required this.type,
    required this.activityDate,
    required this.startAt,
    required this.endAt,
    required this.reminderEnabled,
    required this.reminderMinutes,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  Activity copyWith({
    String? id,
    String? listId,
    String? name,
    String? type,
    DateTime? activityDate,
    DateTime? startAt,
    DateTime? endAt,
    bool? reminderEnabled,
    int? reminderMinutes,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      type: type ?? this.type,
      activityDate:
          activityDate ?? this.activityDate,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      reminderEnabled:
          reminderEnabled ?? this.reminderEnabled,
      reminderMinutes:
          reminderMinutes ?? this.reminderMinutes,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isUpcoming {
    return status == 'UPCOMING';
  }

  bool get isActive {
    return status == 'ACTIVE';
  }

  bool get isCompleted {
    return status == 'COMPLETED';
  }

  bool get isCancelled {
    return status == 'CANCELLED';
  }

  bool get isFinished {
    return isCompleted || isCancelled;
  }
}