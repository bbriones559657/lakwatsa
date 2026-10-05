import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../services/auth_service.dart';

import '../../theme/app_theme.dart';

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

  FirestoreItemRepository? itemRepository;

  final List<String> categories = [
    'All',
    'Electronics',
    'Documents',
    'Clothing',
    'Toiletries',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      itemRepository = FirestoreItemRepository(userId: user.uid);
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
    if (itemRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<Item>>(
      stream: itemRepository!.watchItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load items.\n'
                '${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data ?? [];

        final filteredItems = _filterItems(items);

        return Column(
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
                    selected: selectedCategory == category,
                    onTap: () {
                      setState(() {
                        selectedCategory = category;
                      });
                    },
                  );
                },
              ),
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
  }

  List<Item> _filterItems(List<Item> items) {
    final searchText = searchController.text.trim().toLowerCase();

    return items.where((item) {
      final matchesCategory =
          selectedCategory == 'All' || item.category == selectedCategory;

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
    return GestureDetector(
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
