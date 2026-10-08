import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../services/item_qr_export_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';

class BulkQrExportScreen extends StatefulWidget {
  final Stream<List<Item>>? itemsStream;
  final ItemQrExportService exportService;

  const BulkQrExportScreen({
    super.key,
    this.itemsStream,
    this.exportService = const ItemQrExportService(),
  });

  @override
  State<BulkQrExportScreen> createState() => _BulkQrExportScreenState();
}

class _BulkQrExportScreenState extends State<BulkQrExportScreen> {
  FirestoreItemRepository? itemRepository;
  Stream<List<Item>>? itemsStream;
  final Set<String> selectedItemIds = <String>{};

  String? activeAction;
  int exportProgress = 0;
  int exportTotal = 0;

  @override
  void initState() {
    super.initState();

    if (widget.itemsStream != null) {
      itemsStream = widget.itemsStream;
      return;
    }

    final user = AuthService().currentUser;

    if (user != null) {
      itemRepository = FirestoreItemRepository(userId: user.uid);
      itemsStream = itemRepository!.watchItems();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      key: const ValueKey('bulk-qr-export-pop-scope'),
      canPop: activeAction == null,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: activeAction == null,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            'QR Label Export',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AppColors.ink),
          ),
        ),
        body: Stack(
          children: [
            const LakwatsaBackgroundDots(),
            if (itemsStream == null)
              Center(
                child: Text('Please sign in again.', style: AppTextStyles.body),
              )
            else
              StreamBuilder<List<Item>>(
                stream: itemsStream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Failed to load items.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.body,
                        ),
                      ),
                    );
                  }

                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allItems = snapshot.data ?? const <Item>[];
                  final qrItems = allItems.where((item) => item.hasQr).toList();
                  final withoutQrCount = allItems.length - qrItems.length;
                  final selectedItems = qrItems
                      .where((item) => selectedItemIds.contains(item.id))
                      .toList();

                  if (qrItems.isEmpty) {
                    return _NoQrItemsState(withoutQrCount: withoutQrCount);
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                          children: [
                            _ExportIntro(
                              qrReadyCount: qrItems.length,
                              withoutQrCount: withoutQrCount,
                            ),
                            const SizedBox(height: 18),
                            _SelectionHeader(
                              selectedCount: selectedItems.length,
                              allSelected:
                                  selectedItems.length == qrItems.length,
                              onToggleAll: () {
                                setState(() {
                                  if (selectedItems.length == qrItems.length) {
                                    selectedItemIds.clear();
                                  } else {
                                    selectedItemIds.addAll(
                                      qrItems.map((item) => item.id),
                                    );
                                  }
                                });
                              },
                            ),
                            const SizedBox(height: 10),
                            ...qrItems.map((item) {
                              final selected = selectedItemIds.contains(
                                item.id,
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _SelectableQrItemCard(
                                  key: ValueKey('bulk-qr-item-${item.id}'),
                                  item: item,
                                  selected: selected,
                                  onTap: activeAction != null
                                      ? null
                                      : () {
                                          setState(() {
                                            if (selected) {
                                              selectedItemIds.remove(item.id);
                                            } else {
                                              selectedItemIds.add(item.id);
                                            }
                                          });
                                        },
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      _ExportActions(
                        selectedCount: selectedItems.length,
                        activeAction: activeAction,
                        onPngPressed: selectedItems.isEmpty
                            ? null
                            : () => _exportPngCards(selectedItems),
                        onPdfPressed: selectedItems.isEmpty
                            ? null
                            : () => _exportPdfSheet(selectedItems),
                      ),
                    ],
                  );
                },
              ),
            if (activeAction != null)
              _ExportProcessingOverlay(
                action: activeAction!,
                completed: exportProgress,
                total: exportTotal,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPngCards(List<Item> items) async {
    await _runAction(
      key: 'png',
      failureMessage: 'Could not export the PNG cards. Please try again.',
      action: () {
        return widget.exportService.shareQrPngs(
          items,
          sharePositionOrigin: _sharePositionOrigin(),
          onProgress: _updateProgress,
        );
      },
    );
  }

  Future<void> _exportPdfSheet(List<Item> items) async {
    await _runAction(
      key: 'pdf',
      failureMessage: 'Could not export the PDF tag sheet. Please try again.',
      action: () async {
        final saved = await widget.exportService.exportQrSheetPdf(
          items,
          onProgress: _updateProgress,
        );

        if (saved && mounted) {
          _showMessage(
            '${items.length} QR ${items.length == 1 ? 'tag' : 'tags'} exported.',
          );
        }
      },
    );
  }

  Future<void> _runAction({
    required String key,
    required String failureMessage,
    required Future<void> Function() action,
  }) async {
    if (activeAction != null) {
      return;
    }

    setState(() {
      activeAction = key;
      exportProgress = 0;
      exportTotal = 0;
    });

    // Let Flutter paint the processing overlay before export work begins.
    await WidgetsBinding.instance.endOfFrame;

    try {
      await action();
    } catch (_) {
      if (mounted) {
        _showMessage(failureMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          activeAction = null;
          exportProgress = 0;
          exportTotal = 0;
        });
      }
    }
  }

  void _updateProgress(int completed, int total) {
    if (!mounted) {
      return;
    }

    setState(() {
      exportProgress = completed;
      exportTotal = total;
    });
  }

  Rect? _sharePositionOrigin() {
    final renderObject = context.findRenderObject();

    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return null;
    }

    final origin = renderObject.localToGlobal(Offset.zero);
    return origin & renderObject.size;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ExportIntro extends StatelessWidget {
  final int qrReadyCount;
  final int withoutQrCount;

  const _ExportIntro({
    required this.qrReadyCount,
    required this.withoutQrCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: AppMetrics.borderWidth),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$qrReadyCount QR-ready ${qrReadyCount == 1 ? 'item' : 'items'}',
            style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'PNG export creates individual branded QR cards. '
            'PDF export arranges up to 12 cut-out tags per A4 page.',
            style: AppTextStyles.body,
          ),
          if (withoutQrCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$withoutQrCount ${withoutQrCount == 1 ? 'item does' : 'items do'} '
              'not have a QR yet and ${withoutQrCount == 1 ? 'is' : 'are'} not shown.',
              style: AppTextStyles.body.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _SelectionHeader extends StatelessWidget {
  final int selectedCount;
  final bool allSelected;
  final VoidCallback onToggleAll;

  const _SelectionHeader({
    required this.selectedCount,
    required this.allSelected,
    required this.onToggleAll,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text('$selectedCount selected', style: AppTextStyles.bodyBold),
        ),
        TextButton(
          onPressed: onToggleAll,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            minimumSize: const Size(88, AppMetrics.touchTarget),
          ),
          child: Text(
            allSelected ? 'Clear all' : 'Select all',
            style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _SelectableQrItemCard extends StatelessWidget {
  final Item item;
  final bool selected;
  final VoidCallback? onTap;

  const _SelectableQrItemCard({
    super.key,
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${selected ? 'Deselect' : 'Select'} ${item.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 70),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected ? AppColors.card : AppColors.background,
              border: Border.all(
                color: AppColors.ink,
                width: selected
                    ? AppMetrics.strongBorderWidth
                    : AppMetrics.borderWidth,
              ),
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              boxShadow: selected
                  ? const [
                      BoxShadow(color: AppColors.green, offset: Offset(4, 4)),
                    ]
                  : const [
                      BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.ink, width: 1.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.qr_code_2,
                    size: 25,
                    color: AppColors.ink,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.category} • Qty ${item.quantity}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(fontSize: 11),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.green : AppColors.background,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  alignment: Alignment.center,
                  child: selected
                      ? const Icon(
                          Icons.check,
                          size: 18,
                          color: AppColors.background,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ExportProcessingOverlay extends StatelessWidget {
  final String action;
  final int completed;
  final int total;

  const _ExportProcessingOverlay({
    required this.action,
    required this.completed,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final isPdf = action == 'pdf';
    final title = isPdf ? 'Preparing PDF tags' : 'Preparing PNG tags';
    final progressKnown = total > 0;
    final finishedRendering = progressKnown && completed >= total;
    final detail = finishedRendering
        ? (isPdf ? 'Finalizing PDF...' : 'Opening share options...')
        : progressKnown
        ? '$completed of $total tags prepared'
        : 'Starting export...';

    return Positioned.fill(
      key: const ValueKey('qr-export-processing-overlay'),
      child: Stack(
        children: [
          ModalBarrier(
            dismissible: false,
            color: AppColors.ink.withValues(alpha: .36),
          ),
          Center(
            child: Semantics(
              liveRegion: true,
              label: '$title. $detail',
              child: Container(
                width: 264,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(
                    color: AppColors.ink,
                    width: AppMetrics.strongBorderWidth,
                  ),
                  borderRadius: BorderRadius.circular(AppMetrics.radius),
                  boxShadow: const [
                    BoxShadow(color: AppColors.orange, offset: Offset(5, 5)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: AppColors.green,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      detail,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      finishedRendering
                          ? 'Still working. This can take a few seconds.'
                          : 'Please keep this screen open.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.pixelDark.copyWith(fontSize: 5.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExportActions extends StatelessWidget {
  final int selectedCount;
  final String? activeAction;
  final VoidCallback? onPngPressed;
  final VoidCallback? onPdfPressed;

  const _ExportActions({
    required this.selectedCount,
    required this.activeAction,
    required this.onPngPressed,
    required this.onPdfPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(
              color: AppColors.ink,
              width: AppMetrics.borderWidth,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              selectedCount == 0
                  ? 'Select QR-ready items to export.'
                  : '$selectedCount ${selectedCount == 1 ? 'item' : 'items'} ready to export.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body.copyWith(fontSize: 11),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(
                  child: _ExportButton(
                    icon: Icons.image_outlined,
                    label: 'Export PNG Cards',
                    busy: activeAction == 'png',
                    onPressed: activeAction == null ? onPngPressed : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ExportButton(
                    icon: Icons.picture_as_pdf_outlined,
                    label: 'Export PDF Sheet',
                    filled: true,
                    busy: activeAction == 'pdf',
                    onPressed: activeAction == null ? onPdfPressed : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onPressed;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.filled = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = filled ? AppColors.background : AppColors.ink;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          child: Container(
            constraints: const BoxConstraints(
              minHeight: AppMetrics.primaryButtonHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: enabled
                  ? (filled ? AppColors.ink : AppColors.background)
                  : AppColors.card,
              border: Border.all(
                color: AppColors.ink,
                width: AppMetrics.borderWidth,
              ),
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              boxShadow: enabled && filled
                  ? const [
                      BoxShadow(color: AppColors.orange, offset: Offset(3, 3)),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else
                  Icon(
                    icon,
                    size: 18,
                    color: enabled ? foreground : AppColors.muted,
                  ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    busy ? 'Working...' : label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: enabled ? foreground : AppColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NoQrItemsState extends StatelessWidget {
  final int withoutQrCount;

  const _NoQrItemsState({required this.withoutQrCount});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.qr_code_2, size: 54, color: AppColors.muted),
            const SizedBox(height: 14),
            Text(
              'No QR codes ready',
              style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              withoutQrCount == 0
                  ? 'Add items and generate QR codes first.'
                  : 'Generate a QR code for an item before exporting labels.',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
