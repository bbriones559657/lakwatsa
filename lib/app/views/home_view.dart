import 'package:flutter/material.dart';

import '../../domain/packing.dart';
import '../../theme/app_theme.dart';
import '../ui_helpers.dart';
import '../widgets/retro_widgets.dart';

class PackingHomeView extends StatelessWidget {
  final List<PackingList> lists;
  final List<PackingActivity> activities;
  final VoidCallback onItems, onNewList, onActivities, onLists, onNewActivity;
  final ValueChanged<PackingList> onList;
  final ValueChanged<String> onActivity;
  final DateTime? now;
  const PackingHomeView({
    super.key,
    required this.lists,
    required this.activities,
    required this.onItems,
    required this.onNewList,
    required this.onActivities,
    required this.onLists,
    required this.onNewActivity,
    required this.onList,
    required this.onActivity,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final hour = (now ?? DateTime.now()).hour;
    final greeting = hour < 12
        ? 'Good morning!'
        : hour < 18
        ? 'Good afternoon!'
        : 'Good evening!';
    final open = activities.where((a) => a.editable).toList()
      ..sort((a, b) {
        final priority = (a.status == ActivityStatus.active ? 0 : 1).compareTo(
          b.status == ActivityStatus.active ? 0 : 1,
        );
        return priority != 0 ? priority : a.startsAt.compareTo(b.startsAt);
      });
    final featured = open.firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(greeting, style: AppTextStyles.heading.copyWith(fontSize: 24)),
        const SizedBox(height: 10),
        Text(
          featured == null
              ? 'Your next adventure starts here'
              : '${featured.items.length - featured.draft.length} item types still to check',
          style: AppTextStyles.pixel.copyWith(height: 1.8),
        ),
        const SizedBox(height: 20),
        if (featured != null)
          RetroPanel(
            color: AppColors.card,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RetroBadge(
                  featured.status.name.toUpperCase(),
                  color: AppColors.ink,
                ),
                const SizedBox(height: 14),
                Text(featured.name, style: AppTextStyles.heading),
                const SizedBox(height: 8),
                Text(
                  '${featured.status == ActivityStatus.planned ? 'Starts' : 'Ends'} ${dateLabel(featured.status == ActivityStatus.planned ? featured.startsAt : featured.endsAt)}',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 12),
                RetroProgress(
                  found: featured.draft.length,
                  total: featured.items.length,
                  label: featured.status == ActivityStatus.planned
                      ? 'Before check'
                      : 'Return check',
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: () => onActivity(featured.id),
                    label: const Text('Continue'),
                    icon: const Icon(Icons.arrow_forward),
                  ),
                ),
              ],
            ),
          )
        else ...[
          const RetroEmpty(
            title: 'Ready for your next lakwatsa?',
            message: 'Make a list of your essentials, then create an activity to start packing.',
            icon: Icons.backpack_outlined,
          ),
          FilledButton.icon(
            onPressed: onNewActivity,
            icon: const Icon(Icons.add),
            label: const Text('Create activity'),
          ),
        ],
        const SizedBox(height: 14),
        Text(
          'Quick Actions',
          style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _action('My Items', AppColors.orange, onItems),
            const SizedBox(width: 10),
            _action('New List', AppColors.green, onNewList),
            const SizedBox(width: 10),
            _action('Activities', AppColors.ink, onActivities),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'Your Lists',
                style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
              ),
            ),
            TextButton(onPressed: onLists, child: const Text('See all')),
          ],
        ),
        const SizedBox(height: 8),
        if (lists.isEmpty)
          const RetroEmpty(
            title: 'No lists yet',
            message: 'Tap New List to group your saved items.',
            icon: Icons.list_alt_outlined,
          ),
        for (final list in lists.take(3))
          RetroPanel(
            onTap: () => onList(list),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(list.name, style: AppTextStyles.bodyBold),
                      const SizedBox(height: 5),
                      Text(
                        '${list.quantities.length} item types',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
      ],
    );
  }

  Widget _action(String label, Color shadow, VoidCallback action) => Expanded(
    child: RetroPanel(
      shadowColor: shadow,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
      onTap: action,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
      ),
    ),
  );
}
