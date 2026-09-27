import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const PixelDots(),
        Column(
          children: [
            const _StatusBar(),
            const _TopNav(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Greeting(),
                    _ActiveActivityCard(),
                    _QuickActions(),
                    _RecentLists(),
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

class PixelDots extends StatelessWidget {
  const PixelDots({super.key});

  static const positions = [
    Offset(26, 80),
    Offset(316, 110),
    Offset(40, 290),
    Offset(322, 270),
    Offset(28, 510),
    Offset(334, 490),
    Offset(60, 650),
    Offset(298, 670),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: positions.map((position) {
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

class _TopNav extends StatelessWidget {
  const _TopNav();

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
          Text('Lakwatsa', style: AppTextStyles.heading),
          const Spacer(),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.ink, width: 1.5),
            ),
            alignment: Alignment.center,
            child: Text('B', style: AppTextStyles.bodyBold),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Good morning!', style: AppTextStyles.heading),
          SizedBox(height: 8),
          Text('3 items still unpacked', style: AppTextStyles.pixel),
        ],
      ),
    );
  }
}

class _ActiveActivityCard extends StatelessWidget {
  const _ActiveActivityCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: PixelCard(
        color: AppColors.card,
        shadowColor: AppColors.ink,
        shadowOffset: const Offset(5, 5),
        height: 190,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
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
              SizedBox(height: 10),
              Text(
                'Beach Trip',
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              SizedBox(height: 5),
              Text('Departure in 2 days', style: AppTextStyles.body),
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Packing', style: AppTextStyles.pixelDark),
                  Text('13/18', style: AppTextStyles.pixelDark),
                ],
              ),
              SizedBox(height: 6),
              Container(
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  border: Border.all(color: AppColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(2),
                ),
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: 13 / 18,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.green,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  width: 120,
                  height: 32,
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
                    'Continue →',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.background,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: AppTextStyles.bodyBold),
          SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  title: 'My Items',
                  shadowColor: AppColors.orange,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: 'New List',
                  shadowColor: AppColors.green,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: _QuickAction(
                  title: 'Activities',
                  shadowColor: AppColors.ink,
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
  final Color shadowColor;

  const _QuickAction({required this.title, required this.shadowColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: shadowColor, offset: const Offset(4, 4))],
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _RecentLists extends StatelessWidget {
  const _RecentLists();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Lists', style: AppTextStyles.bodyBold),
              Text('See all', style: AppTextStyles.body),
            ],
          ),
          SizedBox(height: 12),
          _RecentListCard(
            title: 'Boracay 2025',
            count: '18 items',
            status: 'DONE',
            statusColor: AppColors.green,
          ),
          SizedBox(height: 10),
          _RecentListCard(
            title: 'School — Monday',
            count: '12 items',
            status: 'ACTIVE',
            statusColor: AppColors.orange,
          ),
        ],
      ),
    );
  }
}

class _RecentListCard extends StatelessWidget {
  final String title;
  final String count;
  final String status;
  final Color statusColor;

  const _RecentListCard({
    required this.title,
    required this.count,
    required this.status,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodyBold),
              SizedBox(height: 3),
              Text(count, style: AppTextStyles.body),
            ],
          ),
          const Spacer(),
          Container(
            width: 64,
            height: 20,
            decoration: BoxDecoration(
              color: statusColor,
              border: Border.all(color: AppColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(2),
            ),
            alignment: Alignment.center,
            child: Text(
              status,
              style: AppTextStyles.pixelWhite.copyWith(fontSize: 5),
            ),
          ),
        ],
      ),
    );
  }
}

class PixelCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color shadowColor;
  final Offset shadowOffset;
  final double height;

  const PixelCard({
    super.key,
    required this.child,
    required this.color,
    required this.shadowColor,
    required this.shadowOffset,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: AppColors.ink, width: 2.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: shadowColor, offset: shadowOffset)],
      ),
      child: child,
    );
  }
}
