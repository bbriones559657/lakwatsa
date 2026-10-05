/// The only supported Activity status progression is
/// UPCOMING -> ACTIVE -> COMPLETED.
///
/// These checks are also enforced inside Firestore transactions so two
/// competing check completions cannot both change the Activity.
class ActivityStatusPolicy {
  static void requireNew(String? current) {
    _require(current, 'UPCOMING', 'create an Activity');
  }

  static void requireBefore(String? current) {
    _require(current, 'UPCOMING', 'complete the Before Check');
  }

  static void requireReturn(String? current) {
    _require(current, 'ACTIVE', 'complete the Return Check');
  }

  static void requireDraft(String? current, String checkType) {
    final expected = switch (checkType) {
      'BEFORE_ACTIVITY' => 'UPCOMING',
      'RETURN' => 'ACTIVE',
      _ => throw ArgumentError.value(checkType, 'checkType'),
    };
    _require(current, expected, 'save the $checkType draft');
  }

  static void requireEditable(String? current) {
    if (current != 'UPCOMING' && current != 'ACTIVE') {
      throw StateError(
        'Cannot add Items while the Activity is ${current ?? 'UNKNOWN'}.',
      );
    }
  }

  static bool addedDuringActivityFor(String? current) {
    requireEditable(current);
    return current == 'ACTIVE';
  }

  static void requireItemRemoval(String? current) {
    _require(current, 'UPCOMING', 'remove Items from the Activity');
  }

  static void _require(String? current, String expected, String action) {
    if (current != expected) {
      throw StateError(
        'Cannot $action: Activity is ${current ?? 'UNKNOWN'} '
        '(expected $expected).',
      );
    }
  }
}
