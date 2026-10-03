import 'package:flutter/material.dart';

import '../../domain/packing.dart';
import '../../theme/app_theme.dart';
import '../widgets/retro_widgets.dart';

class PackingListsView extends StatelessWidget {
  final List<PackingList> lists;
  final String query;
  final bool editing;
  final ValueChanged<PackingList> onOpen, onDelete;
  const PackingListsView({
    super.key,
    required this.lists,
    required this.query,
    required this.editing,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final visible = lists
        .where((l) => l.name.toLowerCase().contains(query))
        .toList();
    if (visible.isEmpty) {
      return const RetroEmpty(
        title: 'No lists found',
        message: 'Create a reusable list for a trip, school, work, or daily essentials.',
        icon: Icons.list_alt_outlined,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 320 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 14) / columns;
        return Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [
            for (final list in visible)
              SizedBox(
                width: width,
                child: RetroPanel(
                  onTap: editing ? null : () => onOpen(list),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const RetroIcon(Icons.list_alt_outlined),
                          const Spacer(),
                          if (editing)
                            IconButton(
                              tooltip: 'Delete ${list.name}',
                              onPressed: () => onDelete(list),
                              icon: const Icon(Icons.close),
                            ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Text(
                        list.name,
                        style: AppTextStyles.bodyBold,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${list.quantities.length} item types',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
