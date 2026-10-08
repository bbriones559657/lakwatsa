import 'dart:async';

import 'package:flutter/material.dart';

import '../models/activity.dart' as model;
import '../models/item_list.dart';
import '../repositories/firestore_activity_repository.dart';
import '../services/activity_reminder_service.dart';
import '../services/activity_reminder_navigation.dart';
import '../services/auth_service.dart';
import 'activities/activities_screen.dart';
import 'activities/activity_details_screen.dart';
import 'activities/activity_return_check_screen.dart';
import 'auth/sign_out_dialog.dart';
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
  ActivityReminderNavigation? _reminderNavigation;
  bool _signOutDialogOpen = false;
  List<model.Activity> _latestReminderActivities = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    pages = List<Widget?>.filled(_tabCount, null);
    pages[0] = _createPage(0);
    _startReminderSync();
    _startReminderTapHandling();
  }

  void _startReminderTapHandling() {
    _reminderTapSubscription = ActivityReminderService.instance.notificationTaps
        .listen((target) {
          final user = AuthService().currentUser;

          if (user == null || target.userId != user.uid) {
            return;
          }

          _reminderNavigation?.handleTap(target);
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
    _reminderNavigation = ActivityReminderNavigation(
      userId: user.uid,
      loadActivity: repository.getActivity,
      openActivity: _openReminderActivity,
      showMessage: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      },
    );

    _reminderSubscription = repository.watchActivities().listen(
      (activities) {
        _latestReminderActivities = List<model.Activity>.unmodifiable(
          activities,
        );
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

  Future<void> _openReminderActivity(model.Activity activity) async {
    if (!mounted || AuthService().currentUser?.uid != _reminderUserId) return;
    setState(() {
      currentIndex = 3;
      pages[3] ??= _createPage(3);
    });
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => ActivityDetailsScreen(activity: activity),
      ),
    );
  }

  Future<void> _signOut() async {
    if (_signOutDialogOpen) return;
    _signOutDialogOpen = true;
    _reminderNavigation?.setPaused(true);
    try {
      await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const SignOutDialog(),
      );
    } finally {
      _signOutDialogOpen = false;
      if (mounted && AuthService().currentUser?.uid == _reminderUserId) {
        // A failed Firebase sign-out can leave the session active after native
        // reminder cleanup. Restore synchronization when the user stays.
        ActivityReminderService.instance.activateUser(_reminderUserId!);
        _syncActivityReminders();
        _reminderNavigation?.setPaused(false);
      }
    }
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
    _reminderNavigation?.dispose();
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
        onSignOut: _signOut,
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
      // Each Home shortcut invocation must run the create-on-start action,
      // including when the Lists tab already has mounted State.
      pages[2] = ListsScreen(key: UniqueKey(), openCreateOnStart: true);
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
