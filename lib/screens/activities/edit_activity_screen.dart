import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/activity.dart' as model;
import '../../repositories/firestore_activity_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class EditActivityScreen extends StatefulWidget {
  final model.Activity activity;

  const EditActivityScreen({super.key, required this.activity});

  @override
  State<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends State<EditActivityScreen> {
  late final TextEditingController nameController;
  FirestoreActivityRepository? activityRepository;

  late String selectedType;
  late DateTime selectedDate;
  late TimeOfDay startTime;
  late TimeOfDay endTime;
  late bool reminderEnabled;
  late int reminderMinutes;
  late final List<String> activityTypes;
  late final List<int> reminderOptions;

  bool isSaving = false;

  bool get isActive => widget.activity.isActive;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: widget.activity.name);
    selectedType = widget.activity.type;
    selectedDate = widget.activity.activityDate;
    startTime = TimeOfDay.fromDateTime(widget.activity.startAt);
    endTime = TimeOfDay.fromDateTime(widget.activity.endAt);
    reminderEnabled = widget.activity.reminderEnabled;
    reminderMinutes = widget.activity.reminderMinutes;

    activityTypes = {
      'Trip',
      'School',
      'Work',
      'Daily',
      'Other',
      widget.activity.type,
    }.toList();
    reminderOptions = {15, 30, 60, widget.activity.reminderMinutes}.toList()
      ..sort();

    final user = AuthService().currentUser;
    if (user != null) {
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
          'Edit Activity',
          style: AppTextStyles.heading.copyWith(fontSize: 21),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.ink),
        ),
      ),
      body: activityRepository == null
          ? Center(
              child: Text('Please sign in again.', style: AppTextStyles.body),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              children: [
                if (isActive) ...[
                  const _ActiveEditNotice(),
                  const SizedBox(height: 20),
                ],
                const _EditLabel(text: 'Activity Name'),
                const SizedBox(height: 7),
                TextField(
                  controller: nameController,
                  enabled: !isSaving,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  style: AppTextStyles.bodyBold,
                  decoration: _inputDecoration('Activity name'),
                ),
                const SizedBox(height: 20),
                const _EditLabel(text: 'Activity Type'),
                const SizedBox(height: 7),
                DropdownButtonFormField<String>(
                  initialValue: selectedType,
                  decoration: _inputDecoration(null),
                  items: activityTypes.map((type) {
                    return DropdownMenuItem(value: type, child: Text(type));
                  }).toList(),
                  onChanged: isSaving
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => selectedType = value);
                        },
                ),
                const SizedBox(height: 20),
                const _EditLabel(text: 'Date'),
                const SizedBox(height: 7),
                _EditPickerBox(
                  icon: isActive
                      ? Icons.lock_outline
                      : Icons.calendar_today_outlined,
                  text: _formatEditDate(selectedDate),
                  enabled: !isActive && !isSaving,
                  onTap: _pickDate,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _EditLabel(text: 'Start Time'),
                          const SizedBox(height: 7),
                          _EditPickerBox(
                            icon: isActive
                                ? Icons.lock_outline
                                : Icons.access_time,
                            text: startTime.format(context),
                            enabled: !isActive && !isSaving,
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
                          const _EditLabel(text: 'End Time'),
                          const SizedBox(height: 7),
                          _EditPickerBox(
                            icon: Icons.access_time,
                            text: endTime.format(context),
                            enabled: !isSaving,
                            onTap: _pickEndTime,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _ReminderCard(
                  enabled: reminderEnabled,
                  minutes: reminderMinutes,
                  options: reminderOptions,
                  locked: isSaving,
                  onEnabledChanged: (value) {
                    setState(() => reminderEnabled = value);
                  },
                  onMinutesChanged: (value) {
                    setState(() => reminderMinutes = value);
                  },
                ),
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: isSaving ? null : _saveActivity,
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSaving ? AppColors.muted : AppColors.ink,
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSaving
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
                      isSaving ? 'Saving...' : 'Save Changes',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _pickDate() async {
    if (isActive || isSaving) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    final firstDate = current.isBefore(today) ? current : today;
    final normalLastDate = DateTime(now.year + 5, 12, 31);
    final lastDate = current.isAfter(normalLastDate)
        ? current
        : normalLastDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      setState(() => selectedDate = picked);
    }
  }

  Future<void> _pickStartTime() async {
    if (isActive || isSaving) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: startTime,
    );
    if (picked != null && mounted) {
      setState(() => startTime = picked);
    }
  }

  Future<void> _pickEndTime() async {
    if (isSaving) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: endTime,
    );
    if (picked != null && mounted) {
      setState(() => endTime = picked);
    }
  }

  Future<void> _saveActivity() async {
    final name = nameController.text.trim();
    if (name.isEmpty) {
      _showMessage('Please enter an activity name.');
      return;
    }
    if (name.length > 100) {
      _showMessage('Activity name must be 100 characters or fewer.');
      return;
    }

    final activityDate = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
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

    final updatedActivity = widget.activity.copyWith(
      name: name,
      type: selectedType,
      activityDate: activityDate,
      startAt: startAt,
      endAt: endAt,
      reminderEnabled: reminderEnabled,
      reminderMinutes: reminderMinutes,
    );

    setState(() => isSaving = true);
    try {
      await activityRepository!.updateActivity(updatedActivity);
      if (!mounted) return;
      Navigator.pop(
        context,
        updatedActivity.copyWith(updatedAt: DateTime.now()),
      );
    } catch (error) {
      if (!mounted) return;
      _showMessage('Failed to update Activity: $error');
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
      disabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.muted, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _ActiveEditNotice extends StatelessWidget {
  const _ActiveEditNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_clock_outlined,
            color: AppColors.ink,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This Activity has already started. Its date and start time '
              'are locked, but you can still update its details, end time, '
              'and return reminder.',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  final bool enabled;
  final int minutes;
  final List<int> options;
  final bool locked;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onMinutesChanged;

  const _ReminderCard({
    required this.enabled,
    required this.minutes,
    required this.options,
    required this.locked,
    required this.onEnabledChanged,
    required this.onMinutesChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              const Icon(Icons.notifications_none, color: AppColors.ink),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Return reminder', style: AppTextStyles.bodyBold),
              ),
              Switch(
                value: enabled,
                onChanged: locked ? null : onEnabledChanged,
              ),
            ],
          ),
          if (enabled) ...[
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
                  value: minutes,
                  items: options.map((value) {
                    return DropdownMenuItem(
                      value: value,
                      child: Text(value == 60 ? '1 hour' : '$value min'),
                    );
                  }).toList(),
                  onChanged: locked
                      ? null
                      : (value) {
                          if (value != null) onMinutesChanged(value);
                        },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EditLabel extends StatelessWidget {
  final String text;
  const _EditLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
    );
  }
}

class _EditPickerBox extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _EditPickerBox({
    required this.icon,
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(
            color: enabled ? AppColors.ink : AppColors.muted,
            width: enabled ? 2 : 1.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: enabled ? AppColors.ink : AppColors.muted,
              size: 20,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                text,
                style: AppTextStyles.bodyBold.copyWith(
                  color: enabled ? AppColors.ink : AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatEditDate(DateTime date) {
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
  return '${months[date.month - 1]} ${date.day}, ${date.year}';
}
