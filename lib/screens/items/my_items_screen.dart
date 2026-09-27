import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'add_item_screen.dart';

class MyItemsScreen extends StatelessWidget {
  const MyItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _BackgroundDots(),
        Column(
          children: [
            const _StatusBar(),
            const _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _SearchBar(),
                    _CategoryChips(),
                    _ElectronicsSection(),
                    _DocumentsSection(),
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

class _BackgroundDots extends StatelessWidget {
  const _BackgroundDots();

  static const dots = [
    Offset(30, 95),
    Offset(325, 130),
    Offset(35, 310),
    Offset(328, 290),
    Offset(32, 530),
    Offset(330, 510),
    Offset(65, 670),
    Offset(295, 680),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: dots.map((position) {
          return Positioned(
            left: position.dx,
            top: position.dy,
            child: Container(
              width: 4,
              height: 4,
              color: AppColors.ink.withValues(alpha: .05),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      color: AppColors.ink,
      padding: const EdgeInsets.only(left: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        '9:41',
        style: AppTextStyles.pixelWhite.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          Text('My Items', style: AppTextStyles.heading),
          const Spacer(),
          _HeaderButton(text: 'Q', filled: false, onTap: () {}),
          const SizedBox(width: 10),
          _HeaderButton(
            text: '+',
            filled: true,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddItemScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String text;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderButton({
    required this.text,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: filled
              ? const [BoxShadow(color: AppColors.green, offset: Offset(3, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.bodyBold.copyWith(
            color: filled ? AppColors.background : AppColors.ink,
            fontSize: text == '+' ? 20 : 14,
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Search items...',
        style: AppTextStyles.body.copyWith(fontSize: 13),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(left: 20),
        child: Row(
          children: const [
            _CategoryChip(text: 'All', selected: true, width: 44),
            SizedBox(width: 8),
            _CategoryChip(text: 'Electronics', width: 108),
            SizedBox(width: 8),
            _CategoryChip(text: 'Documents', width: 92),
            SizedBox(width: 8),
            _CategoryChip(text: 'Clothing', width: 84),
            SizedBox(width: 8),
            _CategoryChip(text: 'Toiletries', width: 100),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;
  final bool selected;
  final double width;

  const _CategoryChip({
    required this.text,
    this.selected = false,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 28,
      decoration: BoxDecoration(
        color: selected ? AppColors.ink : AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: AppTextStyles.bodyBold.copyWith(
          fontSize: 11,
          color: selected ? AppColors.background : AppColors.ink,
        ),
      ),
    );
  }
}

class _ElectronicsSection extends StatelessWidget {
  const _ElectronicsSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: _ItemSection(
        title: 'Electronics',
        count: '2 items',
        items: [
          _ItemData(
            name: 'MacBook Pro',
            category: 'Electronics',
            hasQr: true,
            qrColor: AppColors.green,
            stripeColor: AppColors.orange,
          ),
          _ItemData(
            name: 'USB-C Charger',
            category: 'Electronics',
            hasQr: true,
            qrColor: AppColors.card,
            stripeColor: AppColors.orange,
          ),
        ],
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 16),
      child: _ItemSection(
        title: 'Documents',
        count: '2 items',
        items: [
          _ItemData(
            name: 'Passport',
            category: 'Documents',
            hasQr: true,
            qrColor: AppColors.card,
            stripeColor: AppColors.orange,
            statusColor: Color(0xFFC44A4A),
          ),
          _ItemData(
            name: 'National ID',
            category: 'Documents',
            hasQr: false,
            qrColor: AppColors.card,
            stripeColor: AppColors.muted,
          ),
        ],
      ),
    );
  }
}

class _ItemSection extends StatelessWidget {
  final String title;
  final String count;
  final List<_ItemData> items;

  const _ItemSection({
    required this.title,
    required this.count,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: AppTextStyles.pixelDark.copyWith(
                  color: AppColors.ink,
                  fontSize: 7,
                ),
              ),
              const Spacer(),
              Text(count, style: AppTextStyles.body.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 7),
          Container(height: 1, color: AppColors.ink),
          const SizedBox(height: 10),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemCard(item: item),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemData {
  final String name;
  final String category;
  final bool hasQr;
  final Color qrColor;
  final Color stripeColor;
  final Color? statusColor;

  const _ItemData({
    required this.name,
    required this.category,
    required this.hasQr,
    required this.qrColor,
    required this.stripeColor,
    this.statusColor,
  });
}

class _ItemCard extends StatelessWidget {
  final _ItemData item;

  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 10,
            top: 4,
            child: Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: item.stripeColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            left: 22,
            top: 11,
            child: Text(item.name, style: AppTextStyles.bodyBold),
          ),
          Positioned(
            left: 22,
            top: 31,
            child: Text(
              item.category,
              style: AppTextStyles.body.copyWith(fontSize: 11),
            ),
          ),
          Positioned(
            right: 16,
            top: 11,
            child: Container(
              width: 38,
              height: 20,
              decoration: BoxDecoration(
                color: item.hasQr ? AppColors.green : AppColors.card,
                border: Border.all(color: AppColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: Text(
                item.hasQr ? 'QR' : 'NO QR',
                style: AppTextStyles.pixelDark.copyWith(
                  color: item.hasQr ? AppColors.background : AppColors.ink,
                  fontSize: 5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
