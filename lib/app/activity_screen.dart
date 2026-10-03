import 'package:flutter/material.dart';

import '../domain/packing.dart';
import '../repositories/packing_repository.dart';
import '../services/reminder_service.dart';
import 'ui_helpers.dart';
import 'qr_scanner_screen.dart';
import 'widgets/retro_widgets.dart';

class ActivityScreen extends StatefulWidget {
  final PackingRepository repository;
  final String activityId;
  const ActivityScreen({
    super.key,
    required this.repository,
    required this.activityId,
  });
  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  late Stream<PackingActivity?> _stream = widget.repository.watchActivity(
    widget.activityId,
  );
  bool _busy = false;
  Future<void> _run(Future<void> Function() operation) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await operation();
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan(PackingActivity activity) async {
    final id = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => QrScannerScreen(userId: widget.repository.userId),
      ),
    );
    if (!mounted || id == null) return;
    await _run(() async {
      if (activity.draft.containsKey(id)) {
        showMessage(context, 'This item is already checked.');
        return;
      }
      Belonging? addition;
      if (!activity.items.containsKey(id)) {
        addition = await widget.repository.getItem(id);
        if (!mounted) return;
        if (addition == null || addition.archived) {
          throw StateError(
            'This QR points to an unavailable or archived item.',
          );
        }
        final accepted = await confirm(
          context,
          'Add ${addition.name}?',
          'This item is not in the activity. Add it here and mark it found by QR? Your reusable list stays unchanged.',
          action: 'Add to activity',
        );
        if (!accepted) return;
      }
      await widget.repository.markItem(
        activity.id,
        activity.status,
        id,
        CheckMethod.qr,
        addition: addition,
      );
    });
  }

  Future<void> _finish(PackingActivity activity) async {
    final missing = activity.items.length - activity.draft.length;
    final before = activity.status == ActivityStatus.planned;
    if (!await confirm(
      context,
      before ? 'Start activity?' : 'Finish activity?',
      '${activity.draft.length} of ${activity.items.length} item types found. '
      '${missing > 0 ? '$missing will be recorded as missing. ' : ''}'
      'Confirm you have the full displayed quantity of every checked item. Completed results cannot be edited.',
      action: before ? 'Start activity' : 'Finish activity',
    )) {
      return;
    }
    if (!mounted) return;
    await _run(() async {
      await widget.repository.completeCheck(activity);
      if (before) await ReminderService.instance.requestPermission();
      if (mounted) {
        showMessage(
          context,
          before
              ? 'Activity started. Your before check is saved.'
              : 'Activity completed. Return results are saved.',
        );
      }
    });
  }

  Future<void> _reschedule(PackingActivity activity) async {
    final end = await chooseDate(context, activity.endsAt);
    if (!mounted || end == null) return;
    await _run(
      () => widget.repository.reschedule(
        activity.id,
        end,
        activity.reminderMinutes,
      ),
    );
  }

  Widget _result(CheckRecord? check, String id) {
    if (check == null || !check.itemIds.contains(id)) {
      return const Text('Not checked');
    }
    final method = check.found[id];
    return Text(
      method == null ? 'MISSING' : 'FOUND · ${method.name.toUpperCase()}',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: method == null ? Colors.red.shade800 : Colors.green.shade800,
      ),
    );
  }

  Widget _history(PackingActivity activity) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (activity.before != null)
        Text(
          'Before: ${activity.before!.found.length}/${activity.before!.itemIds.length} found · ${dateLabel(activity.before!.completedAt)}',
        ),
      if (activity.returned != null)
        Text(
          'Return: ${activity.returned!.found.length}/${activity.returned!.itemIds.length} found · ${dateLabel(activity.returned!.completedAt)}',
        ),
      const SizedBox(height: 16),
      ...activity.items.values.map(
        (item) => RetroPanel(
          padding: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.name} · Qty ${item.quantity}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (item.addedDuringActivity)
                  const Text('Added during activity'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 24,
                  runSpacing: 8,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('BEFORE'),
                        _result(activity.before, item.id),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RETURN'),
                        _result(activity.returned, item.id),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      const Text(
        'MANUAL = confirmed by tapping. QR = confirmed by scanning. Not checked = the item was not part of that check, or that check was never completed.',
      ),
    ],
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: StreamBuilder<PackingActivity?>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(errorText(snapshot.error!)),
                    TextButton(
                      onPressed: () => setState(
                        () => _stream = widget.repository.watchActivity(
                          widget.activityId,
                        ),
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final activity = snapshot.data;
          if (activity == null) {
            return const Center(child: Text('Activity not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                activity.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('${activity.type} · ${activity.status.name.toUpperCase()}'),
              Text(
                '${dateLabel(activity.startsAt)} → ${dateLabel(activity.endsAt)}',
              ),
              Text('Reminder: ${activity.reminderMinutes} minutes before end'),
              if (activity.editable) ...[
                const SizedBox(height: 12),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: _busy ? null : () => _reschedule(activity),
                      child: const Text('Change end time'),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () async {
                              if (await confirm(
                                    context,
                                    'Cancel activity?',
                                    'Existing check results will remain in history.',
                                    action: 'Cancel activity',
                                  ) &&
                                  mounted) {
                                await _run(
                                  () => widget.repository.cancelActivity(
                                    activity.id,
                                  ),
                                );
                              }
                            },
                      child: const Text('Cancel activity'),
                    ),
                  ],
                ),
                const Divider(),
                Text(
                  activity.status == ActivityStatus.planned
                      ? 'Before activity check'
                      : 'Return check',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Check an item only when its full quantity is present. Progress saves to your account; internet is required to confirm changes.',
                ),
                const SizedBox(height: 12),
                RetroProgress(
                  found: activity.draft.length,
                  total: activity.items.length,
                  label: activity.status == ActivityStatus.planned
                      ? 'Before check'
                      : 'Return check',
                ),
                const SizedBox(height: 8),
                Text(
                  '${activity.draft.length} / ${activity.items.length} item types found',
                ),
                if (_busy) const LinearProgressIndicator(),
                ...activity.items.values.map(
                  (item) => RetroPanel(
                    padding: EdgeInsets.zero,
                    child: CheckboxListTile(
                      title: Text(item.name),
                      subtitle: Text(
                        'Qty ${item.quantity} · ${item.category}'
                        '${activity.draft[item.id] == null ? '' : ' · ${activity.draft[item.id]!.name.toUpperCase()}'}',
                      ),
                      value: activity.draft.containsKey(item.id),
                      onChanged: _busy
                          ? null
                          : (value) => _run(
                              () => widget.repository.markItem(
                                activity.id,
                                activity.status,
                                item.id,
                                value == true ? CheckMethod.manual : null,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(activity),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scan QR code'),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: _busy ? null : () => _finish(activity),
                  child: Text(
                    activity.status == ActivityStatus.planned
                        ? 'Start activity'
                        : 'Finish activity',
                  ),
                ),
                if (activity.before != null) ...[
                  const SizedBox(height: 24),
                  ExpansionTile(
                    title: const Text('View saved before results'),
                    children: [_history(activity)],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 24),
                _history(activity),
              ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    ),
  );
}
