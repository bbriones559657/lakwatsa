import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'activity_check_error_text.dart';

enum CheckExitDecision { stay, retry, leaveWithoutSaving }

Future<CheckExitDecision> showCheckExitDialog(
  BuildContext context, {
  Object? saveError,
  required bool timedOut,
}) async {
  final canRetry =
      saveError == null || !isLegacyActivityMigrationError(saveError);
  final detail = timedOut
      ? 'Saving is taking longer than expected.'
      : activityDraftSaveErrorMessage(saveError!);

  return await showDialog<CheckExitDecision>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          title: Text(
            'Draft save not confirmed',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: Text(
            '$detail The most recent unsaved check changes may be lost if you leave.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, CheckExitDecision.stay),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(
                dialogContext,
                CheckExitDecision.leaveWithoutSaving,
              ),
              child: const Text('Leave without saving'),
            ),
            if (canRetry)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.ink,
                  foregroundColor: AppColors.background,
                ),
                onPressed: () =>
                    Navigator.pop(dialogContext, CheckExitDecision.retry),
                child: const Text('Retry'),
              ),
          ],
        ),
      ) ??
      CheckExitDecision.stay;
}
