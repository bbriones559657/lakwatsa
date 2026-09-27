import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'list_details_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  bool editMode = false;

  final List<_ItemListData> lists = [
    _ItemListData(name: 'Beach Trip', itemCount: 18, icon: Icons.beach_access),
    _ItemListData(
      name: 'School — Monday',
      itemCount: 12,
      icon: Icons.school_outlined,
    ),
    _ItemListData(name: 'Gym', itemCount: 8, icon: Icons.fitness_center),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              editMode: editMode,
              onEdit: () {
                setState(() {
                  editMode = !editMode;
                });
              },
              onAdd: () {
                _showCreateListDialog();
              },
            ),
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  const _SearchBar(),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _ListGrid(
                      lists: lists,
                      editMode: editMode,
                      onDelete: (index) {
                        _deleteList(index);
                      },
                      onTap: (index) {
                        if (!editMode) {
                          _openList(lists[index]);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateListDialog() {
    final controller = TextEditingController();

    IconData selectedIcon = Icons.list_alt_outlined;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppColors.ink, width: 2),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New List',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'List Name',
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: controller,
                        style: AppTextStyles.bodyBold,
                        decoration: InputDecoration(
                          hintText: 'Enter list name',
                          hintStyle: AppTextStyles.body,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.ink,
                              width: 2,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.ink,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Icon',
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final icon = await _showIconLibrary(
                            context,
                            selectedIcon,
                          );

                          if (icon != null) {
                            setDialogState(() {
                              selectedIcon = icon;
                            });
                          }
                        },
                        child: Container(
                          height: 62,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.ink, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.card,
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: 1.5,
                                  ),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  selectedIcon,
                                  color: AppColors.ink,
                                  size: 23,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Choose an icon',
                                  style: AppTextStyles.bodyBold,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.ink,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            child: Text(
                              'Cancel',
                              style: AppTextStyles.bodyBold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.ink,
                              foregroundColor: AppColors.background,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            onPressed: () {
                              final name = controller.text.trim();

                              if (name.isEmpty) {
                                return;
                              }

                              setState(() {
                                lists.add(
                                  _ItemListData(
                                    name: name,
                                    itemCount: 0,
                                    icon: selectedIcon,
                                  ),
                                );
                              });

                              Navigator.pop(dialogContext);
                            },
                            child: const Text('Create'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  Future<IconData?> _showIconLibrary(
    BuildContext context,
    IconData selectedIcon,
  ) {
    final categories = <_IconCategory>[
      _IconCategory(
        name: 'Travel',
        icons: [
          Icons.beach_access,
          Icons.flight,
          Icons.luggage_outlined,
          Icons.directions_car_outlined,
          Icons.directions_boat_outlined,
          Icons.map_outlined,
          Icons.hotel_outlined,
          Icons.explore_outlined,
        ],
      ),
      _IconCategory(
        name: 'School',
        icons: [
          Icons.school_outlined,
          Icons.menu_book_outlined,
          Icons.book_outlined,
          Icons.edit_note_outlined,
          Icons.backpack_outlined,
          Icons.science_outlined,
          Icons.calculate_outlined,
          Icons.computer_outlined,
        ],
      ),
      _IconCategory(
        name: 'Work',
        icons: [
          Icons.work_outline,
          Icons.business_center_outlined,
          Icons.folder_outlined,
          Icons.laptop_mac_outlined,
          Icons.desktop_windows_outlined,
          Icons.calendar_month_outlined,
          Icons.assignment_outlined,
          Icons.badge_outlined,
        ],
      ),
      _IconCategory(
        name: 'Fitness',
        icons: [
          Icons.fitness_center,
          Icons.directions_run,
          Icons.directions_bike,
          Icons.sports_soccer_outlined,
          Icons.sports_basketball_outlined,
          Icons.sports_tennis_outlined,
          Icons.pool_outlined,
          Icons.sports_outlined,
        ],
      ),
      _IconCategory(
        name: 'Daily',
        icons: [
          Icons.home_outlined,
          Icons.shopping_bag_outlined,
          Icons.shopping_cart_outlined,
          Icons.restaurant_outlined,
          Icons.local_cafe_outlined,
          Icons.local_grocery_store_outlined,
          Icons.cleaning_services_outlined,
          Icons.pets_outlined,
        ],
      ),
      _IconCategory(
        name: 'Other',
        icons: [
          Icons.list_alt_outlined,
          Icons.star_outline,
          Icons.favorite_border,
          Icons.event_outlined,
          Icons.card_giftcard_outlined,
          Icons.camera_alt_outlined,
          Icons.music_note_outlined,
          Icons.more_horiz,
        ],
      ),
    ];

    return showModalBottomSheet<IconData>(
      context: context,
      backgroundColor: AppColors.background,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.75,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'Choose an Icon',
                        style: AppTextStyles.heading.copyWith(fontSize: 20),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(sheetContext);
                        },
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.ink, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.close,
                            color: AppColors.ink,
                            size: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.search,
                          color: AppColors.ink,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text('Search icons...', style: AppTextStyles.body),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: categories.length,
                    itemBuilder: (context, categoryIndex) {
                      final category = categories[categoryIndex];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category.name,
                              style: AppTextStyles.bodyBold.copyWith(
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 8),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: category.icons.length,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 6,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: 1,
                                  ),
                              itemBuilder: (context, iconIndex) {
                                final icon = category.icons[iconIndex];
                                final isSelected = icon == selectedIcon;

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.pop(sheetContext, icon);
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? AppColors.ink
                                          : AppColors.card,
                                      border: Border.all(
                                        color: AppColors.ink,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(
                                      icon,
                                      color: isSelected
                                          ? AppColors.background
                                          : AppColors.ink,
                                      size: 23,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _deleteList(int index) {
    final listName = lists[index].name;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          title: Text(
            'Delete List?',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: Text(
            'Delete "$listName"? The items inside it will not be deleted.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel', style: AppTextStyles.bodyBold),
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
                setState(() {
                  lists.removeAt(index);
                });

                Navigator.pop(context);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _openList(_ItemListData list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ListDetailsScreen(listName: list.name, itemCount: list.itemCount),
      ),
    );
  }
}

class _ItemListData {
  final String name;
  final int itemCount;
  final IconData icon;

  const _ItemListData({
    required this.name,
    required this.itemCount,
    required this.icon,
  });
}

class _IconCategory {
  final String name;
  final List<IconData> icons;

  const _IconCategory({required this.name, required this.icons});
}

class _Header extends StatelessWidget {
  final bool editMode;
  final VoidCallback onEdit;
  final VoidCallback onAdd;

  const _Header({
    required this.editMode,
    required this.onEdit,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          Text('Lists', style: AppTextStyles.heading.copyWith(fontSize: 24)),
          const Spacer(),
          GestureDetector(
            onTap: onEdit,
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: editMode ? AppColors.ink : AppColors.background,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                editMode ? 'Save' : 'Edit',
                style: AppTextStyles.bodyBold.copyWith(
                  color: editMode ? AppColors.background : AppColors.ink,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 42,
              height: 42,
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
                '+',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.background,
                  fontSize: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
          ],
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.ink, size: 20),
            const SizedBox(width: 10),
            Text('Search lists...', style: AppTextStyles.body),
          ],
        ),
      ),
    );
  }
}

class _ListGrid extends StatelessWidget {
  final List<_ItemListData> lists;
  final bool editMode;
  final Function(int) onDelete;
  final Function(int) onTap;

  const _ListGrid({
    required this.lists,
    required this.editMode,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return Center(child: Text('No lists yet', style: AppTextStyles.body));
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        return _ListCard(
          list: lists[index],
          editMode: editMode,
          onDelete: () {
            onDelete(index);
          },
          onTap: () {
            onTap(index);
          },
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  final _ItemListData list;
  final bool editMode;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ListCard({
    required this.list,
    required this.editMode,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.ink, width: 2),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Icon(list.icon, color: AppColors.ink, size: 27),
                ),
                const Spacer(),
                Text(
                  list.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text('${list.itemCount} items', style: AppTextStyles.body),
              ],
            ),
          ),
          if (editMode)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.ink,
                    border: Border.all(color: AppColors.ink, width: 2),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '×',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: AppColors.background,
                      fontSize: 18,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
