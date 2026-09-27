import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/item.dart';
import '../../data/mock_items.dart';

class AddItemsScreen extends StatefulWidget {
  final Set<int> existingItemIds;

  const AddItemsScreen({super.key, required this.existingItemIds});

  @override
  State<AddItemsScreen> createState() => _AddItemsScreenState();
}

class _AddItemsScreenState extends State<AddItemsScreen> {
  final TextEditingController searchController = TextEditingController();

  String selectedCategory = 'All';

  final List<Item> items = mockItems;

  final Set<int> selectedItemIds = {};

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredItems = items.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;

      final searchText = searchController.text.toLowerCase();

      final matchesSearch = item.name.toLowerCase().contains(searchText);

      return matchesCategory && matchesSearch;
    }).toList();

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
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
            child: _SearchField(
              controller: searchController,
              onChanged: (_) {
                setState(() {});
              },
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: selectedCategory == 'All',
                  onTap: () {
                    setState(() {
                      selectedCategory = 'All';
                    });
                  },
                ),
                _CategoryChip(
                  label: 'Electronics',
                  selected: selectedCategory == 'Electronics',
                  onTap: () {
                    setState(() {
                      selectedCategory = 'Electronics';
                    });
                  },
                ),
                _CategoryChip(
                  label: 'Documents',
                  selected: selectedCategory == 'Documents',
                  onTap: () {
                    setState(() {
                      selectedCategory = 'Documents';
                    });
                  },
                ),
                _CategoryChip(
                  label: 'Clothing',
                  selected: selectedCategory == 'Clothing',
                  onTap: () {
                    setState(() {
                      selectedCategory = 'Clothing';
                    });
                  },
                ),
                _CategoryChip(
                  label: 'Personal Care',
                  selected: selectedCategory == 'Personal Care',
                  onTap: () {
                    setState(() {
                      selectedCategory = 'Personal Care';
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Text('No items found', style: AppTextStyles.body),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                    itemCount: filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = filteredItems[index];

                      final alreadyAdded = widget.existingItemIds.contains(
                        item.id,
                      );

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
                  ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          child: GestureDetector(
            onTap: selectedItemIds.isEmpty ? null : _addSelectedItems,
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: selectedItemIds.isEmpty
                    ? AppColors.muted
                    : AppColors.ink,
                border: Border.all(color: AppColors.ink, width: 2),
                borderRadius: BorderRadius.circular(4),
                boxShadow: selectedItemIds.isEmpty
                    ? null
                    : const [
                        BoxShadow(color: AppColors.green, offset: Offset(3, 3)),
                      ],
              ),
              alignment: Alignment.center,
              child: Text(
                selectedItemIds.isEmpty
                    ? 'Add Items'
                    : 'Add ${selectedItemIds.length} Item'
                          '${selectedItemIds.length == 1 ? '' : 's'}',
                style: AppTextStyles.bodyBold.copyWith(
                  color: AppColors.background,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _addSelectedItems() {
    final selectedItems = items.where((item) {
      return selectedItemIds.contains(item.id);
    }).toList();

    Navigator.pop(context, selectedItems);
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        hintText: 'Search items',
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.muted),
        prefixIcon: const Icon(Icons.search, color: AppColors.ink),
        filled: true,
        fillColor: AppColors.card,
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
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
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.ink : AppColors.card,
            border: Border.all(color: AppColors.ink, width: 1.5),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: AppTextStyles.bodyBold.copyWith(
              color: selected ? AppColors.background : AppColors.ink,
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
        opacity: alreadyAdded ? 0.5 : 1.0,
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
                    Text(item.category, style: AppTextStyles.body),
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
        return Icons.checkroom;
      case 'shirt':
        return Icons.checkroom_outlined;
      case 'toothbrush':
        return Icons.cleaning_services_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
