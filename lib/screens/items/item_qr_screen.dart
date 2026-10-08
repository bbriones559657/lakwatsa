import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../services/item_qr_export_service.dart';
import '../../theme/app_theme.dart';

class ItemQrScreen extends StatefulWidget {
  final Item item;

  const ItemQrScreen({super.key, required this.item});

  @override
  State<ItemQrScreen> createState() => _ItemQrScreenState();
}

class _ItemQrScreenState extends State<ItemQrScreen> {
  FirestoreItemRepository? itemRepository;

  late Item currentItem;

  bool isGenerating = false;
  String? activeFileAction;

  final ItemQrExportService qrExportService = const ItemQrExportService();

  @override
  void initState() {
    super.initState();

    currentItem = widget.item;

    final user = AuthService().currentUser;

    if (user != null) {
      itemRepository = FirestoreItemRepository(userId: user.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: activeFileAction == null,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          automaticallyImplyLeading: activeFileAction == null,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.ink,
          elevation: 0,
          title: Text(
            'Item QR Code',
            style: AppTextStyles.heading.copyWith(fontSize: 21),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(2),
            child: Container(height: 2, color: AppColors.ink),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
            children: [
              _ItemInfo(item: currentItem),

              const SizedBox(height: 30),

              if (currentItem.hasQr) _buildQrCode() else _buildNoQr(),

              const SizedBox(height: 24),

              if (currentItem.hasQr) _QrReminder(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQrCode() {
    return Column(
      children: [
        Text(
          'Scan this QR code to identify this item.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),

        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
            ],
          ),
          child: QrImageView(
            data: currentItem.qrCode!,
            version: QrVersions.auto,
            size: 230,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Colors.black,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 20),

        _buildQrFileActions(),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('QR assigned', style: AppTextStyles.bodyBold),
              const SizedBox(height: 4),
              Text(
                'This QR code belongs to ${currentItem.name}.',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQrFileActions() {
    final isBusy = activeFileAction != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _QrFileActionButton(
                icon: Icons.download_outlined,
                label: 'Save PNG',
                busy: activeFileAction == 'save',
                onPressed: isBusy ? null : _saveQrImage,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _QrFileActionButton(
                icon: Icons.share_outlined,
                label: 'Share',
                busy: activeFileAction == 'share',
                onPressed: isBusy ? null : _shareQrImage,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _QrFileActionButton(
          icon: Icons.picture_as_pdf_outlined,
          label: 'Export Print-Ready PDF',
          filled: true,
          busy: activeFileAction == 'pdf',
          onPressed: isBusy ? null : _exportQrPdf,
        ),
      ],
    );
  }

  Widget _buildNoQr() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          const Icon(Icons.qr_code_2, size: 64, color: AppColors.muted),

          const SizedBox(height: 14),

          Text(
            'No QR Code',
            style: AppTextStyles.bodyBold.copyWith(fontSize: 17),
          ),

          const SizedBox(height: 6),

          Text(
            'Generate a QR code if you want to identify this item using the scanner.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: isGenerating ? null : _generateQrCode,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: isGenerating ? AppColors.muted : AppColors.ink,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isGenerating
                    ? null
                    : const [
                        BoxShadow(color: AppColors.green, offset: Offset(3, 3)),
                      ],
              ),
              alignment: Alignment.center,
              child: Text(
                isGenerating ? 'Generating...' : 'Generate QR Code',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.background,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveQrImage() async {
    await _runFileAction(
      key: 'save',
      failureMessage: 'Could not save the QR image. Please try again.',
      action: () async {
        final saved = await qrExportService.saveQrPng(currentItem);

        if (saved && mounted) {
          _showMessage('QR image saved.');
        }
      },
    );
  }

  Future<void> _shareQrImage() async {
    await _runFileAction(
      key: 'share',
      failureMessage: 'Could not open sharing. Please try again.',
      action: () {
        return qrExportService.shareQrPng(
          currentItem,
          sharePositionOrigin: _sharePositionOrigin(),
        );
      },
    );
  }

  Future<void> _exportQrPdf() async {
    await _runFileAction(
      key: 'pdf',
      failureMessage: 'Could not export the QR label. Please try again.',
      action: () async {
        final saved = await qrExportService.exportQrPdf(currentItem);

        if (saved && mounted) {
          _showMessage('Print-ready QR PDF exported.');
        }
      },
    );
  }

  Future<void> _runFileAction({
    required String key,
    required String failureMessage,
    required Future<void> Function() action,
  }) async {
    if (activeFileAction != null || !currentItem.hasQr) {
      return;
    }

    setState(() {
      activeFileAction = key;
    });

    try {
      await action();
    } catch (_) {
      if (mounted) {
        _showMessage(failureMessage);
      }
    } finally {
      if (mounted) {
        setState(() {
          activeFileAction = null;
        });
      }
    }
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

  Future<void> _generateQrCode() async {
    if (itemRepository == null) {
      return;
    }

    if (currentItem.hasQr) {
      return;
    }

    setState(() {
      isGenerating = true;
    });

    try {
      final qrCode = 'lakwatsa:item:${const Uuid().v4()}';

      final updatedItem = currentItem.copyWith(qrCode: qrCode);

      await itemRepository!.updateItem(updatedItem);

      if (!mounted) {
        return;
      }

      setState(() {
        currentItem = updatedItem;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR code generated successfully.')),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to generate QR code: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }
}

class _QrFileActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool busy;
  final VoidCallback? onPressed;

  const _QrFileActionButton({
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
    final background = filled ? AppColors.ink : AppColors.background;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              minHeight: AppMetrics.primaryButtonHeight,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: enabled ? background : AppColors.card,
              border: Border.all(color: AppColors.ink, width: 2),
              borderRadius: BorderRadius.circular(4),
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
                    size: 19,
                    color: enabled ? foreground : AppColors.muted,
                  ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    busy ? 'Working...' : label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: enabled ? foreground : AppColors.muted,
                      fontSize: 12,
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

class _ItemInfo extends StatelessWidget {
  final Item item;

  const _ItemInfo({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Icon(_getItemIcon(item.icon), color: AppColors.ink, size: 30),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppTextStyles.bodyBold.copyWith(fontSize: 18),
              ),

              const SizedBox(height: 4),

              Text(
                '${item.category} • Qty ${item.quantity}',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QrReminder extends StatelessWidget {
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
              'Save a PNG, share the QR, or export a print-ready PDF. '
              'Attach the same QR to the physical item so it stays linked.',
              style: AppTextStyles.body,
            ),
          ),
        ],
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
