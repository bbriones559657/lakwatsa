import 'package:flutter/material.dart';

String errorText(Object error) {
  final value = error.toString();
  if (value.contains('TimeoutException')) {
    return 'Server confirmation is delayed. Your change may still be queued. Reconnect and check your saved data before retrying.';
  }
  if (value.contains('permission-denied')) {
    return 'Access denied. Check that your account is signed in and Firestore rules are configured.';
  }
  if (value.contains('unavailable') || value.contains('network')) {
    return 'Unable to reach the server. Check your connection and retry.';
  }
  return value
      .replaceFirst('Invalid argument(s): ', '')
      .replaceFirst('Bad state: ', '');
}

void showMessage(BuildContext context, String text) =>
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
Future<bool> confirm(
  BuildContext context,
  String title,
  String message, {
  String action = 'Confirm',
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    ) ??
    false;

String dateLabel(DateTime value) {
  final date = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${pad(date.month)}-${pad(date.day)} ${pad(date.hour)}:${pad(date.minute)}';
}

Future<DateTime?> chooseDate(BuildContext context, DateTime initial) async {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day);
  final date = await showDatePicker(
    context: context,
    initialDate: initial.isBefore(start) ? start : initial,
    firstDate: start,
    lastDate: DateTime(now.year + 5),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
