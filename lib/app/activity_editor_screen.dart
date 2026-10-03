import 'package:flutter/material.dart';

import '../domain/packing.dart';
import '../repositories/packing_repository.dart';
import 'ui_helpers.dart';

class ActivityEditor extends StatefulWidget {
  final PackingRepository repository;
  final List<PackingList> lists;
  final List<Belonging> items;
  const ActivityEditor({
    super.key,
    required this.repository,
    required this.lists,
    required this.items,
  });
  @override
  State<ActivityEditor> createState() => _ActivityEditorState();
}

class _ActivityEditorState extends State<ActivityEditor> {
  final _name = TextEditingController();
  late final _id = widget.repository.newId();
  String? _listId;
  String _type = 'Trip';
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(hours: 2));
  int _reminder = 30;
  bool _busy = false;
  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final list = widget.lists.where((l) => l.id == _listId).firstOrNull;
      if (list == null) throw ArgumentError('Choose a reusable list.');
      final available = {
        for (final item in widget.items.where((i) => !i.archived))
          item.id: item,
      };
      if (list.quantities.keys.any((id) => !available.containsKey(id))) {
        throw StateError(
          'This list has archived or unavailable items. Edit the list or restore those items first.',
        );
      }
      final snapshot = list.quantities.map((id, quantity) {
        final item = available[id]!;
        return MapEntry(
          id,
          PackedItem(
            id: id,
            name: item.name,
            category: item.category,
            quantity: quantity,
          ),
        );
      });
      await widget.repository.createActivity(
        PackingActivity(
          id: _id,
          name: _name.text,
          type: _type,
          status: ActivityStatus.planned,
          startsAt: _start,
          endsAt: _end,
          reminderMinutes: _reminder,
          items: snapshot,
        ),
      );
      if (mounted) Navigator.pop(context, _id);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Create activity')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _name,
            maxLength: 100,
            enabled: !_busy,
            decoration: const InputDecoration(
              labelText: 'Activity name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _listId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Reusable list',
              border: OutlineInputBorder(),
            ),
            items: widget.lists
                .map(
                  (l) => DropdownMenuItem(
                    value: l.id,
                    child: Text(
                      '${l.name} (${l.quantities.length})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : (v) => setState(() => _listId = v),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(
              labelText: 'Activity type',
              border: OutlineInputBorder(),
            ),
            items: [
              'Trip',
              'School',
              'Work',
              'Daily',
              'Other',
            ].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: _busy ? null : (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Start'),
            subtitle: Text(dateLabel(_start)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _busy
                ? null
                : () async {
                    final value = await chooseDate(context, _start);
                    if (mounted && value != null) {
                      setState(() => _start = value);
                    }
                  },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Expected end'),
            subtitle: Text(dateLabel(_end)),
            trailing: const Icon(Icons.calendar_today),
            onTap: _busy
                ? null
                : () async {
                    final value = await chooseDate(context, _end);
                    if (mounted && value != null) setState(() => _end = value);
                  },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int>(
            initialValue: _reminder,
            decoration: const InputDecoration(
              labelText: 'Remind me before ending',
              border: OutlineInputBorder(),
            ),
            items: [0, 5, 15, 30, 60]
                .map(
                  (v) => DropdownMenuItem(
                    value: v,
                    child: Text(
                      v == 0 ? 'At the end time' : '$v minutes before',
                    ),
                  ),
                )
                .toList(),
            onChanged: _busy ? null : (v) => setState(() => _reminder = v!),
          ),
          const SizedBox(height: 20),
          const Text(
            'This creates an independent copy of your list. Reminders start after the before check, when the activity becomes active. Android may deliver reminders later while idle.',
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy || widget.lists.isEmpty ? null : _save,
            child: Text(_busy ? 'Creating…' : 'Create activity'),
          ),
          if (widget.lists.isEmpty)
            const Text('Create a reusable list with at least one item first.'),
        ],
      ),
    ),
  );
}
