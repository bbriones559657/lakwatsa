import 'package:flutter/material.dart';

import '../../domain/packing.dart';
import '../../theme/app_theme.dart';
import '../ui_helpers.dart';
import '../widgets/retro_widgets.dart';

class PackingActivitiesView extends StatelessWidget {
  final List<PackingActivity> activities;
  final String query;
  final String filter;
  final ValueChanged<String> onFilter;
  final ValueChanged<String> onOpen;
  const PackingActivitiesView({
    super.key,
    required this.activities,
    required this.query,
    required this.filter,
    required this.onFilter,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) {
    final history = filter == 'History';
    final visible = activities
        .where(
          (a) =>
              a.name.toLowerCase().contains(query) &&
              (history
                  ? !a.editable
                  : a.status ==
                        (filter == 'Active'
                            ? ActivityStatus.active
                            : ActivityStatus.planned)),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final tab in ['Upcoming', 'Active', 'History'])
              if (filter == tab)
                FilledButton(onPressed: () => onFilter(tab), child: Text(tab))
              else
                OutlinedButton(
                  onPressed: () => onFilter(tab),
                  child: Text(tab),
                ),
          ],
        ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          RetroEmpty(
            title: history
                ? 'No history yet'
                : 'No ${filter.toLowerCase()} activities',
            message: history
                ? 'Completed and cancelled activities will appear here.'
                : 'Create an activity from one of your saved lists.',
            icon: Icons.backpack_outlined,
          ),
        for (final activity in visible)
          RetroPanel(
            onTap: () => onOpen(activity.id),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RetroBadge(
                      activity.status.name.toUpperCase(),
                      color: switch (activity.status) {
                        ActivityStatus.completed => AppColors.green,
                        ActivityStatus.planned => AppColors.orange,
                        _ => AppColors.ink,
                      },
                    ),
                    Text(activity.type, style: AppTextStyles.body),
                  ],
                ),
                const SizedBox(height: 14),
                Text(activity.name, style: AppTextStyles.heading),
                const SizedBox(height: 8),
                Text(
                  'Ends ${dateLabel(activity.endsAt)}',
                  style: AppTextStyles.body,
                ),
                const SizedBox(height: 14),
                if (activity.editable)
                  RetroProgress(
                    found: activity.draft.length,
                    total: activity.items.length,
                    label: activity.status == ActivityStatus.planned
                        ? 'Before check'
                        : 'Return check',
                  )
                else
                  Text(
                    '${activity.items.length} item types / View saved results',
                    style: AppTextStyles.body,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
