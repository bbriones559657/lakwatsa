import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                Semantics(
                  label: 'Profile',
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.ink,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text('B', style: AppTextStyles.bodyBold),
                  ),
                ),
              ],
            ),
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
      child: LakwatsaPixelCard(
        color: AppColors.card,
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
