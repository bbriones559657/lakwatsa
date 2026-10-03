import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../domain/packing.dart';
import '../repositories/packing_repository.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'activity_screen.dart';
import 'ui_helpers.dart';
import 'item_editor_screen.dart';
import 'list_editor_screen.dart';
import 'activity_editor_screen.dart';
import 'item_qr_screen.dart';
import 'list_details_screen.dart';
import 'widgets/retro_widgets.dart';
import 'views/home_view.dart';
import 'views/items_view.dart';
import 'views/lists_view.dart';
import 'views/activities_view.dart';

class PackingApp extends StatefulWidget {
  final User user;
  const PackingApp({super.key, required this.user});
  @override
  State<PackingApp> createState() => _PackingAppState();
}

class _PackingAppState extends State<PackingApp> with WidgetsBindingObserver {
  late final _repository = PackingRepository(userId: widget.user.uid);
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  List<Belonging> _items = [];
  List<PackingList> _lists = [];
  List<PackingActivity> _activities = [];
  final Set<String> _loaded = {};
  final Map<String, String> _errors = {};
  int _tab = 0;
  String _query = '', _category = 'All', _activityFilter = 'Upcoming';
  bool _archived = false, _signingOut = false, _editingLists = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
    ReminderService.instance.tappedActivity.addListener(_openNotification);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openNotification());
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    ReminderService.instance.tappedActivity.removeListener(_openNotification);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _loaded.contains('activities')) {
      ReminderService.instance.reconcile(widget.user.uid, _activities);
    }
  }

  void _listen() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    _loaded.clear();
    _errors.clear();
    void failure(String key, Object error) {
      if (mounted) setState(() => _errors[key] = errorText(error));
    }

    _subscriptions.add(
      _repository.watchItems().listen((data) {
        if (mounted) {
          setState(() {
            _items = data;
            _loaded.add('items');
            _errors.remove('items');
          });
        }
      }, onError: (Object e) => failure('items', e)),
    );
    _subscriptions.add(
      _repository.watchLists().listen((data) {
        if (mounted) {
          setState(() {
            _lists = data;
            _loaded.add('lists');
            _errors.remove('lists');
          });
        }
      }, onError: (Object e) => failure('lists', e)),
    );
    _subscriptions.add(
      _repository.watchActivities().listen((data) {
        if (mounted) {
          setState(() {
            _activities = data;
            _loaded.add('activities');
            _errors.remove('activities');
          });
          if (!_signingOut) {
            ReminderService.instance.reconcile(widget.user.uid, data);
          }
        }
      }, onError: (Object e) => failure('activities', e)),
    );
  }

  void _openNotification() {
    if (!mounted) return;
    final payload = ReminderService.instance.tappedActivity.value;
    if (payload == null) return;
    ReminderService.instance.tappedActivity.value = null;
    final parts = payload.split('/');
    if (parts.length == 2 && parts.first == widget.user.uid) {
      _openActivity(parts.last);
    }
  }

  Future<void> _open(Widget screen) =>
      Navigator.push<void>(context, MaterialPageRoute(builder: (_) => screen));
  void _openActivity(String id) =>
      _open(ActivityScreen(repository: _repository, activityId: id));
  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await ReminderService.instance.clear();
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      if (mounted) {
        setState(() => _signingOut = false);
        showMessage(context, errorText(e));
      }
    }
  }

  Future<void> _createActivity() async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => ActivityEditor(
          repository: _repository,
          lists: _lists,
          items: _items,
        ),
      ),
    );
    if (mounted && id != null) _openActivity(id);
  }

  void _selectTab(int index) => setState(() {
    _tab = index;
    _query = '';
    _editingLists = false;
  });

  void _openList(PackingList list) =>
      _open(PackingListDetailsScreen(repository: _repository, listId: list.id));
  void _newList() => _open(ListEditor(repository: _repository, items: _items));

  Future<void> _archive(Belonging item) async {
    if (await confirm(
          context,
          item.archived ? 'Restore item?' : 'Archive item?',
          'Existing lists and activity history retain their references. You can restore this item later.',
        ) &&
        mounted) {
      await _perform(() => _repository.archiveItem(item.id, !item.archived));
    }
  }

  Future<void> _deleteList(PackingList list) async {
    if (await confirm(
          context,
          'Delete ${list.name}?',
          'Your items and existing activities will be kept.',
          action: 'Delete',
        ) &&
        mounted) {
      await _perform(() => _repository.deleteList(list.id));
    }
  }

  Future<void> _retryReminders() => _perform(() async {
    await ReminderService.instance.requestPermission();
    await ReminderService.instance.reconcile(widget.user.uid, _activities);
  });

  Widget _view() => switch (_tab) {
    0 => PackingHomeView(
      lists: _lists,
      activities: _activities,
      onItems: () => _selectTab(1),
      onNewList: _newList,
      onActivities: () => _selectTab(3),
      onLists: () => _selectTab(2),
      onNewActivity: _createActivity,
      onList: _openList,
      onActivity: _openActivity,
    ),
    1 => PackingItemsView(
      items: _items,
      query: _query,
      category: _category,
      archived: _archived,
      onCategory: (value) => setState(() => _category = value),
      onEdit: (item) => _open(ItemEditor(repository: _repository, item: item)),
      onQr: (item) => _open(ItemQrScreen(item: item, userId: widget.user.uid)),
      onArchive: _archive,
    ),
    2 => PackingListsView(
      lists: _lists,
      query: _query,
      editing: _editingLists,
      onOpen: _openList,
      onDelete: _deleteList,
    ),
    _ => PackingActivitiesView(
      activities: _activities,
      query: _query,
      filter: _activityFilter,
      onFilter: (value) => setState(() => _activityFilter = value),
      onOpen: _openActivity,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final ready = _loaded.length == 3 && _errors.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          const ['Lakwatsa', 'My Items', 'Lists', 'Activities'][_tab],
        ),
        actions: [
          if (_tab == 2)
            OutlinedButton(
              onPressed: ready
                  ? () => setState(() => _editingLists = !_editingLists)
                  : null,
              child: Text(_editingLists ? 'Done' : 'Edit'),
            ),
          if (_tab != 0)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton.filled(
                tooltip: const [
                  '',
                  'Add item',
                  'Create list',
                  'Create activity',
                ][_tab],
                onPressed: !ready
                    ? null
                    : () {
                        if (_tab == 1) {
                          _open(ItemEditor(repository: _repository));
                        }
                        if (_tab == 2) _newList();
                        if (_tab == 3) _createActivity();
                      },
                icon: const Icon(Icons.add, color: AppColors.background),
              ),
            ),
          PopupMenuButton<String>(
            tooltip: 'Account and reminders',
            icon: _tab == 0
                ? const CircleAvatar(
                    backgroundColor: AppColors.background,
                    foregroundColor: AppColors.ink,
                    child: Icon(Icons.person_outline),
                  )
                : const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'signout') _signOut();
              if (value == 'reminders') _retryReminders();
              if (value == 'archive') setState(() => _archived = !_archived);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Text(widget.user.email ?? 'Your account'),
              ),
              if (_tab == 1)
                PopupMenuItem(
                  value: 'archive',
                  child: Text(
                    _archived ? 'Show current items' : 'Show archived items',
                  ),
                ),
              const PopupMenuItem(
                value: 'reminders',
                child: Text('Retry reminders'),
              ),
              PopupMenuItem(
                value: 'signout',
                enabled: !_signingOut,
                child: const Text('Sign out'),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _errors.isNotEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_errors.values.join('\n')),
                      TextButton(
                        onPressed: () => setState(_listen),
                        child: const Text('Retry loading'),
                      ),
                    ],
                  ),
                ),
              )
            : !ready
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  ValueListenableBuilder<String?>(
                    valueListenable: ReminderService.instance.warning,
                    builder: (_, message, _) => message == null
                        ? const SizedBox.shrink()
                        : MaterialBanner(
                            content: Text(message),
                            actions: [
                              TextButton(
                                onPressed: _retryReminders,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                  ),
                  if (_tab != 0)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                      child: RetroSearch(
                        key: ValueKey(_tab),
                        hint: const [
                          '',
                          'Search items...',
                          'Search lists...',
                          'Search activities...',
                        ][_tab],
                        onChanged: (value) =>
                            setState(() => _query = value.trim().toLowerCase()),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      key: ValueKey('tab-$_tab'),
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
                      children: [_view()],
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: RetroBottomNavigation(
        index: _tab,
        onChanged: _selectTab,
      ),
    );
  }
}
