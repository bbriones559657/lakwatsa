import 'dart:async';

import 'package:flutter/material.dart';

import '../models/activity.dart' as model;
import '../models/item_list.dart';
import '../repositories/firestore_activity_repository.dart';
import '../services/activity_reminder_service.dart';
import '../services/auth_service.dart';
import 'activities/activities_screen.dart';
import 'activities/activity_details_screen.dart';
import 'activities/activity_return_check_screen.dart';
import 'home/home_screen.dart';
import 'items/my_items_screen.dart';
import 'lists/list_details_screen.dart';
import 'lists/lists_screen.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  static const _tabCount = 4;

  int currentIndex = 0;
  late final List<Widget?> pages;

  StreamSubscription<List<model.Activity>>? _reminderSubscription;
  StreamSubscription<ActivityReminderTapTarget>? _reminderTapSubscription;
  String? _reminderUserId;
  String? _pendingReminderActivityId;
  bool _openingReminderActivity = false;
  List<model.Activity> _latestReminderActivities = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pages = List<Widget?>.filled(_tabCount, null);
    pages[0] = _createPage(0);
    _startReminderTapHandling();
    _startReminderSync();
  }

  void _startReminderTapHandling() {
    _reminderTapSubscription = ActivityReminderService.instance.notificationTaps
        .listen((target) {
          final user = AuthService().currentUser;

          if (user == null || target.userId != user.uid) {
            return;
          }

          _pendingReminderActivityId = target.activityId;
          _tryOpenPendingReminderActivity();
        });

    unawaited(ActivityReminderService.instance.initialize());
  }

  void _startReminderSync() {
    final user = AuthService().currentUser;
    if (user == null) {
      return;
    }

    _reminderUserId = user.uid;
    ActivityReminderService.instance.activateUser(user.uid);
    final repository = FirestoreActivityRepository(userId: user.uid);

    _reminderSubscription = repository.watchActivities().listen(
      (activities) {
        _latestReminderActivities = List<model.Activity>.unmodifiable(
          activities,
        );
        _tryOpenPendingReminderActivity();
        _syncActivityReminders();
      },
      onError: (_) {
        // Core Activity screens surface Firestore errors themselves. Reminder
        // sync must never interrupt normal navigation.
      },
    );
  }

  void _syncActivityReminders() {
    final userId = _reminderUserId;
    if (userId == null) {
      return;
    }

    unawaited(
      ActivityReminderService.instance.reconcileForUser(
        userId: userId,
        activities: _latestReminderActivities,
      ),
    );
  }

  void _tryOpenPendingReminderActivity() {
    final activityId = _pendingReminderActivityId;

    if (!mounted || activityId == null || _openingReminderActivity) {
      return;
    }

    model.Activity? targetActivity;
    for (final activity in _latestReminderActivities) {
      if (activity.id == activityId) {
        targetActivity = activity;
        break;
      }
    }

    if (targetActivity == null) {
      return;
    }

    _pendingReminderActivityId = null;
    _openingReminderActivity = true;

    final activity = targetActivity;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        _openingReminderActivity = false;
        return;
      }

      setState(() {
        currentIndex = 3;
        pages[3] ??= _createPage(3);
      });

      Navigator.of(context)
          .push(
            MaterialPageRoute<void>(
              builder: (context) => ActivityDetailsScreen(activity: activity),
            ),
          )
          .whenComplete(() {
            _openingReminderActivity = false;
            _tryOpenPendingReminderActivity();
          });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncActivityReminders();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reminderSubscription?.cancel();
    _reminderTapSubscription?.cancel();
    super.dispose();
  }

  Widget _createPage(int index) {
    return switch (index) {
      0 => HomeScreen(
        onOpenItems: () => _selectTab(1),
        onCreateList: _openCreateList,
        onOpenLists: () => _selectTab(2),
        onOpenActivities: () => _selectTab(3),
        onContinueActivity: _openActiveReturnCheck,
        onOpenList: _openList,
      ),
      1 => const MyItemsScreen(),
      2 => const ListsScreen(),
      3 => const ActivitiesScreen(),
      _ => throw RangeError.index(index, pages, 'index'),
    };
  }

  void _selectTab(int index) {
    if (index == currentIndex) {
      return;
    }

    setState(() {
      currentIndex = index;
      pages[index] ??= _createPage(index);
    });
  }

  void _openCreateList() {
    setState(() {
      pages[2] = const ListsScreen(openCreateOnStart: true);
      currentIndex = 2;
    });
  }

  void _openActiveReturnCheck(model.Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityReturnCheckScreen(activity: activity),
      ),
    );
  }

  void _openList(ItemList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListDetailsScreen(
          listId: list.id,
          listName: list.name,
          listIcon: list.icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,
          children: List.generate(
            _tabCount,
            (index) => pages[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: currentIndex,
        onChanged: _selectTab,
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomNavigation({
    required this.currentIndex,
    required this.onChanged,
  });

  static const labels = ['Home', 'Items', 'Lists', 'Activities'];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        height: AppMetrics.bottomNavHeight,
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(
              color: AppColors.ink,
              width: AppMetrics.borderWidth,
            ),
          ),
        ),
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = currentIndex == index;
            final label = labels[index];

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: '$label tab',
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: selected
                              ? AppTextStyles.navSelected
                              : AppTextStyles.nav,
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.ink
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
