import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'items/my_items_screen.dart';
import 'lists/lists_screen.dart';
import 'activities/activities_screen.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int currentIndex = 0;

  final pages = const [
    HomeScreen(),
    MyItemsScreen(),
    ListsScreen(),
    ActivitiesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[currentIndex]),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: currentIndex,
        onChanged: (index) {
          setState(() {
            currentIndex = index;
          });
        },
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onChanged;

  const _BottomNavigation({
    required this.currentIndex,
    required this.onChanged,
  });

  static const labels = ['Home', 'Items', 'Lists', 'Activities'];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: List.generate(labels.length, (index) {
          final selected = currentIndex == index;

          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    labels[index],
                    style: selected
                        ? AppTextStyles.navSelected
                        : AppTextStyles.nav,
                  ),
                  const SizedBox(height: 7),
                  if (selected)
                    const SizedBox(
                      width: 4,
                      height: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: AppColors.ink),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
