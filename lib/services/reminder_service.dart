import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/packing.dart';
import '../domain/reminder_time.dart';

class ReminderService {
  static final instance = ReminderService._();
  ReminderService._();
  final _plugin = FlutterLocalNotificationsPlugin();
  final ValueNotifier<String?> tappedActivity = ValueNotifier(null);
  final ValueNotifier<String?> warning = ValueNotifier(null);
  bool _ready = false;
  Future<void> _queue = Future.value();
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  Future<void> initialize() async {
    if (_ready || !supported) return;
    try {
      tzdata.initializeTimeZones();
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_notification'),
        ),
        onDidReceiveNotificationResponse: (response) =>
            tappedActivity.value = response.payload,
      );
      final launch = await _plugin.getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp == true) {
        tappedActivity.value = launch?.notificationResponse?.payload;
      }
      _ready = true;
      warning.value = null;
    } catch (_) {
      warning.value =
          'Reminders could not start. Open notification settings and retry.';
    }
  }

  Future<bool> requestPermission() async {
    await initialize();
    if (!_ready) return false;
    final allowed =
        await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
    warning.value = allowed ? null : 'Notifications are disabled. Enable them in Android Settings to receive reminders.';
    return allowed;
  }

  Future<void> clear() {
    _queue = _queue
        .then((_) async {
          if (_ready) await _plugin.cancelAll();
        })
        .catchError((Object _) {
          warning.value =
              'Could not clear reminders. Check Android notification settings.';
        });
    return _queue;
  }

  Future<void> reconcile(String userId, List<PackingActivity> activities) {
    _queue = _queue.then((_) => _sync(userId, activities)).catchError((
      Object _,
    ) {
      warning.value = 'Some reminders could not be scheduled. Use Retry reminders in the account menu.';
    });
    return _queue;
  }

  Future<void> _sync(String userId, List<PackingActivity> activities) async {
    await initialize();
    if (!_ready) return;
    final pending = await _plugin.pendingNotificationRequests();
    final desired = <String, PackingActivity>{};
    final now = DateTime.now();
    for (final activity in activities) {
      if (activity.status == ActivityStatus.active &&
          activity.endsAt.isAfter(now)) {
        desired['$userId/${activity.id}'] = activity;
      }
    }
    for (final entry in pending) {
      if (!desired.containsKey(entry.payload)) {
        await _plugin.cancel(id: entry.id);
      }
    }
    final usedIds = pending.map((e) => e.id).toSet();
    for (final entry in desired.entries) {
      final existing = pending.where((n) => n.payload == entry.key).firstOrNull;
      var id = existing?.id ?? 1;
      if (existing == null) {
        while (usedIds.contains(id)) {
          id++;
        }
        usedIds.add(id);
      }
      final time = nextReminderTime(entry.value, now);
      // Leave an already pending overdue alarm to Android's inexact delivery.
      if (time == null) continue;
      await _plugin.zonedSchedule(
        id: id,
        title: 'Check your belongings',
        body: 'Before leaving ${entry.value.name}, complete your return check.',
        scheduledDate: tz.TZDateTime.from(time, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'activity_reminders',
            'Activity reminders',
            channelDescription: 'Check belongings before heading home',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: entry.key,
      );
    }
  }
}
