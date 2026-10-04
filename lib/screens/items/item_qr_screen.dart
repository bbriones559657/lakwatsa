import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ItemQrScreen extends StatefulWidget {
  final Item item;

  const ItemQrScreen({
    super.key,
    required this.item,
  });

  @override
  State<ItemQrScreen> createState() => _ItemQrScreenState();
}

class _ItemQrScreenState extends State<ItemQrScreen> {
  FirestoreItemRepository? itemRepository;

  late Item currentItem;

  bool isGenerating = false;

  @override
  void initState() {
    super.initState();

    currentItem = widget.item;

    final user = AuthService().currentUser;

    if (user != null) {
      itemRepository = FirestoreItemRepository(
        userId: user.uid,
      );
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
          'Item QR Code',
          style: AppTextStyles.heading.copyWith(
            fontSize: 21,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(
            height: 2,
            color: AppColors.ink,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            24,
            28,
            24,
            30,
          ),
          children: [
            _ItemInfo(
              item: currentItem,
            ),

            const SizedBox(height: 30),

            if (currentItem.hasQr)
              _buildQrCode()
            else
              _buildNoQr(),

            const SizedBox(height: 24),

            if (currentItem.hasQr)
              _QrReminder(),
          ],
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
            border: Border.all(
              color: AppColors.ink,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: AppColors.ink,
                offset: Offset(4, 4),
              ),
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
            dataModuleStyle:
                const QrDataModuleStyle(
              dataModuleShape:
                  QrDataModuleShape.square,
              color: Colors.black,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.ink,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QR assigned',
                style: AppTextStyles.bodyBold,
              ),
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

  Widget _buildNoQr() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: AppColors.ink,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.qr_code_2,
            size: 64,
            color: AppColors.muted,
          ),

          const SizedBox(height: 14),

          Text(
            'No QR Code',
            style: AppTextStyles.bodyBold.copyWith(
              fontSize: 17,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Generate a QR code if you want to identify this item using the scanner.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: isGenerating
                ? null
                : _generateQrCode,
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                color: isGenerating
                    ? AppColors.muted
                    : AppColors.ink,
                border: Border.all(
                  color: AppColors.ink,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(4),
                boxShadow: isGenerating
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
                isGenerating
                    ? 'Generating...'
                    : 'Generate QR Code',
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
      final qrCode =
          'lakwatsa:item:${const Uuid().v4()}';

      final updatedItem = currentItem.copyWith(
        qrCode: qrCode,
      );

      await itemRepository!.updateItem(
        updatedItem,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        currentItem = updatedItem;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'QR code generated successfully.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to generate QR code: $error',
          ),
        ),
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

class _ItemInfo extends StatelessWidget {
  final Item item;

  const _ItemInfo({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.ink,
              width: 2,
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Icon(
            _getItemIcon(item.icon),
            color: AppColors.ink,
            size: 30,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: AppTextStyles.bodyBold.copyWith(
                  fontSize: 18,
                ),
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
        border: Border.all(
          color: AppColors.ink,
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.ink,
            size: 20,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Print or save this QR code and attach it to the physical item. '
              'The same QR should continue to be used for this item.',
              style: AppTextStyles.body,
            ),
          ),
        ],
      ),
    );
  }
}

IconData _getItemIcon(
  String icon,
) {
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