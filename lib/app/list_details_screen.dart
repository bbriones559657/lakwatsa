import 'package:flutter/material.dart';

import '../domain/packing.dart';
import '../repositories/packing_repository.dart';
import '../theme/app_theme.dart';
import 'list_editor_screen.dart';
import 'ui_helpers.dart';
import 'widgets/retro_widgets.dart';

class PackingListDetailsScreen extends StatefulWidget {
  final PackingRepository repository;
  final String listId;
  const PackingListDetailsScreen({
    super.key,
    required this.repository,
    required this.listId,
  });
  @override
  State<PackingListDetailsScreen> createState() =>
      _PackingListDetailsScreenState();
}

class _PackingListDetailsScreenState extends State<PackingListDetailsScreen> {
  late final _lists = widget.repository.watchLists();
  late final _items = widget.repository.watchItems();

  @override
  Widget build(BuildContext context) => StreamBuilder<List<PackingList>>(
    stream: _lists,
    builder: (context, listSnapshot) => StreamBuilder<List<Belonging>>(
      stream: _items,
      builder: (context, itemSnapshot) {
        final list = listSnapshot.data
            ?.where((l) => l.id == widget.listId)
            .firstOrNull;
        final items = itemSnapshot.data ?? [];
        final error = listSnapshot.error ?? itemSnapshot.error;
        final loading = !listSnapshot.hasData || !itemSnapshot.hasData;
        void edit() => Navigator.push<void>(
          context,
          MaterialPageRoute(
            builder: (_) => ListEditor(
              repository: widget.repository,
              items: items,
              list: list,
            ),
          ),
        );
        return Scaffold(
          appBar: AppBar(
            title: Text(list?.name ?? 'List details'),
            actions: [
              if (list != null && !loading && error == null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: OutlinedButton(
                    onPressed: edit,
                    child: const Text('Edit'),
                  ),
                ),
            ],
          ),
          body: error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(errorText(error)),
                  ),
                )
              : loading
              ? const Center(child: CircularProgressIndicator())
              : list == null
              ? const Center(child: Text('This list no longer exists.'))
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Row(
                      children: [
                        const RetroIcon(Icons.list_alt_outlined),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(list.name, style: AppTextStyles.heading),
                              Text(
                                '${list.quantities.length} item types',
                                style: AppTextStyles.body,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Items', style: AppTextStyles.bodyBold),
                    const SizedBox(height: 12),
                    for (final entry in list.quantities.entries)
                      _membership(
                        items.where((i) => i.id == entry.key).firstOrNull,
                        entry.value,
                      ),
                    if (list.quantities.isEmpty)
                      const RetroEmpty(
                        title: 'Your list is empty',
                        message: 'Add items from your saved inventory.',
                        icon: Icons.list_alt_outlined,
                      ),
                    FilledButton.icon(
                      onPressed: edit,
                      icon: const Icon(Icons.add),
                      label: const Text('Add or edit items'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Changes to this list do not change existing activity snapshots.',
                    ),
                  ],
                ),
        );
      },
    ),
  );

  Widget _membership(Belonging? item, int quantity) => RetroPanel(
    child: Row(
      children: [
        RetroIcon(categoryIcon(item?.category ?? 'Other')),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item?.name ?? 'Unavailable item',
                style: AppTextStyles.bodyBold,
              ),
              Text(
                '${item?.category ?? 'Unknown'} / Qty $quantity',
                style: AppTextStyles.body,
              ),
              if (item?.archived ?? false)
                const Text('Archived - restore before creating an activity'),
            ],
          ),
        ),
      ],
    ),
  );
}
