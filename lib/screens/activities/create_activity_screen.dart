import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../models/item.dart';
import '../../models/item_list.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class CreateActivityScreen extends StatefulWidget {
  const CreateActivityScreen({super.key});

  @override
  State<CreateActivityScreen> createState() => _CreateActivityScreenState();
}

class _CreateActivityScreenState extends State<CreateActivityScreen> {
  final TextEditingController nameController = TextEditingController();

  FirestoreListRepository? listRepository;
  FirestoreItemRepository? itemRepository;
  FirestoreActivityRepository? activityRepository;

  String selectedType = 'Trip';
  String? selectedListId;

  Future<List<Item>>? selectedListItemsFuture;

  DateTime selectedDate = DateTime.now();

  TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);

  TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);

  bool reminderEnabled = true;
  int reminderMinutes = 30;

  bool isSaving = false;

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

    final user = AuthService().currentUser;

    if (user != null) {
      listRepository = FirestoreListRepository(userId: user.uid);

      itemRepository = FirestoreItemRepository(userId: user.uid);

      activityRepository = FirestoreActivityRepository(userId: user.uid);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
  }

  Widget _buildBody() {
    if (listRepository == null ||
        itemRepository == null ||
        activityRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<ItemList>>(
      stream: listRepository!.watchLists(),
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

            const _Label(text: 'Packing List'),

            const SizedBox(height: 7),

            if (lists.isEmpty)
              const _NoListsMessage()
            else
              DropdownButtonFormField<String>(
                initialValue: selectedListId,
                decoration: _inputDecoration('Choose a list'),
                items: lists.map((list) {
                  return DropdownMenuItem(
                    value: list.id,
                    child: Text(list.name),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedListId = value;

                    if (value != null) {
                      selectedListItemsFuture = _loadListItems(value);
                    } else {
                      selectedListItemsFuture = null;
                    }
                  });
                },
              ),

            if (selectedListId != null) ...[
              const SizedBox(height: 14),

              _buildSelectedListPreview(),
            ],

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

            GestureDetector(
              onTap: isSaving || lists.isEmpty ? null : _saveActivity,
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isSaving || lists.isEmpty
                      ? AppColors.muted
                      : AppColors.ink,
                  border: Border.all(color: AppColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: isSaving || lists.isEmpty
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
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectedListPreview() {
    final future = selectedListItemsFuture;

    if (future == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Item>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Failed to load list items.',
              style: AppTextStyles.body,
            ),
          );
        }

        final items = snapshot.data ?? [];

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
                  Text('Items in this list', style: AppTextStyles.bodyBold),

                  const Spacer(),

                  Text(
                    '${items.length} '
                    '${items.length == 1 ? 'item' : 'items'}',
                    style: AppTextStyles.body,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No items in this list.',
                    style: AppTextStyles.body,
                  ),
                )
              else
                ...items.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PreviewItem(item: item),
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  Future<List<Item>> _loadListItems(String listId) async {
    final itemIds = await listRepository!.getListItemIds(listId);

    final itemResults = await Future.wait(
      itemIds.map((itemId) {
        return itemRepository!.getItem(itemId);
      }),
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
    final activityName = nameController.text.trim();

    if (activityName.isEmpty) {
      _showMessage('Please enter an activity name.');
      return;
    }

    if (selectedListId == null) {
      _showMessage('Please choose a packing list.');
      return;
    }

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
      final items = await _loadListItems(selectedListId!);

      final activity = model.Activity(
        id: '',
        listId: selectedListId!,
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

      await activityRepository!.addActivityWithItems(
        activity: activity,
        items: items,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Activity created successfully.')),
      );

      Navigator.pop(context);
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

  const _PreviewItem({required this.item});

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
              _getItemIcon(item.icon),
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
                  '${item.category} • Qty ${item.quantity}',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),

          if (item.hasQr)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
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

class _NoListsMessage extends StatelessWidget {
  const _NoListsMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'You need to create a List before creating an Activity.',
        style: AppTextStyles.body,
      ),
    );
  }
}

IconData _getItemIcon(String icon) {
  switch (icon) {
    case 'electronics':
      return Icons.devices_outlined;

    case 'documents':
      return Icons.description_outlined;

    case 'clothing':
      return Icons.checkroom_outlined;

    case 'toiletries':
      return Icons.cleaning_services_outlined;

    case 'laptop':
      return Icons.laptop_mac;

    case 'charger':
      return Icons.battery_charging_full;

    case 'battery':
      return Icons.battery_5_bar;

    case 'passport':
      return Icons.badge_outlined;

    case 'id':
      return Icons.credit_card;

    case 'jacket':
    case 'shirt':
      return Icons.checkroom;

    case 'toothbrush':
      return Icons.cleaning_services_outlined;

    default:
      return Icons.inventory_2_outlined;
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
