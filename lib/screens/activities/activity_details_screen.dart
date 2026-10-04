import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../models/activity_item.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../services/auth_service.dart';
import 'activity_check_screen.dart';
import 'activity_return_check_screen.dart';
import 'activity_check_results_screen.dart';
import '../../theme/app_theme.dart';

class ActivityDetailsScreen extends StatefulWidget {
  final model.Activity activity;

  const ActivityDetailsScreen({super.key, required this.activity});

  @override
  State<ActivityDetailsScreen> createState() => _ActivityDetailsScreenState();
}

class _ActivityDetailsScreenState extends State<ActivityDetailsScreen> {
  FirestoreActivityRepository? activityRepository;

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
            _Header(title: widget.activity.name),
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (activityRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<ActivityItem>>(
      stream: activityRepository!.watchActivityItems(widget.activity.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load activity items.\n'
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

        final items = snapshot.data ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            _ActivityInfo(activity: widget.activity),

            const SizedBox(height: 24),

            Row(
              children: [
                Text(
                  'Items',
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '${items.length} '
                  '${items.length == 1 ? 'item' : 'items'}',
                  style: AppTextStyles.body,
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (items.isEmpty)
              const _EmptyItems()
            else
              ...items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ActivityItemCard(item: item),
                );
              }),

            const SizedBox(height: 14),

            _ActionButton(activity: widget.activity, onPressed: _handleAction),
          ],
        );
      },
    );
  }

  Future<void> _handleAction() async {
    if (widget.activity.status == 'UPCOMING') {
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) {
            return ActivityCheckScreen(activity: widget.activity);
          },
        ),
      );

      if (!mounted) {
        return;
      }

      if (completed == true) {
        Navigator.pop(context);
      }

      return;
    }

    if (widget.activity.status == 'ACTIVE') {
      final completed = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) {
            return ActivityReturnCheckScreen(activity: widget.activity);
          },
        ),
      );

      if (!mounted) {
        return;
      }

      if (completed == true) {
        Navigator.pop(context);
      }

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ActivityCheckResultsScreen(activity: widget.activity);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;

  const _Header({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.arrow_back, color: AppColors.ink),
            ),
          ),

          const SizedBox(width: 6),

          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading.copyWith(fontSize: 21),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityInfo extends StatelessWidget {
  final model.Activity activity;

  const _ActivityInfo({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
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
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _getActivityIcon(activity.type),
                  color: AppColors.ink,
                  size: 26,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activity.name,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 17),
                    ),

                    const SizedBox(height: 3),

                    Text(activity.type, style: AppTextStyles.body),
                  ],
                ),
              ),

              _StatusBadge(status: activity.status),
            ],
          ),

          const SizedBox(height: 16),

          _InfoRow(
            icon: Icons.calendar_today_outlined,
            text: _formatDate(activity.activityDate),
          ),

          const SizedBox(height: 9),

          _InfoRow(
            icon: Icons.access_time,
            text:
                '${_formatTime(activity.startAt)}'
                ' - '
                '${_formatTime(activity.endAt)}',
          ),

          if (activity.reminderEnabled) ...[
            const SizedBox(height: 9),
            _InfoRow(
              icon: Icons.notifications_none,
              text:
                  'Reminder ${activity.reminderMinutes} '
                  'min before end',
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.ink, size: 18),
        const SizedBox(width: 9),
        Expanded(child: Text(text, style: AppTextStyles.body)),
      ],
    );
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
        color: status == 'ACTIVE' ? AppColors.green : AppColors.background,
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

class _ActivityItemCard extends StatelessWidget {
  final ActivityItem item;

  const _ActivityItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: double.infinity,
            decoration: BoxDecoration(
              color: item.hasQr ? AppColors.orange : AppColors.muted,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                bottomLeft: Radius.circular(2),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Icon(
              _getItemIcon(item.icon),
              color: AppColors.ink,
              size: 24,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                ),

                const SizedBox(height: 3),

                Text(
                  '${item.category} • Qty ${item.quantity}',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),

          if (item.hasQr)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.green,
                border: Border.all(color: AppColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                'QR',
                style: AppTextStyles.pixelDark.copyWith(
                  color: AppColors.background,
                  fontSize: 5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.muted,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text('No items', style: AppTextStyles.bodyBold),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final model.Activity activity;
  final VoidCallback onPressed;

  const _ActionButton({required this.activity, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    String text;

    switch (activity.status) {
      case 'ACTIVE':
        text = 'Check Items Before Going Home';
        break;

      case 'COMPLETED':
        text = 'View Check Results';
        break;

      default:
        text = 'Check Items Before Leaving';
    }

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 52,
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
          text,
          style: AppTextStyles.bodyBold.copyWith(color: AppColors.background),
        ),
      ),
    );
  }
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

IconData _getItemIcon(String icon) {
  switch (icon) {
    case 'electronics':
      return Icons.devices_outlined;
    case 'documents':
      return Icons.description_outlined;
    case 'clothing':
      return Icons.checkroom_outlined;
    case 'toiletries':
      return Icons.cleaning_services_outlined;
    case 'laptop':
      return Icons.laptop_mac;
    case 'charger':
      return Icons.battery_charging_full;
    case 'battery':
      return Icons.battery_5_bar;
    case 'passport':
      return Icons.badge_outlined;
    case 'id':
      return Icons.credit_card;
    case 'jacket':
    case 'shirt':
      return Icons.checkroom;
    case 'toothbrush':
      return Icons.cleaning_services_outlined;
    default:
      return Icons.inventory_2_outlined;
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
