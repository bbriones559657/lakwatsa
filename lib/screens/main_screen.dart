import 'package:flutter/material.dart';

import '../models/activity.dart' as model;
import '../models/item_list.dart';
import 'activities/activities_screen.dart';
import 'activities/activity_return_check_screen.dart';
import 'home/home_screen.dart';
import 'items/my_items_screen.dart';
import 'lists/list_details_screen.dart';
import 'lists/lists_screen.dart';
import '../theme/app_theme.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  static const _tabCount = 4;

  int currentIndex = 0;
  late final List<Widget?> pages;

  @override
  void initState() {
    super.initState();
    pages = List<Widget?>.filled(_tabCount, null);
    pages[0] = _createPage(0);
  }

  Widget _createPage(int index) {
    return switch (index) {
      0 => HomeScreen(
          onOpenItems: () => _selectTab(1),
          onCreateList: _openCreateList,
          onOpenLists: () => _selectTab(2),
          onOpenActivities: () => _selectTab(3),
          onContinueActivity: _openActiveReturnCheck,
          onOpenList: _openList,
        ),
      1 => const MyItemsScreen(),
      2 => const ListsScreen(),
      3 => const ActivitiesScreen(),
      _ => throw RangeError.index(index, pages, 'index'),
    };
  }

  void _selectTab(int index) {
    if (index == currentIndex) {
      return;
    }

    setState(() {
      currentIndex = index;
      pages[index] ??= _createPage(index);
    });
  }

  void _openCreateList() {
    setState(() {
      pages[2] = const ListsScreen(openCreateOnStart: true);
      currentIndex = 2;
    });
  }

  void _openActiveReturnCheck(model.Activity activity) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ActivityReturnCheckScreen(activity: activity),
      ),
    );
  }

  void _openList(ItemList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListDetailsScreen(
          listId: list.id,
          listName: list.name,
          listIcon: list.icon,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: currentIndex,
          children: List.generate(
            _tabCount,
            (index) => pages[index] ?? const SizedBox.shrink(),
          ),
        ),
      ),
      bottomNavigationBar: _BottomNavigation(
        currentIndex: currentIndex,
        onChanged: _selectTab,
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
    return SafeArea(
      top: false,
      child: Container(
        height: AppMetrics.bottomNavHeight,
        decoration: const BoxDecoration(
          color: AppColors.background,
          border: Border(
            top: BorderSide(
              color: AppColors.ink,
              width: AppMetrics.borderWidth,
            ),
          ),
        ),
        child: Row(
          children: List.generate(labels.length, (index) {
            final selected = currentIndex == index;
            final label = labels[index];

            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: '$label tab',
                excludeSemantics: true,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          label,
                          style: selected
                              ? AppTextStyles.navSelected
                              : AppTextStyles.nav,
                        ),
                        const SizedBox(height: 7),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: selected
                                ? AppColors.ink
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
