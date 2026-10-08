import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../models/item_category.dart';
import '../../repositories/firestore_item_category_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';
import 'add_item_screen.dart';
import 'bulk_qr_export_screen.dart';
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
        const LakwatsaBackgroundDots(),
        Column(
          children: [
            LakwatsaTopBar(
              title: 'My Items',
              actions: [
                LakwatsaHeaderAction(
                  icon: Icons.qr_code_2,
                  label: 'Export QR labels',
                  onPressed: _openBulkQrExport,
                ),
                LakwatsaHeaderAction(
                  icon: Icons.category_outlined,
                  label: 'Manage categories',
                  onPressed: _openCategories,
                ),
                LakwatsaHeaderAction(
                  text: '+',
                  label: 'Add item',
                  filled: true,
                  onPressed: _openAddItem,
                ),
              ],
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
                LakwatsaSearchField(
                  controller: searchController,
                  hintText: 'Search items...',
                  margin: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
    final customNames =
        customCategories
            .map((category) => category.name.trim())
            .where((name) => name.isNotEmpty)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final legacyNames =
        items
            .map((item) => item.category.trim())
            .where((name) => name.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final name in [...customNames, ...legacyNames]) {
      if (!names.any((existing) => ItemCategory.sameName(existing, name))) {
        names.add(name);
      }
    }

    return names;
  }

  List<Item> _filterItems(List<Item> items, String activeCategory) {
    final search = searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesSearch =
          search.isEmpty || item.name.toLowerCase().contains(search);

      final matchesCategory =
          activeCategory == 'All' ||
          ItemCategory.sameName(item.category, activeCategory);

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
          .where((item) => ItemCategory.sameName(item.category, category))
          .toList();

      if (categoryItems.isEmpty) {
        continue;
      }

      widgets.add(_ItemSection(title: category, items: categoryItems));
    }

    return widgets;
  }

  Future<void> _openBulkQrExport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BulkQrExportScreen()),
    );
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
      MaterialPageRoute(builder: (context) => const ManageCategoriesScreen()),
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
      height: 44,
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
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter by $text',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: AppMetrics.touchTarget,
            child: Center(
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.ink : AppColors.background,
                  border: Border.all(color: AppColors.ink, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(
                    fontSize: 11,
                    color: selected ? AppColors.background : AppColors.ink,
                  ),
                ),
              ),
            ),
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
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.pixelDark.copyWith(
                    color: AppColors.ink,
                    fontSize: 7,
                  ),
                ),
              ),

              const SizedBox(width: 12),

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
    return Semantics(
      button: true,
      label: 'Edit ${item.name}',
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2.5),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(4),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
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
