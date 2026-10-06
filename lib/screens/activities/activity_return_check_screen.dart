import 'package:flutter/material.dart';

import '../../models/activity.dart' as model;
import '../../models/activity_item.dart';
import '../../repositories/activity_repository.dart';
import '../../repositories/firestore_activity_repository.dart';
import '../../services/auth_service.dart';
import '../../services/check_draft_writer.dart';
import '../../theme/app_theme.dart';
import 'activity_check_error_text.dart';
import 'activity_qr_scanner_screen.dart';

class ActivityReturnCheckScreen extends StatefulWidget {
  final model.Activity activity;
  final ActivityRepository? activityRepository;

  const ActivityReturnCheckScreen({
    super.key,
    required this.activity,
    this.activityRepository,
  });

  @override
  State<ActivityReturnCheckScreen> createState() =>
      _ActivityReturnCheckScreenState();
}

class _ActivityReturnCheckScreenState extends State<ActivityReturnCheckScreen> {
  ActivityRepository? activityRepository;

  // Reuse the Firestore subscription instead of restarting it on every tap.
  Stream<List<ActivityItem>>? _activityItemsStream;

  final Map<String, String> foundMethods = {};

  late DateTime checkStartedAt;
  CheckDraftWriter? _draftWriter;
  bool _loadingDraft = true;
  Object? _loadError;
  Object? _saveError;

  bool isSaving = false;

  @override
  void initState() {
    super.initState();

    checkStartedAt = DateTime.now();

    activityRepository = widget.activityRepository;
    final user = activityRepository == null ? AuthService().currentUser : null;

    if (activityRepository == null && user != null) {
      activityRepository = FirestoreActivityRepository(userId: user.uid);
    }

    if (activityRepository != null) {
      _activityItemsStream =
          activityRepository!.watchActivityItems(widget.activity.id);
      _draftWriter = CheckDraftWriter(
        write: (snapshot) => activityRepository!.saveCheckDraft(
          activityId: widget.activity.id,
          checkType: 'RETURN',
          startedAt: checkStartedAt,
          foundMethods: snapshot,
        ),
        onError: (error) {
          if (mounted) setState(() => _saveError = error);
        },
        onSaved: () {
          if (mounted) setState(() => _saveError = null);
        },
      );
      _restoreDraft();
    } else {
      _loadingDraft = false;
    }
  }

  Future<void> _restoreDraft() async {
    try {
      final draft = await activityRepository!.getCheckDraft(
        activityId: widget.activity.id,
        checkType: 'RETURN',
      );
      if (!mounted) return;
      setState(() {
        if (draft != null) {
          checkStartedAt = draft.startedAt;
          foundMethods
            ..clear()
            ..addAll(draft.foundMethods);
        }
        _loadError = null;
      });

      if (draft == null) {
        // Opening Return Check starts the session. Persist an empty draft so
        // Home and Activity Details can offer "Continue Checking" even if
        // the user leaves before confirming the first Item.
        _saveDraft();
      }
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loadingDraft = false);
    }
  }

  void _saveDraft() {
    _draftWriter?.save(foundMethods);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(activityName: widget.activity.name),
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

    if (_loadingDraft) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_loadError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Could not load your saved check.'),
            TextButton(
              onPressed: () {
                setState(() => _loadingDraft = true);
                _restoreDraft();
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<ActivityItem>>(
      stream: _activityItemsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load items.\n'
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

        return Column(
          children: [
            _ProgressSection(
              found: items.where((item) => foundMethods.containsKey(item.id)).length,
              total: items.length,
            ),

            if (_saveError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        activityDraftSaveErrorMessage(_saveError!),
                        style: AppTextStyles.body,
                      ),
                    ),
                    if (!isLegacyActivityMigrationError(_saveError!))
                      TextButton(
                        onPressed: _saveDraft,
                        child: const Text('Retry'),
                      ),
                  ],
                ),
              ),

            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text(
                        'No items in this Activity.',
                        style: AppTextStyles.body,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];

                        final found = foundMethods.containsKey(item.id);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _CheckItemCard(
                            item: item,
                            found: found,
                            onTap: () {
                              _toggleManualItem(item);
                            },
                          ),
                        );
                      },
                    ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: GestureDetector(
                onTap: isSaving
                    ? null
                    : () {
                        _openQrScanner(items);
                      },
                child: Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_scanner, color: AppColors.ink),

                      const SizedBox(width: 8),

                      Text('Scan QR Codes', style: AppTextStyles.bodyBold),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: GestureDetector(
                  onTap: isSaving
                      ? null
                      : () {
                          _confirmFinish(items);
                        },
                  child: Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: isSaving ? AppColors.muted : AppColors.ink,
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isSaving
                          ? null
                          : const [
                              BoxShadow(
                                color: AppColors.green,
                                offset: Offset(3, 3),
                              ),
                            ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      isSaving ? 'Saving...' : 'Finish Activity',
                      style: AppTextStyles.bodyBold.copyWith(
                        color: AppColors.background,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _toggleManualItem(ActivityItem item) {
    setState(() {
      if (foundMethods.containsKey(item.id)) {
        foundMethods.remove(item.id);
      } else {
        foundMethods[item.id] = 'MANUAL';
      }
    });
    _saveDraft();
  }

  Future<void> _openQrScanner(List<ActivityItem> items) async {
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ActivityQrScannerScreen(
            activityId: widget.activity.id,
            activityItems: items,
            checkedMethods: foundMethods,
          );
        },
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      foundMethods
        ..clear()
        ..addAll(result);
    });
    _saveDraft();
  }

  Future<void> _confirmFinish(List<ActivityItem> items) async {
    final uncheckedCount =
        items.where((item) => !foundMethods.containsKey(item.id)).length;

    final shouldFinish = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          title: Text(
            uncheckedCount == 0 ? 'All Items Checked' : 'Finish Activity?',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: Text(
            uncheckedCount == 0
                ? 'All ${items.length} items are confirmed. '
                      'Finish this Activity?'
                : '$uncheckedCount '
                      '${uncheckedCount == 1 ? 'item is' : 'items are'} '
                      'still unchecked. '
                      '${uncheckedCount == 1 ? 'It' : 'They'} will be '
                      'marked as Not Found if you finish now.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text('Keep Checking', style: AppTextStyles.bodyBold),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.ink,
                foregroundColor: AppColors.background,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Finish Activity'),
            ),
          ],
        );
      },
    );

    if (shouldFinish != true) {
      return;
    }

    await _finishReturnCheck(items);
  }

  Future<void> _finishReturnCheck(List<ActivityItem> items) async {
    if (activityRepository == null) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      // Prevent an earlier queued draft write from recreating the draft.
      final writer = _draftWriter;
      if (writer != null) await writer.flush();
      await activityRepository!.completeReturnCheck(
        activityId: widget.activity.id,
        activityItems: items,
        foundMethods: foundMethods,
        startedAt: checkStartedAt,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Activity completed.')));

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(activityCheckFinishErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }
}

class _Header extends StatelessWidget {
  final String activityName;

  const _Header({required this.activityName});

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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Return Check',
                  style: AppTextStyles.heading.copyWith(fontSize: 19),
                ),
                Text(
                  activityName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressSection extends StatelessWidget {
  final int found;
  final int total;

  const _ProgressSection({required this.found, required this.total});

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : found / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Check your belongings',
                style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
              ),

              const Spacer(),

              Text('$found / $total', style: AppTextStyles.bodyBold),
            ],
          ),

          const SizedBox(height: 8),

          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.card,
              color: AppColors.green,
            ),
          ),

          const SizedBox(height: 9),

          Text(
            'Confirm each item before going home.',
            style: AppTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _CheckItemCard extends StatelessWidget {
  final ActivityItem item;
  final bool found;
  final VoidCallback onTap;

  const _CheckItemCard({
    required this.item,
    required this.found,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: found ? AppColors.card : AppColors.background,
          border: Border.all(color: AppColors.ink, width: found ? 2.5 : 2),
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
                color: found ? AppColors.green : AppColors.muted,
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

            Container(
              width: 28,
              height: 28,
              margin: const EdgeInsets.only(right: 16),
              decoration: BoxDecoration(
                color: found ? AppColors.green : AppColors.background,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: found
                  ? const Icon(
                      Icons.check,
                      color: AppColors.background,
                      size: 19,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
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
