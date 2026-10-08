import 'dart:async';

import '../models/activity.dart';
import 'activity_reminder_service.dart';

/// Resolves each notification once, independently of the Activity list stream.
/// A missing document or failed lookup must not leave a target to retry on
/// every subsequent Firestore snapshot.
class ActivityReminderNavigation {
  final String userId;
  final Future<Activity?> Function(String id) loadActivity;
  final Future<void> Function(Activity activity) openActivity;
  final void Function(String message) showMessage;

  ActivityReminderNavigation({
    required this.userId,
    required this.loadActivity,
    required this.openActivity,
    required this.showMessage,
  });

  String? _pendingId;
  String? _openingId;
  bool _paused = false;
  bool _disposed = false;

  void handleTap(ActivityReminderTapTarget target) {
    if (_disposed ||
        target.userId != userId ||
        target.activityId == _openingId) {
      return;
    }
    _pendingId = target.activityId;
    unawaited(_drain());
  }

  void setPaused(bool paused) {
    _paused = paused;
    if (!paused) unawaited(_drain());
  }

  Future<void> _drain() async {
    if (_disposed || _paused || _openingId != null || _pendingId == null) {
      return;
    }
    final id = _pendingId!;
    _pendingId = null;
    _openingId = id;
    try {
      final activity = await loadActivity(id)
          .timeout(const Duration(seconds: 10));
      if (_disposed) return;
      if (_paused) {
        _pendingId ??= id;
        return;
      }
      if (activity == null) {
        showMessage('This Activity is no longer available.');
      } else {
        await openActivity(activity);
      }
    } catch (_) {
      if (!_disposed && !_paused) {
        showMessage('Could not open this Activity. Please check Activities.');
      }
    } finally {
      _openingId = null;
      if (!_disposed) unawaited(_drain());
    }
  }

  void dispose() {
    _disposed = true;
    _pendingId = null;
  }
}
