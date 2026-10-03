import 'package:flutter/material.dart';

import '../domain/packing.dart';
import '../repositories/packing_repository.dart';
import 'ui_helpers.dart';
import 'widgets/retro_widgets.dart';

class ListEditor extends StatefulWidget {
  final PackingRepository repository;
  final List<Belonging> items;
  final PackingList? list;
  const ListEditor({
    super.key,
    required this.repository,
    required this.items,
    this.list,
  });
  @override
  State<ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends State<ListEditor> {
  late final _name = TextEditingController(text: widget.list?.name);
  late final Map<String, int> _selected = Map.of(widget.list?.quantities ?? {});
  late final _id = widget.list?.id ?? widget.repository.newId();
  String _search = '';
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
      await widget.repository.saveList(
        PackingList(id: _id, name: _name.text, quantities: _selected),
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showMessage(context, errorText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items
        .where(
          (i) =>
              (!i.archived || _selected.containsKey(i.id)) &&
              i.name.toLowerCase().contains(_search),
        )
        .toList();
    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.list == null ? 'Create list' : 'Edit list'),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _name,
                    maxLength: 100,
                    enabled: !_busy,
                    decoration: const InputDecoration(
                      labelText: 'List name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  TextField(
                    onChanged: (v) =>
                        setState(() => _search = v.trim().toLowerCase()),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Find items',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_selected.length} selected · Removing an item here keeps it in My Items.',
                  ),
                ],
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(
                      child: Text(
                        'No items found. Add items in My Items first.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = _selected.containsKey(item.id);
                        return RetroPanel(
                          padding: EdgeInsets.zero,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: selected,
                                title: Text(item.name),
                                subtitle: Text(
                                  item.archived
                                      ? 'Archived — remove or restore in My Items'
                                      : item.category,
                                ),
                                onChanged: _busy
                                    ? null
                                    : (value) => setState(() {
                                        if (value == true) {
                                          _selected[item.id] = item.quantity;
                                        } else {
                                          _selected.remove(item.id);
                                        }
                                      }),
                              ),
                              if (selected)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    const Text('Pack quantity'),
                                    IconButton(
                                      tooltip: 'Decrease quantity',
                                      onPressed:
                                          _busy || _selected[item.id]! <= 1
                                          ? null
                                          : () => setState(
                                              () => _selected[item.id] =
                                                  _selected[item.id]! - 1,
                                            ),
                                      icon: const Icon(Icons.remove),
                                    ),
                                    Text('${_selected[item.id]}'),
                                    IconButton(
                                      tooltip: 'Increase quantity',
                                      onPressed:
                                          _busy || _selected[item.id]! >= 999
                                          ? null
                                          : () => setState(
                                              () => _selected[item.id] =
                                                  _selected[item.id]! + 1,
                                            ),
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: Text(_busy ? 'Saving…' : 'Save list'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
