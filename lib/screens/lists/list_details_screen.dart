import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../models/item.dart';
import 'add_items_screen.dart';

class ListDetailsScreen extends StatefulWidget {
  final String listName;
  final int itemCount;

  const ListDetailsScreen({
    super.key,
    required this.listName,
    required this.itemCount,
  });

  @override
  State<ListDetailsScreen> createState() => _ListDetailsScreenState();
}

class _ListDetailsScreenState extends State<ListDetailsScreen> {
  bool editMode = false;

  // Temporary sample data.
  // Later this will come from the database.
  final List<Item> items = [
    const Item(
      id: 1,
      name: 'MacBook Pro',
      category: 'Electronics',
      quantity: 1,
      icon: 'laptop',
      hasQr: true,
    ),
    const Item(
      id: 2,
      name: 'USB-C Charger',
      category: 'Electronics',
      quantity: 1,
      icon: 'charger',
      hasQr: true,
    ),
    const Item(
      id: 4,
      name: 'Passport',
      category: 'Documents',
      quantity: 1,
      icon: 'passport',
      hasQr: true,
    ),
    const Item(
      id: 5,
      name: 'National ID',
      category: 'Documents',
      quantity: 1,
      icon: 'id',
      hasQr: false,
    ),
    const Item(
      id: 6,
      name: 'Jacket',
      category: 'Clothing',
      quantity: 1,
      icon: 'jacket',
      hasQr: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              listName: widget.listName,
              editMode: editMode,
              onEdit: () {
                setState(() {
                  editMode = !editMode;
                });
              },
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                children: [
                  _ListInfo(listName: widget.listName, itemCount: items.length),
                  const SizedBox(height: 24),
                  _SectionTitle(title: 'Items', count: items.length),
                  const SizedBox(height: 10),
                  ...List.generate(items.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ItemCard(
                        item: items[index],
                        editMode: editMode,
                        onDelete: () {
                          _deleteItem(index);
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  _AddItemsButton(onPressed: _addItems),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteItem(int index) {
    final itemName = items[index].name;

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
            'Remove Item?',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: Text(
            'Remove "$itemName" from this list? '
            'The item will remain in My Items.',
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
                  items.removeAt(index);
                });

                Navigator.pop(context);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addItems() async {
    // Send the IDs of items already in this list.
    //
    // Later these IDs will come from the database through
    // ITEM_LIST_ITEM (list_id + item_id).
    final existingItemIds = items.map((item) => item.id).toSet();

    final selectedItems = await Navigator.push<List<Item>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AddItemsScreen(existingItemIds: existingItemIds);
        },
      ),
    );

    if (!mounted || selectedItems == null) {
      return;
    }

    setState(() {
      for (final item in selectedItems) {
        final alreadyExists = items.any(
          (existingItem) => existingItem.id == item.id,
        );

        if (!alreadyExists) {
          items.add(item);
        }
      }
    });
  }
}

class _Header extends StatelessWidget {
  final String listName;
  final bool editMode;
  final VoidCallback onEdit;

  const _Header({
    required this.listName,
    required this.editMode,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const SizedBox(
              width: 42,
              height: 42,
              child: Icon(Icons.arrow_back, color: AppColors.ink, size: 24),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              listName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading.copyWith(fontSize: 21),
            ),
          ),
          const SizedBox(width: 8),
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
        ],
      ),
    );
  }
}

class _ListInfo extends StatelessWidget {
  final String listName;
  final int itemCount;

  const _ListInfo({required this.listName, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.list_alt_outlined,
            color: AppColors.ink,
            size: 34,
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listName,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 4),
            Text('$itemCount items', style: AppTextStyles.body),
          ],
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),
        const Spacer(),
        Text('$count items', style: AppTextStyles.body),
      ],
    );
  }
}

class _ItemCard extends StatelessWidget {
  final Item item;
  final bool editMode;
  final VoidCallback onDelete;

  const _ItemCard({
    required this.item,
    required this.editMode,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 76,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: double.infinity,
            decoration: BoxDecoration(
              color: item.hasQr ? AppColors.orange : AppColors.muted,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(2),
                bottomLeft: Radius.circular(2),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 46,
            height: 46,
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
              ],
            ),
          ),
          if (item.hasQr)
            Container(
              width: 38,
              height: 20,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppColors.green,
                border: Border.all(color: AppColors.ink, width: 1.5),
                borderRadius: BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: Text(
                'QR',
                style: AppTextStyles.pixelDark.copyWith(
                  color: AppColors.background,
                  fontSize: 5,
                ),
              ),
            ),
          if (editMode)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 34,
                height: double.infinity,
                alignment: Alignment.center,
                child: const Icon(Icons.close, color: AppColors.ink, size: 20),
              ),
            ),
        ],
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

class _AddItemsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddItemsButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
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
          '+ Add Items',
          style: AppTextStyles.bodyBold.copyWith(color: AppColors.background),
        ),
      ),
    );
  }
}
