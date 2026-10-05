import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../models/activity_check.dart';
import '../../models/activity_check_item.dart';
import '../../models/activity_item.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ActivityCheckResultsScreen extends StatefulWidget {
  final model.Activity activity;

  const ActivityCheckResultsScreen({super.key, required this.activity});

  @override
  State<ActivityCheckResultsScreen> createState() =>
      _ActivityCheckResultsScreenState();
}

class _ActivityCheckResultsScreenState
    extends State<ActivityCheckResultsScreen> {
  FirestoreActivityRepository? repository;

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      repository = FirestoreActivityRepository(userId: user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          'Check Results',
          style: AppTextStyles.heading.copyWith(fontSize: 21),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.ink),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (repository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return FutureBuilder<_HistoryData>(
      future: _loadHistory(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load check results.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          children: [
            _ActivitySummary(activity: widget.activity),

            const SizedBox(height: 24),

            _CheckSummary(
              beforeResults: data.beforeItems,
              returnResults: data.returnItems,
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'ITEM',
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 11),
                  ),
                ),

                Expanded(
                  child: Text(
                    'BEFORE',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 10),
                  ),
                ),

                Expanded(
                  child: Text(
                    'RETURN',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyBold.copyWith(fontSize: 10),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Container(height: 2, color: AppColors.ink),

            const SizedBox(height: 10),

            ...data.activityItems.map((item) {
              final before = data.beforeItems[item.id];

              final returned = data.returnItems[item.id];

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _ResultRow(
                  item: item,
                  beforeResult: before,
                  returnResult: returned,
                ),
              );
            }),

            const SizedBox(height: 14),

            _LegendCard(),
          ],
        );
      },
    );
  }

  Future<_HistoryData> _loadHistory() async {
    final beforeCheck = await repository!.getActivityCheckByType(
      activityId: widget.activity.id,
      type: 'BEFORE_ACTIVITY',
    );

    final returnCheck = await repository!.getActivityCheckByType(
      activityId: widget.activity.id,
      type: 'RETURN',
    );

    final activityItems = await repository!
        .watchActivityItems(widget.activity.id)
        .first;

    List<ActivityCheckItem> beforeCheckItems = [];
    List<ActivityCheckItem> returnCheckItems = [];

    if (beforeCheck != null) {
      beforeCheckItems = await repository!.getActivityCheckItems(
        activityId: widget.activity.id,
        checkId: beforeCheck.id,
      );
    }

    if (returnCheck != null) {
      returnCheckItems = await repository!.getActivityCheckItems(
        activityId: widget.activity.id,
        checkId: returnCheck.id,
      );
    }

    return _HistoryData(
      beforeCheck: beforeCheck,
      returnCheck: returnCheck,
      activityItems: activityItems,
      beforeItems: {
        for (final item in beforeCheckItems) item.activityItemId: item,
      },
      returnItems: {
        for (final item in returnCheckItems) item.activityItemId: item,
      },
    );
  }
}

class _HistoryData {
  final ActivityCheck? beforeCheck;
  final ActivityCheck? returnCheck;

  final List<ActivityItem> activityItems;

  final Map<String, ActivityCheckItem> beforeItems;
  final Map<String, ActivityCheckItem> returnItems;

  const _HistoryData({
    required this.beforeCheck,
    required this.returnCheck,
    required this.activityItems,
    required this.beforeItems,
    required this.returnItems,
  });
}

class _ActivitySummary extends StatelessWidget {
  final model.Activity activity;

  const _ActivitySummary({required this.activity});

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
      child: Row(
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

                const SizedBox(height: 4),

                Text(activity.type, style: AppTextStyles.body),

                const SizedBox(height: 3),

                Text(
                  _formatDate(activity.activityDate),
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.green,
              border: Border.all(color: AppColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'DONE',
              style: AppTextStyles.bodyBold.copyWith(
                color: AppColors.background,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckSummary extends StatelessWidget {
  final Map<String, ActivityCheckItem> beforeResults;

  final Map<String, ActivityCheckItem> returnResults;

  const _CheckSummary({
    required this.beforeResults,
    required this.returnResults,
  });

  @override
  Widget build(BuildContext context) {
    final beforeFound = beforeResults.values.where((item) {
      return item.status == 'FOUND';
    }).length;

    final returnFound = returnResults.values.where((item) {
      return item.status == 'FOUND';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'Before',
            value: beforeResults.isEmpty
                ? '—'
                : '$beforeFound / ${beforeResults.length}',
            subtitle: 'items found',
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _SummaryCard(
            title: 'Return',
            value: returnResults.isEmpty
                ? '—'
                : '$returnFound / ${returnResults.length}',
            subtitle: 'items found',
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.bodyBold),

          const SizedBox(height: 8),

          Text(value, style: AppTextStyles.heading.copyWith(fontSize: 20)),

          Text(subtitle, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final ActivityItem item;

  final ActivityCheckItem? beforeResult;
  final ActivityCheckItem? returnResult;

  const _ResultRow({
    required this.item,
    required this.beforeResult,
    required this.returnResult,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold,
                ),

                const SizedBox(height: 3),

                Text('Qty ${item.quantity}', style: AppTextStyles.body),

                if (item.addedDuringActivity) ...[
                  const SizedBox(height: 3),

                  Text(
                    'Added during activity',
                    style: AppTextStyles.body.copyWith(fontSize: 9),
                  ),
                ],
              ],
            ),
          ),

          Expanded(
            child: Center(child: _ResultBadge(result: beforeResult)),
          ),

          Expanded(
            child: Center(child: _ResultBadge(result: returnResult)),
          ),
        ],
      ),
    );
  }
}

class _ResultBadge extends StatelessWidget {
  final ActivityCheckItem? result;

  const _ResultBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return Text('—', style: AppTextStyles.bodyBold);
    }

    final found = result!.status == 'FOUND';

    if (!found) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.ink, width: 1.3),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          'MISSING',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyBold.copyWith(
            fontSize: 8,
            color: AppColors.ink,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.green,
        border: Border.all(color: AppColors.ink, width: 1.3),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'FOUND',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyBold.copyWith(
              fontSize: 8,
              color: AppColors.background,
            ),
          ),

          if (result!.method != null && result!.method!.isNotEmpty) ...[
            const SizedBox(height: 2),

            Text(
              result!.method!,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyBold.copyWith(
                fontSize: 7,
                color: AppColors.background,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LegendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: AppColors.ink, size: 20),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'MANUAL means the item was checked by tapping it. '
              'QR means the item was confirmed by scanning its QR code.',
              style: AppTextStyles.body,
            ),
          ),
        ],
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
