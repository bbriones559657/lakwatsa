import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../models/item_category.dart';
import '../../repositories/firestore_item_category_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'add_item_screen.dart';
import 'manage_categories_screen.dart';

class MyItemsScreen extends StatefulWidget {
  const MyItemsScreen({super.key});

  @override
  State<MyItemsScreen> createState() => _MyItemsScreenState();
}

class _MyItemsScreenState extends State<MyItemsScreen> {
  final TextEditingController searchController = TextEditingController();

  FirestoreItemRepository? itemRepository;
  FirestoreItemCategoryRepository? categoryRepository;

  String selectedCategory = 'All';

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      itemRepository = FirestoreItemRepository(userId: user.uid);
      categoryRepository = FirestoreItemCategoryRepository(userId: user.uid);
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const _BackgroundDots(),
        Column(
          children: [
            const _StatusBar(),

            _Header(
              onAdd: _openAddItem,
              onCategories: _openCategories,
            ),

            Expanded(child: _buildContent()),
          ],
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (itemRepository == null || categoryRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<ItemCategory>>(
      stream: categoryRepository!.watchCustomCategories(),
      builder: (context, categorySnapshot) {
        // My Items remains usable even if the optional custom-category stream
        // is temporarily unavailable. Item snapshots still carry category names.
        final customCategories = categorySnapshot.data ?? [];
        final categoryLoadFailed = categorySnapshot.hasError;

        return StreamBuilder<List<Item>>(
          stream: itemRepository!.watchItems(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Failed to load items.\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.body,
                  ),
                ),
              );
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final allItems = snapshot.data ?? [];
            final categories = _categoryNames(customCategories, allItems);
            final activeCategory = categories.contains(selectedCategory)
                ? selectedCategory
                : 'All';
            final filteredItems = _filterItems(allItems, activeCategory);

            if (activeCategory != selectedCategory) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && selectedCategory != 'All') {
                  setState(() {
                    selectedCategory = 'All';
                  });
                }
              });
            }

            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _SearchBar(
                  controller: searchController,
                  onChanged: (_) {
                    setState(() {});
                  },
                ),

                _CategoryChips(
                  categories: categories,
                  selectedCategory: activeCategory,
                  onSelected: (category) {
                    setState(() {
                      selectedCategory = category;
                    });
                  },
                ),

                if (categoryLoadFailed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Text(
                      'Custom categories could not be refreshed. '
                      'Your Items are still available.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),

                if (allItems.isEmpty)
                  const _EmptyState(
                    title: 'No items yet',
                    message: 'Add your first item to My Items.',
                  )
                else if (filteredItems.isEmpty)
                  const _EmptyState(
                    title: 'No items found',
                    message: 'Try another search or category.',
                  )
                else
                  ..._buildSections(filteredItems, categories),
              ],
            );
          },
        );
      },
    );
  }

  List<String> _categoryNames(
    List<ItemCategory> customCategories,
    List<Item> items,
  ) {
    final names = <String>['All', ...ItemCategory.builtInNames];
    final customNames = customCategories
        .map((category) => category.name.trim())
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final legacyNames = items
        .map((item) => item.category.trim())
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final name in [...customNames, ...legacyNames]) {
      if (!_containsCategoryName(names, name)) {
        names.add(name);
      }
    }

    return names;
  }

  bool _containsCategoryName(List<String> names, String candidate) {
    final normalized = candidate.trim().toLowerCase();

    return names.any((name) => name.trim().toLowerCase() == normalized);
  }

  List<Item> _filterItems(List<Item> items, String activeCategory) {
    final search = searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesSearch =
          search.isEmpty || item.name.toLowerCase().contains(search);

      final matchesCategory = activeCategory == 'All' ||
          _sameCategoryName(item.category, activeCategory);

      return matchesSearch && matchesCategory;
    }).toList();
  }

  List<Widget> _buildSections(List<Item> items, List<String> categories) {
    final widgets = <Widget>[];

    for (final category in categories) {
      if (category == 'All') {
        continue;
      }

      final categoryItems = items
          .where((item) => _sameCategoryName(item.category, category))
          .toList();

      if (categoryItems.isEmpty) {
        continue;
      }

      widgets.add(_ItemSection(title: category, items: categoryItems));
    }

    return widgets;
  }

  bool _sameCategoryName(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  Future<void> _openAddItem() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddItemScreen()),
    );

    // No manual refresh needed.
    // Firestore StreamBuilder updates automatically.
  }

  Future<void> _openCategories() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageCategoriesScreen(),
      ),
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
  final VoidCallback onAdd;
  final VoidCallback onCategories;

  const _Header({
    required this.onAdd,
    required this.onCategories,
  });

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

          _HeaderButton(
            icon: Icons.category_outlined,
            label: 'Manage categories',
            filled: false,
            onTap: onCategories,
          ),

          const SizedBox(width: 10),

          _HeaderButton(
            text: '+',
            label: 'Add item',
            filled: true,
            onTap: onAdd,
          ),
        ],
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final String label;
  final bool filled;
  final VoidCallback onTap;

  const _HeaderButton({
    this.text,
    this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  }) : assert(text != null || icon != null);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: filled ? AppColors.ink : AppColors.background,
              border: Border.all(color: AppColors.ink, width: 2.5),
              borderRadius: BorderRadius.circular(4),
              boxShadow: filled
                  ? const [
                      BoxShadow(color: AppColors.green, offset: Offset(3, 3)),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: icon != null
                ? Icon(
                    icon,
                    color: filled ? AppColors.background : AppColors.ink,
                    size: 19,
                  )
                : Text(
                    text!,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: filled ? AppColors.background : AppColors.ink,
                      fontSize: text == '+' ? 20 : 14,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: AppTextStyles.body.copyWith(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search items...',
          hintStyle: AppTextStyles.body.copyWith(
            fontSize: 13,
            color: AppColors.muted,
          ),
          prefixIcon: const Icon(Icons.search, color: AppColors.ink, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.selectedCategory,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, _) {
          return const SizedBox(width: 8);
        },
        itemBuilder: (context, index) {
          final category = categories[index];

          return _CategoryChip(
            text: category,
            selected: selectedCategory == category,
            onTap: () {
              onSelected(category);
            },
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String text;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.text,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
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
      ),
    );
  }
}

class _ItemSection extends StatelessWidget {
  final String title;
  final List<Item> items;

  const _ItemSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
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

              Text(
                '${items.length} '
                '${items.length == 1 ? 'item' : 'items'}',
                style: AppTextStyles.body.copyWith(fontSize: 11),
              ),
            ],
          ),

          const SizedBox(height: 7),

          Container(height: 1, color: AppColors.ink),

          const SizedBox(height: 10),

          ...items.map((item) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ItemCard(
                item: item,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        return AddItemScreen(item: item);
                      },
                    ),
                  );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final VoidCallback onTap;

  const _ItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 76,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 10),

            Container(
              width: 4,
              height: 64,
              decoration: BoxDecoration(
                color: item.hasQr ? AppColors.orange : AppColors.muted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            const SizedBox(width: 10),

            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.card,
                border: Border.all(color: AppColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.center,
              child: Icon(
                _getItemIcon(item.icon),
                color: AppColors.ink,
                size: 23,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
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
                    style: AppTextStyles.body.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),

            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: item.hasQr ? AppColors.green : AppColors.card,
                border: Border.all(color: AppColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                item.hasQr ? 'QR' : 'NO QR',
                style: AppTextStyles.pixelDark.copyWith(
                  color: item.hasQr ? AppColors.background : AppColors.ink,
                  fontSize: 5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 100, left: 30, right: 30),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: AppColors.muted,
          ),

          const SizedBox(height: 14),

          Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),

          const SizedBox(height: 5),

          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
        ],
      ),
    );
  }
}
