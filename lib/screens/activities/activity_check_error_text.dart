bool isLegacyActivityMigrationError(Object error) {
  return error.toString().contains('secure migration');
}

String activityDraftSaveErrorMessage(Object error) {
  final message = error.toString();

  if (isLegacyActivityMigrationError(error)) {
    return 'This older Activity needs a one-time secure upgrade before '
        'check progress can be saved.';
  }

  if (message.contains('Activity Items changed')) {
    return 'Activity Items changed. Reopen the Activity before continuing.';
  }

  if (message.contains('Activity no longer exists')) {
    return 'This Activity no longer exists.';
  }

  return 'Progress not saved. Check your connection and try again.';
}

String activityCheckFinishErrorMessage(Object error) {
  final message = error.toString();

  if (isLegacyActivityMigrationError(error)) {
    return 'This older Activity needs a one-time secure upgrade before '
        'this check can be finished.';
  }

  if (message.contains('Activity Items changed')) {
    return 'Activity Items changed. Reopen the Activity and review the list.';
  }

  if (message.contains('Activity no longer exists')) {
    return 'This Activity no longer exists.';
  }

  return 'Could not finish the check. Please try again.';
}
