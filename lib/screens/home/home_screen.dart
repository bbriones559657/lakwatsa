import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../models/activity_check_draft.dart';
import '../../models/activity_item.dart';
import '../../models/item_list.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../repositories/list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onOpenItems;
  final VoidCallback onCreateList;
  final VoidCallback onOpenLists;
  final VoidCallback onOpenActivities;
  final ValueChanged<model.Activity> onContinueActivity;
  final ValueChanged<ItemList> onOpenList;
  final VoidCallback? onSignOut;

  // Optional repositories keep the dashboard testable without a live Firebase
  // app while production still builds its repositories from the signed-in user.
  final ActivityRepository? activityRepository;
  final ListRepository? listRepository;
  final String? profileInitial;

  const HomeScreen({
    super.key,
    required this.onOpenItems,
    required this.onCreateList,
    required this.onOpenLists,
    required this.onOpenActivities,
    required this.onContinueActivity,
    required this.onOpenList,
    this.onSignOut,
    this.activityRepository,
    this.listRepository,
    this.profileInitial,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  ActivityRepository? activityRepository;
  ListRepository? listRepository;
  late final String profileInitial;

  @override
  void initState() {
    super.initState();

    activityRepository = widget.activityRepository;
    listRepository = widget.listRepository;

    final needsSignedInUser =
        activityRepository == null ||
        listRepository == null ||
        widget.profileInitial == null;
    final user = needsSignedInUser ? AuthService().currentUser : null;

    if (user != null) {
      activityRepository ??= FirestoreActivityRepository(userId: user.uid);
      listRepository ??= FirestoreListRepository(userId: user.uid);
    }

    profileInitial =
        widget.profileInitial ?? _initialFor(user?.displayName, user?.email);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const LakwatsaBackgroundDots(),
        Column(
          children: [
            LakwatsaTopBar(
              title: 'Lakwatsa',
              actions: [
                _ProfileBadge(initial: profileInitial),
                if (widget.onSignOut != null)
                  TextButton(
                    onPressed: widget.onSignOut,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.ink,
                      minimumSize: const Size(72, 48),
                    ),
                    child: const Text('Sign out'),
                  ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ActivityOverview(
                      repository: activityRepository,
                      onContinue: widget.onContinueActivity,
                      onOpenActivities: widget.onOpenActivities,
                    ),
                    _QuickActions(
                      onOpenItems: widget.onOpenItems,
                      onCreateList: widget.onCreateList,
                      onOpenActivities: widget.onOpenActivities,
                    ),
                    _RecentLists(
                      repository: listRepository,
                      onSeeAll: widget.onOpenLists,
                      onOpenList: widget.onOpenList,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

String _initialFor(String? displayName, String? email) {
  final source = (displayName?.trim().isNotEmpty ?? false)
      ? displayName!.trim()
      : email?.trim() ?? '';

  if (source.isEmpty) {
    return 'U';
  }

  return source.substring(0, 1).toUpperCase();
}

class _ProfileBadge extends StatelessWidget {
  final String initial;

  const _ProfileBadge({required this.initial});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'User profile',
      child: SizedBox(
        width: AppMetrics.touchTarget,
        height: AppMetrics.touchTarget,
        child: Center(
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text(initial, style: AppTextStyles.bodyBold),
          ),
        ),
      ),
    );
  }
}

class _ActivityOverview extends StatelessWidget {
  final ActivityRepository? repository;
  final ValueChanged<model.Activity> onContinue;
  final VoidCallback onOpenActivities;

  const _ActivityOverview({
    required this.repository,
    required this.onContinue,
    required this.onOpenActivities,
  });

  @override
  Widget build(BuildContext context) {
    if (repository == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Greeting(activeCount: 0),
          _DashboardMessageCard(
            title: 'Activities unavailable',
            message: 'Sign in again to load your active activity.',
            actionLabel: 'Activities',
            onPressed: onOpenActivities,
          ),
        ],
      );
    }

    return StreamBuilder<List<model.Activity>>(
      stream: repository!.watchActivities(),
      builder: (context, snapshot) {
        final activities = snapshot.data ?? const <model.Activity>[];
        final activeActivities =
            activities.where((activity) => activity.isActive).toList()
              ..sort((a, b) => b.startAt.compareTo(a.startAt));

        final activeActivity = activeActivities.isEmpty
            ? null
            : activeActivities.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Greeting(activeCount: activeActivities.length),
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const _DashboardMessageCard(
                title: 'Loading activities...',
                message: 'Checking what is active right now.',
              )
            else if (snapshot.hasError)
              _DashboardMessageCard(
                title: 'Could not load activities',
                message:
                    'Your dashboard will update when the connection returns.',
                actionLabel: 'Activities',
                onPressed: onOpenActivities,
              )
            else if (activeActivity == null)
              _DashboardMessageCard(
                title: 'No active activity',
                message: 'Start an upcoming activity when you are ready to check your items.',
                actionLabel: 'View Activities',
                onPressed: onOpenActivities,
              )
            else
              _ActiveActivityCard(
                activity: activeActivity,
                repository: repository!,
                onContinue: () => onContinue(activeActivity),
              ),
          ],
        );
      },
    );
  }
}

class _Greeting extends StatelessWidget {
  final int activeCount;

  const _Greeting({required this.activeCount});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning!'
        : hour < 18
        ? 'Good afternoon!'
        : 'Good evening!';
    final subtitle = activeCount == 0
        ? 'ready for your next activity'
        : activeCount == 1
        ? '1 active activity'
        : '$activeCount active activities';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(greeting, style: AppTextStyles.heading),
          const SizedBox(height: 8),
          Text(subtitle, style: AppTextStyles.pixel),
        ],
      ),
    );
  }
}

class _ActiveActivityCard extends StatefulWidget {
  final model.Activity activity;
  final ActivityRepository repository;
  final VoidCallback onContinue;

  const _ActiveActivityCard({
    required this.activity,
    required this.repository,
    required this.onContinue,
  });

  @override
  State<_ActiveActivityCard> createState() => _ActiveActivityCardState();
}

class _ActiveActivityCardState extends State<_ActiveActivityCard> {
  late Stream<List<ActivityItem>> _itemsStream;
  late Stream<ActivityCheckDraft?> _draftStream;

  @override
  void initState() {
    super.initState();
    _bindStreams();
  }

  @override
  void didUpdateWidget(covariant _ActiveActivityCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activity.id != widget.activity.id ||
        oldWidget.repository != widget.repository) {
      _bindStreams();
    }
  }

  void _bindStreams() {
    _itemsStream = widget.repository.watchActivityItems(widget.activity.id);
    _draftStream = widget.repository.watchCheckDraft(
      activityId: widget.activity.id,
      checkType: 'RETURN',
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = widget.activity;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LakwatsaPixelCard(
        color: AppColors.card,
        shadowOffset: const Offset(5, 5),
        minHeight: 180,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: StreamBuilder<List<ActivityItem>>(
            stream: _itemsStream,
            builder: (context, itemSnapshot) {
              final items = itemSnapshot.data;

              return StreamBuilder<ActivityCheckDraft?>(
                stream: _draftStream,
                builder: (context, draftSnapshot) {
                  final draft = draftSnapshot.data;
                  final progress = _returnProgress(
                    items: items,
                    draft: draft,
                    hasError: itemSnapshot.hasError || draftSnapshot.hasError,
                  );
                  final hasStarted = draft != null;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54,
                        height: 20,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        alignment: Alignment.center,
                        child: Text('ACTIVE', style: AppTextStyles.pixelWhite),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        activity.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.heading.copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${activity.type} · ${_formatDate(activity.activityDate)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body,
                      ),
                      const SizedBox(height: 7),
                      _DashboardProgressBar(progress: progress),
                      const SizedBox(height: 7),
                      Align(
                        alignment: Alignment.centerRight,
                        child: _DashboardActionButton(
                          label: hasStarted
                              ? 'Continue Checking →'
                              : 'Start Return Check →',
                          semanticsLabel: hasStarted
                              ? 'Continue return check for ${activity.name}'
                              : 'Start return check for ${activity.name}',
                          onPressed: widget.onContinue,
                          width: hasStarted ? 154 : 160,
                          height: 32,
                          shadowColor: AppColors.green,
                          filled: true,
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

_ActivityProgress? _returnProgress({
  required List<ActivityItem>? items,
  required ActivityCheckDraft? draft,
  required bool hasError,
}) {
  if (hasError || items == null) {
    return null;
  }

  final itemIds = items.map((item) => item.id).toSet();
  final found = draft == null
      ? 0
      : draft.foundMethods.keys.where(itemIds.contains).length;

  return _ActivityProgress(found: found, total: items.length);
}

class _DashboardProgressBar extends StatelessWidget {
  final _ActivityProgress? progress;

  const _DashboardProgressBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final found = progress?.found;
    final total = progress?.total;
    final fraction = progress?.fraction ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Text('Packing', style: AppTextStyles.pixelDark),
            const Spacer(),
            Text(
              found == null || total == null ? '—/—' : '$found/$total',
              style: AppTextStyles.pixelDark,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Semantics(
          label: progress == null
              ? 'Return check progress unavailable'
              : 'Return check progress: ${progress!.found} of ${progress!.total} items confirmed',
          child: SizedBox(
            key: const Key('dashboard-activity-progress'),
            height: 16,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Positioned(
                  left: 2,
                  top: 2,
                  bottom: 2,
                  right: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: fraction,
                      heightFactor: 1,
                      child: const ColoredBox(color: AppColors.green),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityProgress {
  final int found;
  final int total;

  const _ActivityProgress({required this.found, required this.total});

  double get fraction {
    if (total <= 0) {
      return 0;
    }

    return (found / total).clamp(0.0, 1.0);
  }
}

class _DashboardMessageCard extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onPressed;

  const _DashboardMessageCard({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LakwatsaPixelCard(
        color: AppColors.card,
        shadowOffset: const Offset(5, 5),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyBold),
                    const SizedBox(height: 4),
                    Text(message, style: AppTextStyles.body),
                  ],
                ),
              ),
              if (actionLabel != null && onPressed != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onPressed,
                  child: Text(actionLabel!, style: AppTextStyles.bodyBold),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final VoidCallback onOpenItems;
  final VoidCallback onCreateList;
  final VoidCallback onOpenActivities;

  const _QuickActions({
    required this.onOpenItems,
    required this.onCreateList,
    required this.onOpenActivities,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTextStyles.bodyBold),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  title: 'My Items',
                  semanticsLabel: 'Open My Items',
                  shadowColor: AppColors.orange,
                  onPressed: onOpenItems,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: 'New List',
                  semanticsLabel: 'Create a new list',
                  shadowColor: AppColors.green,
                  onPressed: onCreateList,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: 'Activities',
                  semanticsLabel: 'Open Activities',
                  shadowColor: AppColors.ink,
                  onPressed: onOpenActivities,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String title;
  final String semanticsLabel;
  final Color shadowColor;
  final VoidCallback onPressed;

  const _QuickAction({
    required this.title,
    required this.semanticsLabel,
    required this.shadowColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return _DashboardActionButton(
      label: title,
      semanticsLabel: semanticsLabel,
      onPressed: onPressed,
      height: 52,
      shadowColor: shadowColor,
    );
  }
}

class _DashboardActionButton extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final VoidCallback onPressed;
  final Color shadowColor;
  final double height;
  final double? width;
  final bool filled;

  const _DashboardActionButton({
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
    required this.shadowColor,
    required this.height,
    this.width,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final compact = height < AppMetrics.touchTarget;
    final borderWidth = compact ? 2.0 : AppMetrics.strongBorderWidth;
    final visualHeight = compact
        ? AppMetrics.touchTarget + (borderWidth * 2)
        : height;
    final foreground = filled ? AppColors.background : AppColors.ink;
    final visualButton = Container(
      width: width,
      height: visualHeight,
      decoration: BoxDecoration(
        color: filled ? AppColors.ink : AppColors.background,
        border: Border.all(color: AppColors.ink, width: borderWidth),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: [
          BoxShadow(
            color: shadowColor,
            offset: Offset(compact ? 3 : 4, compact ? 3 : 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyBold.copyWith(
                  color: foreground,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: visualButton,
    );
  }
}

class _RecentLists extends StatelessWidget {
  final ListRepository? repository;
  final VoidCallback onSeeAll;
  final ValueChanged<ItemList> onOpenList;

  const _RecentLists({
    required this.repository,
    required this.onSeeAll,
    required this.onOpenList,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Recent Lists', style: AppTextStyles.bodyBold),
              ),
              TextButton(
                onPressed: onSeeAll,
                style: TextButton.styleFrom(
                  minimumSize: const Size(52, AppMetrics.touchTarget),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  foregroundColor: AppColors.muted,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text('See all', style: AppTextStyles.body),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildLists(),
        ],
      ),
    );
  }

  Widget _buildLists() {
    if (repository == null) {
      return Text(
        'Sign in again to load your lists.',
        style: AppTextStyles.body,
      );
    }

    return StreamBuilder<List<ItemList>>(
      stream: repository!.watchLists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return Text('Loading recent lists...', style: AppTextStyles.body);
        }

        if (snapshot.hasError) {
          return Text(
            'Recent lists are temporarily unavailable.',
            style: AppTextStyles.body,
          );
        }

        final lists = [...?snapshot.data]
          ..sort((a, b) => _listSortDate(b).compareTo(_listSortDate(a)));
        final recentLists = lists.take(2).toList();

        if (recentLists.isEmpty) {
          return Text(
            'No lists yet. Create one from Quick Actions.',
            style: AppTextStyles.body,
          );
        }

        return Column(
          children: [
            for (var index = 0; index < recentLists.length; index++) ...[
              _RecentListCard(
                list: recentLists[index],
                repository: repository!,
                onTap: () => onOpenList(recentLists[index]),
              ),
              if (index < recentLists.length - 1) const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

DateTime _listSortDate(ItemList list) {
  return list.updatedAt ??
      list.createdAt ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

class _RecentListCard extends StatelessWidget {
  final ItemList list;
  final ListRepository repository;
  final VoidCallback onTap;

  const _RecentListCard({
    required this.list,
    required this.repository,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Open ${list.name}',
      child: Container(
        height: 68,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          list.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyBold,
                        ),
                        const SizedBox(height: 3),
                        StreamBuilder<List<String>>(
                          stream: repository.watchListItemIds(list.id),
                          builder: (context, snapshot) {
                            final count = snapshot.data?.length;
                            final text = count == null
                                ? 'Loading items...'
                                : '$count ${count == 1 ? 'item' : 'items'}';
                            return Text(
                              text,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.body,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.ink,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
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

  return '${months[date.month - 1]} ${date.day}';
}
