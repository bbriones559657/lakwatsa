import 'package:flutter/material.dart';

import '../../domain/packing.dart';
import '../../theme/app_theme.dart';
import '../widgets/retro_widgets.dart';

class PackingItemsView extends StatelessWidget {
  final List<Belonging> items;
  final String query, category;
  final bool archived;
  final ValueChanged<String> onCategory;
  final ValueChanged<Belonging> onEdit, onQr, onArchive;
  const PackingItemsView({
    super.key,
    required this.items,
    required this.query,
    required this.category,
    required this.archived,
    required this.onCategory,
    required this.onEdit,
    required this.onQr,
    required this.onArchive,
  });
  static const categories = [
    'Electronics',
    'Documents',
    'Clothing',
    'Personal Care',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    final visible = items
        .where(
          (i) =>
              i.archived == archived &&
              i.name.toLowerCase().contains(query) &&
              (category == 'All' || i.category == category),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final value in ['All', ...categories])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(value),
                    selected: category == value,
                    onSelected: (_) => onCategory(value),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (archived)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text('Archived items', style: AppTextStyles.heading),
          ),
        if (visible.isEmpty)
          const RetroEmpty(
            title: 'No items found',
            message: 'Add an item with the + button or change your filters.',
            icon: Icons.inventory_2_outlined,
          ),
        for (final group in categories)
          if (visible.any((i) => i.category == group)) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    group,
                    style: AppTextStyles.pixelDark.copyWith(
                      fontSize: 8,
                      height: 1.8,
                    ),
                  ),
                ),
                Text(
                  '${visible.where((i) => i.category == group).length} ${visible.where((i) => i.category == group).length == 1 ? 'item' : 'items'}',
                  style: AppTextStyles.body,
                ),
              ],
            ),
            const Divider(height: 20),
            for (final item in visible.where((i) => i.category == group))
              RetroPanel(
                padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
                onTap: () => onEdit(item),
                child: Row(
                  children: [
                    Container(width: 4, height: 52, color: AppColors.orange),
                    const SizedBox(width: 10),
                    RetroIcon(categoryIcon(item.category)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: AppTextStyles.bodyBold,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${item.category} / Qty ${item.quantity}',
                            style: AppTextStyles.body,
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'View QR code for ${item.name}',
                      child: InkWell(
                        onTap: () => onQr(item),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 4,
                          ),
                          child: RetroBadge('QR'),
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Options for ${item.name}',
                      padding: EdgeInsets.zero,
                      onSelected: (value) =>
                          value == 'edit' ? onEdit(item) : onArchive(item),
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Edit item'),
                        ),
                        PopupMenuItem(
                          value: 'archive',
                          child: Text(
                            item.archived ? 'Restore item' : 'Archive item',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
      ],
    );
  }
}
