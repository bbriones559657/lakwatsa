import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../models/item_category.dart';
import '../../repositories/firestore_item_category_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';
import '../items/add_item_screen.dart';

class AddItemsScreen extends StatefulWidget {
  final Set<String> existingItemIds;

  const AddItemsScreen({super.key, required this.existingItemIds});

  @override
  State<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends State<AddItemsScreen> {
  final TextEditingController searchController = TextEditingController();

  String selectedCategory = 'All';

  final Set<String> selectedItemIds = {};
  final Map<String, Item> newlyCreatedItems = {};

  FirestoreItemRepository? itemRepository;
  FirestoreItemCategoryRepository? categoryRepository;

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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          'Add Items',
          style: AppTextStyles.heading.copyWith(fontSize: 21),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.ink),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (itemRepository == null || categoryRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<Item>>(
      stream: itemRepository!.watchItems(),
      builder: (context, itemSnapshot) {
        if (itemSnapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load items.\n'
                '${itemSnapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (itemSnapshot.connectionState == ConnectionState.waiting &&
            !itemSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = _mergeItems(itemSnapshot.data ?? const []);

        return StreamBuilder<List<ItemCategory>>(
          stream: categoryRepository!.watchCustomCategories(),
          builder: (context, categorySnapshot) {
            final customCategories = categorySnapshot.data ?? const [];
            final categories = buildAddItemsCategoryNames(
              items: items,
              customCategories: customCategories,
            );
            final effectiveCategory = categories.contains(selectedCategory)
                ? selectedCategory
                : 'All';
            final filteredItems = _filterItems(
              items,
              category: effectiveCategory,
            );

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: LakwatsaSearchField(
                    controller: searchController,
                    hintText: 'Search items...',
                    margin: EdgeInsets.zero,
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ),

                SizedBox(
                  height: 48,
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
                        label: category,
                        selected: effectiveCategory == category,
                        onTap: () {
                          setState(() {
                            selectedCategory = category;
                          });
                        },
                      );
                    },
                  ),
                ),

                if (categorySnapshot.hasError)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Custom categories could not be refreshed. Existing '
                        'Item categories are still available.',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: _CreateNewItemButton(onPressed: _createNewItem),
                ),

                Expanded(child: _buildItemsList(filteredItems)),

                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
                    child: _AddButton(
                      count: selectedItemIds.length,
                      onPressed: selectedItemIds.isEmpty
                          ? null
                          : () {
                              _addSelectedItems(items);
                            },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Item> _mergeItems(List<Item> streamedItems) {
    final merged = <String, Item>{
      for (final item in streamedItems) item.id: item,
    };

    for (final item in newlyCreatedItems.values) {
      merged.putIfAbsent(item.id, () => item);
    }

    return merged.values.toList();
  }

  Future<void> _createNewItem() async {
    final createdItem = await Navigator.push<Item>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const AddItemScreen(returnSavedItem: true);
        },
      ),
    );

    if (!mounted || createdItem == null) {
      return;
    }

    if (widget.existingItemIds.contains(createdItem.id)) {
      return;
    }

    setState(() {
      newlyCreatedItems[createdItem.id] = createdItem;
      selectedItemIds.add(createdItem.id);
      selectedCategory = 'All';
      searchController.clear();
    });
  }

  List<Item> _filterItems(List<Item> items, {required String category}) {
    final searchText = searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesCategory =
          category == 'All' || ItemCategory.sameName(item.category, category);

      final matchesSearch =
          searchText.isEmpty || item.name.toLowerCase().contains(searchText);

      return matchesCategory && matchesSearch;
    }).toList();
  }

  Widget _buildItemsList(List<Item> items) {
    if (items.isEmpty) {
      return Center(child: Text('No items found', style: AppTextStyles.body));
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        final alreadyAdded = widget.existingItemIds.contains(item.id);

        final selected = selectedItemIds.contains(item.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _SelectableItemCard(
            item: item,
            selected: selected,
            alreadyAdded: alreadyAdded,
            onTap: alreadyAdded
                ? null
                : () {
                    setState(() {
                      if (selected) {
                        selectedItemIds.remove(item.id);
                      } else {
                        selectedItemIds.add(item.id);
                      }
                    });
                  },
          ),
        );
      },
    );
  }

  void _addSelectedItems(List<Item> items) {
    final selectedItems = items.where((item) {
      return selectedItemIds.contains(item.id);
    }).toList();

    Navigator.pop(context, selectedItems);
  }
}

List<String> buildAddItemsCategoryNames({
  required List<Item> items,
  required List<ItemCategory> customCategories,
}) {
  final names = <String>['All', ...ItemCategory.builtInNames];
  final extras = <String>[];

  void collect(String value) {
    final name = value.trim();

    if (name.isEmpty ||
        names.any((existing) => ItemCategory.sameName(existing, name)) ||
        extras.any((existing) => ItemCategory.sameName(existing, name))) {
      return;
    }

    extras.add(name);
  }

  for (final category in customCategories) {
    collect(category.name);
  }

  for (final item in items) {
    collect(item.category);
  }

  extras.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  names.addAll(extras);

  return names;
}

class _CreateNewItemButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CreateNewItemButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add a new item to My Items',
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.ink,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '+ Add New Item',
                      style: AppTextStyles.bodyBold,
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Filter by $label',
      child: SizedBox(
        height: AppMetrics.touchTarget,
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: selected ? AppColors.ink : AppColors.card,
                  border: Border.all(color: AppColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: selected ? AppColors.background : AppColors.ink,
                    fontSize: 11,
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

class _SelectableItemCard extends StatelessWidget {
  final Item item;
  final bool selected;
  final bool alreadyAdded;
  final VoidCallback? onTap;

  const _SelectableItemCard({
    required this.item,
    required this.selected,
    required this.alreadyAdded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: alreadyAdded ? 0.5 : 1,
        child: Container(
          height: 82,
          decoration: BoxDecoration(
            color: selected ? AppColors.card : AppColors.background,
            border: Border.all(color: AppColors.ink, width: selected ? 2 : 1.5),
            borderRadius: BorderRadius.circular(4),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),

              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.card,
                  border: Border.all(color: AppColors.ink, width: 1.5),
                  borderRadius: BorderRadius.circular(3),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _getItemIcon(item.icon),
                  color: AppColors.ink,
                  size: 24,
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

                    const SizedBox(height: 3),

                    Text(
                      '${item.category} • Qty ${item.quantity}',
                      style: AppTextStyles.body,
                    ),

                    if (alreadyAdded)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Already added',
                          style: AppTextStyles.bodyBold.copyWith(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              if (alreadyAdded)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: AppColors.ink,
                    size: 22,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.green : AppColors.background,
                      border: Border.all(color: AppColors.ink, width: 2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: selected
                        ? const Icon(
                            Icons.check,
                            color: AppColors.background,
                            size: 17,
                          )
                        : null,
                  ),
                ),
            ],
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

class _AddButton extends StatelessWidget {
  final int count;
  final VoidCallback? onPressed;

  const _AddButton({required this.count, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: enabled ? AppColors.ink : AppColors.muted,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: enabled
              ? const [BoxShadow(color: AppColors.green, offset: Offset(3, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          count == 0
              ? 'Add Items'
              : 'Add $count '
                    '${count == 1 ? 'Item' : 'Items'}',
          style: AppTextStyles.bodyBold.copyWith(color: AppColors.background),
        ),
      ),
    );
  }
}
