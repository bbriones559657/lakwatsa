import 'package:flutter/material.dart';

import '../../models/item_list.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';
import 'list_details_screen.dart';

class ListsScreen extends StatefulWidget {
  const ListsScreen({super.key});

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  bool editMode = false;

  final TextEditingController searchController = TextEditingController();

  FirestoreListRepository? listRepository;

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      listRepository = FirestoreListRepository(userId: user.uid);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const LakwatsaBackgroundDots(),
            Column(
              children: [
                LakwatsaTopBar(
                  title: 'Lists',
                  actions: [
                    LakwatsaHeaderAction(
                      text: editMode ? 'Save' : 'Edit',
                      label: editMode ? 'Save list changes' : 'Edit lists',
                      filled: editMode,
                      onPressed: () {
                        setState(() {
                          editMode = !editMode;
                        });
                      },
                    ),
                    LakwatsaHeaderAction(
                      text: '+',
                      label: 'Create list',
                      filled: true,
                      onPressed: _showCreateListDialog,
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      LakwatsaSearchField(
                        controller: searchController,
                        hintText: 'Search lists...',
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildLists()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLists() {
    if (listRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<ItemList>>(
      stream: listRepository!.watchLists(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load lists.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lists = snapshot.data ?? [];

        final searchText = searchController.text.trim().toLowerCase();

        final filteredLists = lists.where((list) {
          if (searchText.isEmpty) {
            return true;
          }

          return list.name.toLowerCase().contains(searchText);
        }).toList();

        if (lists.isEmpty) {
          return const _EmptyState(
            title: 'No lists yet',
            message: 'Create your first reusable item list.',
          );
        }

        if (filteredLists.isEmpty) {
          return const _EmptyState(
            title: 'No lists found',
            message: 'Try a different search.',
          );
        }

        return _ListGrid(
          lists: filteredLists,
          repository: listRepository!,
          editMode: editMode,
          onDelete: _deleteList,
          onTap: (list) {
            if (!editMode) {
              _openList(list);
            }
          },
        );
      },
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
                            onPressed: () async {
                              final name = controller.text.trim();

                              if (name.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter a list name.'),
                                  ),
                                );
                                return;
                              }

                              if (listRepository == null) {
                                return;
                              }

                              try {
                                final list = ItemList(
                                  id: '',
                                  name: name,
                                  icon: _iconToKey(selectedIcon),
                                );

                                await listRepository!.addList(list);

                                if (!mounted ||
                                    !context.mounted ||
                                    !dialogContext.mounted) {
                                  return;
                                }

                                Navigator.pop(dialogContext);

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('List created successfully.'),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted || !context.mounted) {
                                  return;
                                }

                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to create list: $error',
                                    ),
                                  ),
                                );
                              }
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

  Future<void> _deleteList(ItemList list) async {
    if (listRepository == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
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
            'Delete "${list.name}"? '
            'The items inside it will not be deleted.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
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
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await listRepository!.deleteList(list.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('List deleted.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete list: $error')));
    }
  }

  void _openList(ItemList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ListDetailsScreen(listId: list.id, listName: list.name);
        },
      ),
    );
  }
}

class _IconCategory {
  final String name;
  final List<IconData> icons;

  const _IconCategory({required this.name, required this.icons});
}


class _ListGrid extends StatelessWidget {
  final List<ItemList> lists;
  final FirestoreListRepository repository;
  final bool editMode;
  final ValueChanged<ItemList> onDelete;
  final ValueChanged<ItemList> onTap;

  const _ListGrid({
    required this.lists,
    required this.repository,
    required this.editMode,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
        final list = lists[index];

        return _ListCard(
          list: list,
          repository: repository,
          editMode: editMode,
          onDelete: () {
            onDelete(list);
          },
          onTap: () {
            onTap(list);
          },
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  final ItemList list;
  final FirestoreListRepository repository;
  final bool editMode;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ListCard({
    required this.list,
    required this.repository,
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
                  child: Icon(
                    _getListIcon(list.icon),
                    color: AppColors.ink,
                    size: 27,
                  ),
                ),

                const Spacer(),

                Text(
                  list.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                ),

                const SizedBox(height: 4),

                StreamBuilder<List<String>>(
                  stream: repository.watchListItemIds(list.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;

                    return Text(
                      '$count '
                      '${count == 1 ? 'item' : 'items'}',
                      style: AppTextStyles.body,
                    );
                  },
                ),
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

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.list_alt_outlined,
              color: AppColors.muted,
              size: 48,
            ),

            const SizedBox(height: 14),

            Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),

            const SizedBox(height: 5),

            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}

const Map<String, IconData> _listIconMap = {
  // Travel
  'beach': Icons.beach_access,
  'flight': Icons.flight,
  'luggage': Icons.luggage_outlined,
  'car': Icons.directions_car_outlined,
  'boat': Icons.directions_boat_outlined,
  'map': Icons.map_outlined,
  'hotel': Icons.hotel_outlined,
  'explore': Icons.explore_outlined,

  // School
  'school': Icons.school_outlined,
  'book': Icons.menu_book_outlined,
  'book_alt': Icons.book_outlined,
  'notes': Icons.edit_note_outlined,
  'backpack': Icons.backpack_outlined,
  'science': Icons.science_outlined,
  'calculator': Icons.calculate_outlined,
  'computer': Icons.computer_outlined,

  // Work
  'work': Icons.work_outline,
  'briefcase': Icons.business_center_outlined,
  'folder': Icons.folder_outlined,
  'laptop': Icons.laptop_mac_outlined,
  'desktop': Icons.desktop_windows_outlined,
  'calendar': Icons.calendar_month_outlined,
  'assignment': Icons.assignment_outlined,
  'badge': Icons.badge_outlined,

  // Fitness
  'fitness': Icons.fitness_center,
  'running': Icons.directions_run,
  'bike': Icons.directions_bike,
  'soccer': Icons.sports_soccer_outlined,
  'basketball': Icons.sports_basketball_outlined,
  'tennis': Icons.sports_tennis_outlined,
  'swimming': Icons.pool_outlined,
  'sports': Icons.sports_outlined,

  // Daily
  'home': Icons.home_outlined,
  'shopping_bag': Icons.shopping_bag_outlined,
  'cart': Icons.shopping_cart_outlined,
  'food': Icons.restaurant_outlined,
  'coffee': Icons.local_cafe_outlined,
  'grocery': Icons.local_grocery_store_outlined,
  'cleaning': Icons.cleaning_services_outlined,
  'pets': Icons.pets_outlined,

  // Other
  'list': Icons.list_alt_outlined,
  'star': Icons.star_outline,
  'heart': Icons.favorite_border,
  'event': Icons.event_outlined,
  'gift': Icons.card_giftcard_outlined,
  'camera': Icons.camera_alt_outlined,
  'music': Icons.music_note_outlined,
  'more': Icons.more_horiz,
};

String _iconToKey(IconData icon) {
  for (final entry in _listIconMap.entries) {
    if (entry.value == icon) {
      return entry.key;
    }
  }

  return 'list';
}

IconData _getListIcon(String key) {
  return _listIconMap[key] ?? Icons.list_alt_outlined;
}
