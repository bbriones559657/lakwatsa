import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../models/item.dart';
import '../../models/item_list.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../repositories/item_repository.dart';
import '../../repositories/list_repository.dart';
import '../../services/activity_reminder_policy.dart';
import '../../services/activity_reminder_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'activity_item_selection.dart';
import '../items/item_icon_catalog.dart';
import '../lists/add_items_screen.dart';
import '../lists/list_icon_catalog.dart';

class CreateActivityScreen extends StatefulWidget {
  final ActivityRepository? activityRepository;
  final ItemRepository? itemRepository;
  final ListRepository? listRepository;
  final Future<bool> Function()? requestReminderPermission;

  const CreateActivityScreen({
    super.key,
    this.activityRepository,
    this.itemRepository,
    this.listRepository,
    this.requestReminderPermission,
  });

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final TextEditingController nameController = TextEditingController();

  ListRepository? listRepository;
  ItemRepository? itemRepository;
  ActivityRepository? activityRepository;

  Stream<List<ItemList>>? listsStream;
  final ScrollController activityItemsScrollController = ScrollController();

  String selectedType = 'Trip';

  final Set<String> selectedListIds = <String>{};
  List<Item> importedListItems = [];
  final Map<String, Item> manuallyAddedItems = <String, Item>{};
  final Set<String> removedItemIds = <String>{};
  final Map<String, int> quantityOverrides = <String, int>{};

  bool isLoadingSelectedLists = false;
  String? selectedListLoadError;
  int selectedListLoadVersion = 0;

  List<Item> get selectedActivityItems {
    return buildActivityItemSelection(
      importedItems: importedListItems,
      manuallyAddedItems: manuallyAddedItems.values,
      removedItemIds: removedItemIds,
      quantityOverrides: quantityOverrides,
    );
  }

  DateTime selectedDate = DateTime.now();

  TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);

  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

  bool reminderEnabled = true;
  int reminderMinutes = 30;

  bool isSaving = false;
  String? _partialActivityId;
  List<Item> _missingCreationItems = const [];
  String? _partialCreationError;
  bool _showingPartialExitWarning = false;
  bool _allowPartialExit = false;
  bool _didPop = false;

  final List<String> activityTypes = [
    'Trip',
    'School',
    'Work',
    'Daily',
    'Other',
  ];

  final List<int> reminderOptions = [15, 30, 60];

  @override
  void initState() {
    super.initState();

    listRepository = widget.listRepository;
    itemRepository = widget.itemRepository;
    activityRepository = widget.activityRepository;

    final needsRepository =
        listRepository == null ||
        itemRepository == null ||
        activityRepository == null;
    final user = needsRepository ? AuthService().currentUser : null;

    if (user != null) {
      listRepository ??= FirestoreListRepository(userId: user.uid);
      itemRepository ??= FirestoreItemRepository(userId: user.uid);
      activityRepository ??= FirestoreActivityRepository(userId: user.uid);
    }

    listsStream = listRepository?.watchLists();
  }

  @override
  void dispose() {
    nameController.dispose();
    activityItemsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: _partialActivityId == null || _allowPartialExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _didPop = true;
        if (!didPop && _partialActivityId != null) _confirmPartialExit();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            'Create Activity',
            style: AppTextStyles.heading.copyWith(fontSize: 21),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AppColors.ink),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (listRepository == null ||
        itemRepository == null ||
        activityRepository == null ||
        listsStream == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    if (_partialActivityId != null) return _buildPartialCreationRecovery();

    return StreamBuilder<List<ItemList>>(
      stream: listsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load lists.\n'
              '${snapshot.error}',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lists = snapshot.data ?? [];
        final createBlockedBySelection =
            isSaving ||
            isLoadingSelectedLists ||
            selectedListLoadError != null ||
            selectedActivityItems.isEmpty ||
            selectedActivityItems.length > 200;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            const _Label(text: 'Activity Name'),

            const SizedBox(height: 7),

            TextField(
              controller: nameController,
              style: AppTextStyles.bodyBold,
              decoration: _inputDecoration('Example: Davao Beach Trip'),
            ),

            const SizedBox(height: 20),

            const _Label(text: 'Activity Type'),

            const SizedBox(height: 7),

            DropdownButtonFormField<String>(
              initialValue: selectedType,
              decoration: _inputDecoration(null),
              items: activityTypes.map((type) {
                return DropdownMenuItem(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  selectedType = value;
                });
              },
            ),

            const SizedBox(height: 20),

            const _Label(text: 'Import from Lists'),

            const SizedBox(height: 5),

            Text(
              'Optional. Select one or more reusable Lists. Overlapping Items are added once.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),

            const SizedBox(height: 9),

            _ListSelectorCard(
              lists: lists,
              selectedIds: selectedListIds,
              disabled: isSaving || isLoadingSelectedLists || lists.isEmpty,
              onChoose: () {
                _choosePackingLists(lists);
              },
              onRemove: (listId) {
                _removePackingList(listId);
              },
            ),

            const SizedBox(height: 14),

            _buildSelectedItemsPreview(),

            const SizedBox(height: 20),

            const _Label(text: 'Date'),

            const SizedBox(height: 7),

            _PickerBox(
              icon: Icons.calendar_today_outlined,
              text: _formatDate(selectedDate),
              onTap: _pickDate,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label(text: 'Start Time'),

                      const SizedBox(height: 7),

                      _PickerBox(
                        icon: Icons.access_time,
                        text: startTime.format(context),
                        onTap: _pickStartTime,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label(text: 'End Time'),

                      const SizedBox(height: 7),

                      _PickerBox(
                        icon: Icons.access_time,
                        text: endTime.format(context),
                        onTap: _pickEndTime,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_none,
                        color: AppColors.ink,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'Return reminder',
                          style: AppTextStyles.bodyBold,
                        ),
                      ),

                      Switch(
                        value: reminderEnabled,
                        onChanged: (value) {
                          setState(() {
                            reminderEnabled = value;
                          });
                        },
                      ),
                    ],
                  ),

                  if (reminderEnabled) ...[
                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Remind me before the expected end time',
                            style: AppTextStyles.body,
                          ),
                        ),

                        const SizedBox(width: 12),

                        DropdownButton<int>(
                          value: reminderMinutes,
                          items: reminderOptions.map((minutes) {
                            return DropdownMenuItem(
                              value: minutes,
                              child: Text(
                                minutes == 60 ? '1 hour' : '$minutes min',
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              reminderMinutes = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 28),

            ValueListenableBuilder<TextEditingValue>(
              valueListenable: nameController,
              builder: (context, nameValue, _) {
                final activityName = nameValue.text.trim();
                final startAt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  startTime.hour,
                  startTime.minute,
                );
                final endAt = DateTime(
                  selectedDate.year,
                  selectedDate.month,
                  selectedDate.day,
                  endTime.hour,
                  endTime.minute,
                );
                final createDisabled =
                    createBlockedBySelection ||
                    activityName.isEmpty ||
                    activityName.length > 100 ||
                    !endAt.isAfter(startAt);

                return GestureDetector(
                  onTap: createDisabled ? null : _saveActivity,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: createDisabled ? AppColors.muted : AppColors.ink,
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: createDisabled
                          ? null
                          : const [
                              BoxShadow(
                                color: AppColors.green,
                                offset: Offset(3, 3),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isSaving ? 'Creating...' : 'Create Activity',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.background,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedItemsPreview() {
    final items = selectedActivityItems;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Activity Items', style: AppTextStyles.bodyBold),
              ),
              Text(
                '${items.length} ${items.length == 1 ? 'item' : 'items'}',
                style: AppTextStyles.body,
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'This becomes the Activity snapshot. Later List changes will not change this Activity.',
            style: AppTextStyles.body.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          if (isLoadingSelectedLists)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (selectedListLoadError != null) ...[
            Text(selectedListLoadError!, style: AppTextStyles.body),
            const SizedBox(height: 6),
            TextButton(
              onPressed: isSaving ? null : _reloadSelectedLists,
              child: const Text('Retry'),
            ),
          ] else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No Items selected yet. Import a List or add Items from My Items.',
                style: AppTextStyles.body,
              ),
            )
          else ...[
            _buildActivityItemsViewport(items),
          ],
          if (!isLoadingSelectedLists && selectedListLoadError == null) ...[
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isSaving ? null : _addItemsToSelection,
                icon: const Icon(Icons.add),
                label: const Text('Add from My Items'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActivityItemsViewport(List<Item> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          constraints: const BoxConstraints(maxHeight: 286),
          padding: const EdgeInsets.fromLTRB(8, 8, 4, 8),
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Scrollbar(
            controller: activityItemsScrollController,
            thumbVisibility: items.length > 4,
            child: ListView.separated(
              controller: activityItemsScrollController,
              primary: false,
              shrinkWrap: true,
              padding: const EdgeInsets.only(right: 5),
              itemCount: items.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final item = items[index];

                return _PreviewItem(
                  key: ValueKey(item.id),
                  item: item,
                  onDecrease: isSaving || item.quantity <= 1
                      ? null
                      : () {
                          _changeItemQuantity(item.id, -1);
                        },
                  onIncrease: isSaving || item.quantity >= 999
                      ? null
                      : () {
                          _changeItemQuantity(item.id, 1);
                        },
                  onRemove: isSaving
                      ? null
                      : () {
                          _removeSelectedItem(item.id);
                        },
                );
              },
            ),
          ),
        ),
        if (items.length > 4) ...[
          const SizedBox(height: 6),
          Text(
            'Scroll inside the box to review all Activity Items.',
            style: AppTextStyles.body.copyWith(
              color: AppColors.muted,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _choosePackingLists(List<ItemList> lists) async {
    if (isSaving || isLoadingSelectedLists) {
      return;
    }

    final draftSelection = <String>{...selectedListIds};
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(sheetContext).height * .72,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(color: AppColors.ink, width: 2),
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(color: AppColors.ink, offset: Offset(0, -5)),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Import from Lists',
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 19,
                              ),
                            ),
                          ),
                          if (draftSelection.isNotEmpty)
                            TextButton(
                              onPressed: () {
                                setSheetState(draftSelection.clear);
                              },
                              child: const Text('Clear'),
                            ),
                          IconButton(
                            tooltip: 'Close List selector',
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          lists.isEmpty
                              ? 'No saved Lists yet. You can still add individual Items.'
                              : 'Choose any Lists you want to combine for this Activity.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (lists.isNotEmpty)
                      Flexible(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                          itemCount: lists.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final list = lists[index];
                            final selected = draftSelection.contains(list.id);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  setSheetState(() {
                                    if (selected) {
                                      draftSelection.remove(list.id);
                                    } else {
                                      draftSelection.add(list.id);
                                    }
                                  });
                                },
                                borderRadius: BorderRadius.circular(4),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 58,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AppColors.card
                                        : AppColors.background,
                                    border: Border.all(
                                      color: AppColors.ink,
                                      width: selected ? 2 : 1.5,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: AppColors.card,
                                          border: Border.all(
                                            color: AppColors.ink,
                                            width: 1.5,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Icon(
                                          listIconDataForKey(list.icon),
                                          color: AppColors.ink,
                                          size: 21,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          list.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTextStyles.bodyBold,
                                        ),
                                      ),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppColors.green
                                              : AppColors.background,
                                          border: Border.all(
                                            color: AppColors.ink,
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            3,
                                          ),
                                        ),
                                        child: selected
                                            ? const Icon(
                                                Icons.check,
                                                color: AppColors.background,
                                                size: 17,
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.ink,
                            foregroundColor: AppColors.background,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(sheetContext, <String>{
                              ...draftSelection,
                            });
                          },
                          child: Text(
                            draftSelection.isEmpty
                                ? 'Use Individual Items Only'
                                : 'Import ${draftSelection.length} ${draftSelection.length == 1 ? 'List' : 'Lists'}',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      selectedListIds
        ..clear()
        ..addAll(result);
    });
    await _reloadSelectedLists();
  }

  Future<void> _removePackingList(String listId) async {
    if (isSaving || isLoadingSelectedLists) {
      return;
    }

    setState(() {
      selectedListIds.remove(listId);
    });
    await _reloadSelectedLists();
  }

  Future<void> _reloadSelectedLists() async {
    final loadVersion = ++selectedListLoadVersion;
    final ids = selectedListIds.toList(growable: false);

    setState(() {
      selectedListLoadError = null;
      isLoadingSelectedLists = ids.isNotEmpty;
      if (ids.isEmpty) {
        importedListItems = [];
      }
    });

    if (ids.isEmpty) {
      return;
    }

    try {
      final listResults = await Future.wait(ids.map(_loadListItems));
      if (!mounted || loadVersion != selectedListLoadVersion) {
        return;
      }

      final mergedItems = dedupeActivityItems(listResults);

      setState(() {
        importedListItems = mergedItems;
        isLoadingSelectedLists = false;
      });
    } catch (_) {
      if (!mounted || loadVersion != selectedListLoadVersion) {
        return;
      }

      setState(() {
        importedListItems = [];
        selectedListLoadError = 'Failed to load Items from the selected Lists.';
        isLoadingSelectedLists = false;
      });
    }
  }

  Future<void> _addItemsToSelection() async {
    if (isLoadingSelectedLists || isSaving) {
      return;
    }

    final items = await Navigator.push<List<Item>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AddItemsScreen(
            existingItemIds: selectedActivityItems
                .map((item) => item.id)
                .toSet(),
          );
        },
      ),
    );

    if (!mounted || items == null || items.isEmpty) {
      return;
    }

    setState(() {
      for (final item in items) {
        manuallyAddedItems[item.id] = item;
        removedItemIds.remove(item.id);
        quantityOverrides.putIfAbsent(item.id, () => item.quantity);
      }
    });
  }

  void _removeSelectedItem(String itemId) {
    if (isSaving) {
      return;
    }

    setState(() {
      removedItemIds.add(itemId);
      manuallyAddedItems.remove(itemId);
      quantityOverrides.remove(itemId);
    });
  }

  void _changeItemQuantity(String itemId, int delta) {
    if (isSaving) {
      return;
    }

    Item? target;
    for (final item in selectedActivityItems) {
      if (item.id == itemId) {
        target = item;
        break;
      }
    }
    if (target == null) {
      return;
    }

    final nextQuantity = target.quantity + delta;
    if (nextQuantity < 1 || nextQuantity > 999) {
      return;
    }

    setState(() {
      quantityOverrides[itemId] = nextQuantity;
    });
  }

  Future<List<Item>> _loadListItems(String listId) async {
    final itemIds = await listRepository!.getListItemIds(listId);
    final itemResults = await Future.wait(
      itemIds.map((itemId) => itemRepository!.getItem(itemId)),
    );
    return itemResults.whereType<Item>().toList();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );

    if (picked != null) {
      setState(() {
        startTime = picked;
      });
    }
  }

  Future<void> _pickEndTime() async {
    final picked = await showTimePicker(context: context, initialTime: endTime);

    if (picked != null) {
      setState(() {
        endTime = picked;
      });
    }
  }

  Future<void> _saveActivity() async {
    if (isSaving) return;
    if (_partialActivityId != null) {
      await _retryMissingCreationItems();
      return;
    }

    final activityName = nameController.text.trim();

    if (activityName.isEmpty) {
      _showMessage('Please enter an activity name.');
      return;
    }

    if (activityName.length > 100) {
      _showMessage('Activity name must be 100 characters or fewer.');
      return;
    }

    if (isLoadingSelectedLists) {
      _showMessage('Please wait for the selected Lists to finish loading.');
      return;
    }

    if (selectedListLoadError != null) {
      _showMessage('Please retry loading the selected List Items.');
      return;
    }

    if (selectedActivityItems.isEmpty) {
      _showMessage('Please add at least one Item to this Activity.');
      return;
    }

    if (selectedActivityItems.length > 200) {
      _showMessage('An Activity can contain at most 200 Items.');
      return;
    }

    // Keep the legacy source-list field for backward compatibility. The
    // Activity Item manifest below is the authoritative independent snapshot.
    final listId = selectedListIds.isEmpty ? '' : selectedListIds.first;
    final activityItems = List<Item>.from(selectedActivityItems);

    final startAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      startTime.hour,
      startTime.minute,
    );

    final endAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      endTime.hour,
      endTime.minute,
    );

    if (!endAt.isAfter(startAt)) {
      _showMessage('End time must be after start time.');
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final activity = model.Activity(
        id: '',
        listId: listId,
        name: activityName,
        type: selectedType,
        activityDate: DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
        ),
        startAt: startAt,
        endAt: endAt,
        reminderEnabled: reminderEnabled,
        reminderMinutes: reminderMinutes,
        status: 'UPCOMING',
      );

      String? reminderNotice;
      var activityToCreate = activity;

      if (activity.reminderEnabled) {
        final reminderAt = ActivityReminderPolicy.scheduledAt(
          activity,
          now: DateTime.now(),
        );

        if (reminderAt == null) {
          activityToCreate = activity.copyWith(reminderEnabled: false);
          reminderNotice =
              'Activity created without a reminder because the reminder time '
              'has already passed.';
        } else if (ActivityReminderService.isSupportedPlatform) {
          final requestPermission =
              widget.requestReminderPermission ??
              ActivityReminderService.instance.requestPermission;
          final permissionGranted = await requestPermission();

          if (!mounted) {
            return;
          }

          if (!permissionGranted) {
            activityToCreate = activity.copyWith(reminderEnabled: false);
            reminderNotice =
                'Activity created without a reminder because notifications '
                'are turned off.';
          }
        }
      }

      await activityRepository!.addActivityWithItems(
        activity: activityToCreate,
        items: activityItems,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(reminderNotice ?? 'Activity created successfully.'),
        ),
      );

      Navigator.pop(context);
    } on PartialActivityCreationException catch (error) {
      if (!mounted) return;
      setState(() {
        _partialActivityId = error.activityId;
        _missingCreationItems = error.missingItems;
        _partialCreationError =
            'Some Items could not be added. Check your connection and retry.';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Failed to create activity: $error');
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Widget _buildPartialCreationRecovery() {
    final missing = _missingCreationItems;
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Activity created',
                        style: AppTextStyles.heading.copyWith(fontSize: 21),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${missing.length} ${missing.length == 1 ? 'Item still needs' : 'Items still need'} to be added. Retry here to finish the same Activity without creating a duplicate.',
                        style: AppTextStyles.body,
                      ),
                      if (_partialCreationError != null) ...[
                        const SizedBox(height: 10),
                        Text(_partialCreationError!, style: AppTextStyles.body),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text('Missing Items', style: AppTextStyles.bodyBold),
                const SizedBox(height: 8),
                for (final item in missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '• ${item.name} (Qty ${item.quantity})',
                      style: AppTextStyles.body,
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _retryMissingCreationItems,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.ink,
                      foregroundColor: AppColors.background,
                    ),
                    child: Text(
                      isSaving ? 'Adding Items...' : 'Retry Missing Items',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _confirmPartialExit,
                  child: const Text('Back to Activities'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _retryMissingCreationItems() async {
    if (isSaving) return;
    final activityId = _partialActivityId;
    if (activityId == null) return;
    final missing = List<Item>.from(_missingCreationItems);
    setState(() {
      isSaving = true;
      _partialCreationError = null;
    });
    try {
      await activityRepository!.retryActivityCreationItems(
        activityId: activityId,
        items: missing,
      );
      if (!mounted) return;
      _showMessage('All Activity Items added.');
      _leaveCreatedActivity();
    } on PartialActivityCreationException catch (error) {
      if (!mounted) return;
      setState(() {
        _missingCreationItems = error.missingItems;
        _partialCreationError = 'Retry stopped: ${error.cause}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _partialCreationError = 'Could not add Items: $error');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  Future<void> _confirmPartialExit() async {
    if (_showingPartialExitWarning || _didPop || !mounted) return;
    _showingPartialExitWarning = true;
    try {
      final leave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.background,
          title: const Text('Leave unfinished Activity?'),
          content: Text(
            'Up to ${_missingCreationItems.length} Items may still be missing. '
            'This retry list will be lost if you leave now.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Keep retrying'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Leave Activity'),
            ),
          ],
        ),
      );
      if (leave == true && mounted) _leaveCreatedActivity();
    } finally {
      _showingPartialExitWarning = false;
    }
  }

  void _leaveCreatedActivity() {
    if (_didPop || !mounted) return;
    setState(() => _allowPartialExit = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_didPop) {
        _didPop = true;
        Navigator.of(context).pop();
      }
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  InputDecoration _inputDecoration(String? hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
      filled: true,
      fillColor: AppColors.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _PreviewItem extends StatelessWidget {
  final Item item;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onRemove;

  const _PreviewItem({
    super.key,
    required this.item,
    this.onDecrease,
    this.onIncrease,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 1.2),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.ink, width: 1.2),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Icon(
              itemIconDataForKey(item.icon),
              color: AppColors.ink,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold,
                ),
                const SizedBox(height: 2),
                Text(
                  item.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _QuantityButton(
            icon: Icons.remove,
            tooltip: 'Decrease quantity',
            onPressed: onDecrease,
          ),
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            alignment: Alignment.center,
            child: Text('${item.quantity}', style: AppTextStyles.bodyBold),
          ),
          _QuantityButton(
            icon: Icons.add,
            tooltip: 'Increase quantity',
            onPressed: onIncrease,
          ),
          if (item.hasQr)
            Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.green,
                border: Border.all(color: AppColors.ink, width: 1.2),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'QR',
                style: AppTextStyles.bodyBold.copyWith(
                  fontSize: 9,
                  color: AppColors.background,
                ),
              ),
            ),
          if (onRemove != null)
            Tooltip(
              message: 'Remove from Activity',
              child: IconButton(
                onPressed: onRemove,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close, color: AppColors.ink, size: 20),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  const _QuantityButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
      icon: Icon(
        icon,
        size: 18,
        color: onPressed == null ? AppColors.muted : AppColors.ink,
      ),
    );
  }
}

class _ListSelectorCard extends StatelessWidget {
  final List<ItemList> lists;
  final Set<String> selectedIds;
  final bool disabled;
  final VoidCallback onChoose;
  final ValueChanged<String> onRemove;

  const _ListSelectorCard({
    required this.lists,
    required this.selectedIds,
    required this.disabled,
    required this.onChoose,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLists = lists
        .where((list) => selectedIds.contains(list.id))
        .toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedLists.isEmpty
                      ? 'No Lists selected'
                      : '${selectedLists.length} ${selectedLists.length == 1 ? 'List' : 'Lists'} selected',
                  style: AppTextStyles.bodyBold,
                ),
              ),
              TextButton.icon(
                onPressed: disabled ? null : onChoose,
                icon: const Icon(Icons.playlist_add, size: 19),
                label: Text(selectedLists.isEmpty ? 'Choose' : 'Change'),
              ),
            ],
          ),
          if (selectedLists.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: selectedLists.map((list) {
                return Container(
                  constraints: const BoxConstraints(maxWidth: 190),
                  padding: const EdgeInsets.fromLTRB(8, 5, 4, 5),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        listIconDataForKey(list.icon),
                        size: 16,
                        color: AppColors.ink,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: disabled ? null : () => onRemove(list.id),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.close, size: 15),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ] else
            Text(
              lists.isEmpty
                  ? 'No saved Lists yet. You can still add Items below.'
                  : 'You can skip Lists and add individual Items below.',
              style: AppTextStyles.body.copyWith(color: AppColors.muted),
            ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.bodyBold.copyWith(fontSize: 13));
  }
}

class _PickerBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;

  const _PickerBox({
    required this.icon,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.ink, size: 20),

            const SizedBox(width: 9),

            Expanded(child: Text(text, style: AppTextStyles.bodyBold)),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  return '${months[date.month - 1]} '
      '${date.day}, ${date.year}';
}
