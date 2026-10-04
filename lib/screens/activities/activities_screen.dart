import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../repositories/firestore_activity_repository.dart';
import '../../services/auth_service.dart';
import 'create_activity_screen.dart';
import 'activity_details_screen.dart';
import '../../theme/app_theme.dart';

class ActivitiesScreen extends StatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  State<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends State<ActivitiesScreen> {
  FirestoreActivityRepository? activityRepository;

  String selectedTab = 'UPCOMING';

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      activityRepository = FirestoreActivityRepository(userId: user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              onAdd: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) {
                      return const CreateActivityScreen();
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            _ActivityTabs(
              selectedTab: selectedTab,
              onChanged: (tab) {
                setState(() {
                  selectedTab = tab;
                });
              },
            ),

            const SizedBox(height: 16),

            Expanded(child: _buildActivities()),
          ],
        ),
      ),
    );
  }

  Widget _buildActivities() {
    if (activityRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<model.Activity>>(
      stream: activityRepository!.watchActivities(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load activities.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final activities = snapshot.data ?? [];

        final filteredActivities = activities.where((activity) {
          return activity.status == selectedTab;
        }).toList();

        if (filteredActivities.isEmpty) {
          return _EmptyState(status: selectedTab);
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          itemCount: filteredActivities.length,
          itemBuilder: (context, index) {
            final activity = filteredActivities[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _ActivityCard(
                activity: activity,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return ActivityDetailsScreen(activity: activity);
                      },
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAdd;

  const _Header({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          Text(
            'Activities',
            style: AppTextStyles.heading.copyWith(fontSize: 24),
          ),

          const Spacer(),

          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.ink,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: const [
                  BoxShadow(color: AppColors.green, offset: Offset(3, 3)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '+',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.background,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTabs extends StatelessWidget {
  final String selectedTab;
  final ValueChanged<String> onChanged;

  const _ActivityTabs({required this.selectedTab, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _TabButton(
              text: 'Upcoming',
              selected: selectedTab == 'UPCOMING',
              onTap: () {
                onChanged('UPCOMING');
              },
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: _TabButton(
              text: 'Active',
              selected: selectedTab == 'ACTIVE',
              onTap: () {
                onChanged('ACTIVE');
              },
            ),
          ),

          const SizedBox(width: 8),

          Expanded(
            child: _TabButton(
              text: 'History',
              selected: selectedTab == 'COMPLETED',
              onTap: () {
                onChanged('COMPLETED');
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: selected ? AppColors.ink : AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.bodyBold.copyWith(
            fontSize: 12,
            color: selected ? AppColors.background : AppColors.ink,
          ),
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final model.Activity activity;
  final VoidCallback onTap;

  const _ActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(5),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    _getActivityIcon(activity.type),
                    color: AppColors.ink,
                    size: 24,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
                      ),

                      const SizedBox(height: 3),

                      Text(activity.type, style: AppTextStyles.body),
                    ],
                  ),
                ),

                _StatusBadge(status: activity.status),
              ],
            ),

            const SizedBox(height: 14),

            Container(height: 1, color: AppColors.ink.withValues(alpha: 0.25)),

            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  color: AppColors.ink,
                  size: 17,
                ),

                const SizedBox(width: 7),

                Text(
                  _formatDate(activity.activityDate),
                  style: AppTextStyles.body,
                ),
              ],
            ),

            const SizedBox(height: 7),

            Row(
              children: [
                const Icon(Icons.access_time, color: AppColors.ink, size: 17),

                const SizedBox(width: 7),

                Text(
                  '${_formatTime(activity.startAt)}'
                  ' - '
                  '${_formatTime(activity.endAt)}',
                  style: AppTextStyles.body,
                ),
              ],
            ),

            if (activity.reminderEnabled) ...[
              const SizedBox(height: 7),

              Row(
                children: [
                  const Icon(
                    Icons.notifications_none,
                    color: AppColors.ink,
                    size: 17,
                  ),

                  const SizedBox(width: 7),

                  Text(
                    'Reminder '
                    '${activity.reminderMinutes} min before end',
                    style: AppTextStyles.body,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'Trip':
        return Icons.luggage_outlined;

      case 'School':
        return Icons.school_outlined;

      case 'Work':
        return Icons.work_outline;

      case 'Daily':
        return Icons.today_outlined;

      default:
        return Icons.event_outlined;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    String text;

    switch (status) {
      case 'ACTIVE':
        text = 'ACTIVE';
        break;

      case 'COMPLETED':
        text = 'DONE';
        break;

      default:
        text = 'UPCOMING';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: status == 'ACTIVE' ? AppColors.green : AppColors.card,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodyBold.copyWith(
          fontSize: 9,
          color: status == 'ACTIVE' ? AppColors.background : AppColors.ink,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String status;

  const _EmptyState({required this.status});

  @override
  Widget build(BuildContext context) {
    String title;
    String message;
    IconData icon;

    switch (status) {
      case 'ACTIVE':
        title = 'No active activities';
        message = 'Activities you start will appear here.';
        icon = Icons.play_circle_outline;
        break;

      case 'COMPLETED':
        title = 'No activity history';
        message = 'Completed activities will appear here.';
        icon = Icons.history;
        break;

      default:
        title = 'No upcoming activities';
        message = 'Create an activity to start planning.';
        icon = Icons.event_outlined;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: AppColors.muted),

            const SizedBox(height: 14),

            Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),

            const SizedBox(height: 5),

            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
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

String _formatTime(DateTime date) {
  final hour = date.hour == 0
      ? 12
      : date.hour > 12
      ? date.hour - 12
      : date.hour;

  final minute = date.minute.toString().padLeft(2, '0');

  final period = date.hour >= 12 ? 'PM' : 'AM';

  return '$hour:$minute $period';
}
