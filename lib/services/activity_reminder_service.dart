import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/activity.dart';
import 'activity_reminder_policy.dart';

class _ExactAlarmResumeWaiter with WidgetsBindingObserver {
  final Completer<void> _resumed = Completer<void>();
  bool _leftApp = false;

  Future<void> get resumed => _resumed.future;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _leftApp = true;
      return;
    }

    if (_leftApp &&
        state == AppLifecycleState.resumed &&
        !_resumed.isCompleted) {
      _resumed.complete();
    }
  }
}

class _ExpectedActivityReminder {
  final int id;
  final Activity activity;
  final DateTime scheduledAt;
  final String payload;

  const _ExpectedActivityReminder({
    required this.id,
    required this.activity,
    required this.scheduledAt,
    required this.payload,
  });
}

class ActivityReminderTapTarget {
  final String userId;
  final String activityId;

  const ActivityReminderTapTarget({
    required this.userId,
    required this.activityId,
  });
}

class ActivityReminderService {
  ActivityReminderService._();

  static final ActivityReminderService instance = ActivityReminderService._();

  static const String activityReminderChannelId =
      'lakwatsa_activity_return_reminders';
  static const String activityReminderGroupKey =
      'lakwatsa.activity_return_reminders';

  static const AndroidNotificationChannel _androidChannel =
      AndroidNotificationChannel(
        activityReminderChannelId,
        'Activity return reminders',
        description:
            'Reminders to check your belongings before an Activity ends.',
        importance: Importance.high,
      );

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final StreamController<ActivityReminderTapTarget> _notificationTapController =
      StreamController<ActivityReminderTapTarget>.broadcast(sync: true);

  bool _initialized = false;
  String? _lastHandledTapPayload;
  bool _available = false;
  Future<void>? _initializing;
  Future<void> _notificationMutationQueue = Future<void>.value();
  String? _activeUserId;
  int _sessionGeneration = 0;

  Stream<ActivityReminderTapTarget> get notificationTaps =>
      _notificationTapController.stream;

  void activateUser(String userId) {
    if (_activeUserId == userId) {
      return;
    }

    _activeUserId = userId;
    _sessionGeneration++;
    _lastHandledTapPayload = null;
  }

  bool _sessionMatches(String userId, int generation) {
    return _activeUserId == userId && _sessionGeneration == generation;
  }

  Future<void> _enqueueNotificationMutation(Future<void> Function() operation) {
    final next = _notificationMutationQueue.then((_) => operation()).catchError(
      (Object error, StackTrace stackTrace) {
        debugPrint('Activity reminder mutation failed: $error');
      },
    );

    _notificationMutationQueue = next;
    return next;
  }

  static bool isActivityReminderActiveNotification(
    ActiveNotification notification, {
    TargetPlatform? platform,
  }) {
    final targetPlatform = platform ?? defaultTargetPlatform;

    if (targetPlatform == TargetPlatform.android) {
      // Notification channels only exist on Android 8.0 / API 26+. The
      // dedicated group key is also available on API 24-25, which Lakwatsa
      // supports. Either identifier is enough to recognize our delivered
      // Activity reminders without touching unrelated notifications.
      return notification.groupKey == activityReminderGroupKey ||
          notification.channelId == activityReminderChannelId;
    }

    return ActivityReminderPolicy.isActivityReminderPayload(
      notification.payload,
    );
  }

  static ActivityReminderTapTarget? parseTapTarget(String? payload) {
    if (payload == null ||
        !payload.startsWith(ActivityReminderPolicy.payloadPrefix)) {
      return null;
    }

    final body = payload.substring(ActivityReminderPolicy.payloadPrefix.length);
    final parts = body.split(':');

    if (parts.length < 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return null;
    }

    return ActivityReminderTapTarget(userId: parts[0], activityId: parts[1]);
  }

  static bool get isSupportedPlatform {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  Future<void> initialize() async {
    if (!isSupportedPlatform || _initialized) {
      return;
    }

    final inProgress = _initializing;
    if (inProgress != null) {
      await inProgress;
      return;
    }

    final future = _initializeInternal();
    _initializing = future;

    try {
      await future;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initializeInternal() async {
    try {
      tz_data.initializeTimeZones();

      try {
        final localTimeZone = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(localTimeZone.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_lakwatsa'),
        iOS: darwinSettings,
        macOS: darwinSettings,
      );

      await _notifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
      );

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        await android?.createNotificationChannel(_androidChannel);
      }

      _available = true;
      await _emitLaunchNotificationIfNeeded();
    } catch (error) {
      debugPrint('Activity reminder initialization failed: $error');
      _available = false;
    } finally {
      _initialized = true;
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    _emitTapPayload(response.payload);
  }

  Future<void> _emitLaunchNotificationIfNeeded() async {
    final launchDetails = await _notifications
        .getNotificationAppLaunchDetails();

    if (launchDetails?.didNotificationLaunchApp != true) {
      return;
    }

    _emitTapPayload(launchDetails?.notificationResponse?.payload);
  }

  void _emitTapPayload(String? payload) {
    final target = parseTapTarget(payload);

    if (target == null || payload == _lastHandledTapPayload) {
      return;
    }

    _lastHandledTapPayload = payload;
    _notificationTapController.add(target);
  }

  Future<bool> requestPermission() async {
    if (!isSupportedPlatform) {
      return false;
    }

    await initialize();
    if (!_available) {
      return false;
    }

    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        if (android == null) {
          return true;
        }

        final notificationsGranted =
            await android.requestNotificationsPermission() ?? true;

        if (!notificationsGranted) {
          return false;
        }

        final canScheduleExactly = await android
            .canScheduleExactNotifications();

        if (canScheduleExactly == false) {
          final waiter = _ExactAlarmResumeWaiter();
          WidgetsBinding.instance.addObserver(waiter);

          try {
            await android.requestExactAlarmsPermission();

            // Some Android versions/OEMs may grant immediately. If not, the
            // Settings intent returns before the user can interact, so wait
            // until Lakwatsa actually resumes before checking again.
            final grantedImmediately = await android
                .canScheduleExactNotifications();

            if (grantedImmediately == true) {
              return true;
            }

            await waiter.resumed;
            return await android.canScheduleExactNotifications() ?? false;
          } finally {
            WidgetsBinding.instance.removeObserver(waiter);
          }
        }

        return true;
      }

      if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();

        if (ios == null) {
          return true;
        }

        return await ios.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      }

      if (defaultTargetPlatform == TargetPlatform.macOS) {
        final macos = _notifications
            .resolvePlatformSpecificImplementation<
              MacOSFlutterLocalNotificationsPlugin
            >();

        if (macos == null) {
          return true;
        }

        return await macos.requestPermissions(
              alert: true,
              badge: true,
              sound: true,
            ) ??
            true;
      }
    } catch (error) {
      debugPrint('Notification permission request failed: $error');
      return false;
    }

    return false;
  }

  Future<void> reconcileForUser({
    required String userId,
    required List<Activity> activities,
  }) {
    if (!isSupportedPlatform) {
      return Future<void>.value();
    }

    final generation = _sessionGeneration;
    final snapshot = List<Activity>.unmodifiable(activities);

    return _enqueueNotificationMutation(
      () => _reconcileForUserLocked(
        userId: userId,
        activities: snapshot,
        generation: generation,
      ),
    );
  }

  Future<void> _reconcileForUserLocked({
    required String userId,
    required List<Activity> activities,
    required int generation,
  }) async {
    if (!_sessionMatches(userId, generation)) {
      return;
    }

    await initialize();

    if (!_available || !_sessionMatches(userId, generation)) {
      return;
    }

    try {
      final expected = <int, _ExpectedActivityReminder>{};

      for (final activity in activities) {
        final scheduledAt = ActivityReminderPolicy.scheduledAt(activity);
        if (scheduledAt == null) {
          continue;
        }

        final id = ActivityReminderPolicy.notificationId(
          userId: userId,
          activityId: activity.id,
        );
        final payload = ActivityReminderPolicy.payload(
          userId: userId,
          activityId: activity.id,
          scheduledAt: scheduledAt,
        );

        expected[id] = _ExpectedActivityReminder(
          id: id,
          activity: activity,
          scheduledAt: scheduledAt,
          payload: payload,
        );
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();

        final canScheduleExactly = await android
            ?.canScheduleExactNotifications();

        if (!_sessionMatches(userId, generation) ||
            canScheduleExactly == false) {
          return;
        }
      }

      final pending = await _notifications.pendingNotificationRequests();

      if (!_sessionMatches(userId, generation)) {
        return;
      }

      final alreadyCorrect = <int>{};

      for (final request in pending) {
        if (!ActivityReminderPolicy.isActivityReminderPayload(
          request.payload,
        )) {
          continue;
        }

        if (!_sessionMatches(userId, generation)) {
          return;
        }

        final reminder = expected[request.id];

        if (reminder == null || request.payload != reminder.payload) {
          await _notifications.cancel(id: request.id);
          continue;
        }

        alreadyCorrect.add(request.id);
      }

      for (final reminder in expected.values) {
        if (!_sessionMatches(userId, generation)) {
          return;
        }

        if (alreadyCorrect.contains(reminder.id)) {
          continue;
        }

        try {
          await _schedule(reminder: reminder);
        } catch (error) {
          // One bad Activity must not prevent the user's other valid
          // reminders from being scheduled.
          debugPrint(
            'Unable to schedule Activity reminder '
            '${reminder.activity.id}: $error',
          );
        }
      }
    } catch (error) {
      debugPrint('Activity reminder sync failed: $error');
    }
  }

  Future<void> cancelAllActivityReminders() {
    // Invalidate every queued/in-flight reconciliation immediately. The
    // serialized cleanup below then removes anything that may have been
    // scheduled before the invalidation was observed.
    _activeUserId = null;
    _sessionGeneration++;
    _lastHandledTapPayload = null;

    if (!isSupportedPlatform) {
      return Future<void>.value();
    }

    return _enqueueNotificationMutation(_cancelAllActivityRemindersLocked);
  }

  Future<void> _cancelAllActivityRemindersLocked() async {
    await initialize();

    if (!_available) {
      return;
    }

    try {
      final pending = await _notifications.pendingNotificationRequests();

      for (final request in pending) {
        if (ActivityReminderPolicy.isActivityReminderPayload(request.payload)) {
          await _notifications.cancel(id: request.id);
        }
      }

      // Pending requests do not include reminders that already fired.
      // Remove delivered Lakwatsa Activity reminders as part of sign-out
      // cleanup so the previous user's Activity name is not left visible.
      final active = await _notifications.getActiveNotifications();

      for (final notification in active) {
        final id = notification.id;

        if (id != null && isActivityReminderActiveNotification(notification)) {
          await _notifications.cancel(id: id);
        }
      }
    } catch (error) {
      debugPrint('Unable to clear Activity reminders: $error');
    }
  }

  Future<void> _schedule({required _ExpectedActivityReminder reminder}) async {
    await _notifications.zonedSchedule(
      id: reminder.id,
      title: 'Return check reminder',
      body:
          '${reminder.activity.name} ends soon. Check that you have all your '
          'items before leaving.',
      scheduledDate: tz.TZDateTime.from(reminder.scheduledAt, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          activityReminderChannelId,
          'Activity return reminders',
          channelDescription:
              'Reminders to check your belongings before an Activity ends.',
          importance: Importance.high,
          priority: Priority.high,
          groupKey: activityReminderGroupKey,
        ),
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: reminder.payload,
    );

    debugPrint(
      'Activity reminder scheduled: ${reminder.activity.id} '
      'at ${reminder.scheduledAt.toIso8601String()}',
    );
  }
}
