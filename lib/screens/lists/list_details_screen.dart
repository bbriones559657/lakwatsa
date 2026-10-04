import 'package:flutter/material.dart';

import '../../models/item.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'add_items_screen.dart';

class ListDetailsScreen extends StatefulWidget {
  final String listId;
  final String listName;

  const ListDetailsScreen({
    super.key,
    required this.listId,
    required this.listName,
  });

  @override
  State<ListDetailsScreen> createState() =>
      _ListDetailsScreenState();
}

class _ListDetailsScreenState
    extends State<ListDetailsScreen> {
  bool editMode = false;

  FirestoreListRepository? listRepository;
  FirestoreItemRepository? itemRepository;

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      listRepository = FirestoreListRepository(
        userId: user.uid,
      );

      itemRepository = FirestoreItemRepository(
        userId: user.uid,
      );
    }
  }

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
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (listRepository == null ||
        itemRepository == null) {
      return Center(
        child: Text(
          'Please sign in again.',
          style: AppTextStyles.body,
        ),
      );
    }

    return StreamBuilder<List<String>>(
      stream: listRepository!.watchListItemIds(
        widget.listId,
      ),
      builder: (context, membershipSnapshot) {
        if (membershipSnapshot.hasError) {
          return Center(
            child: Text(
              'Failed to load list items.\n'
              '${membershipSnapshot.error}',
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          );
        }

        if (membershipSnapshot.connectionState ==
            ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final itemIds =
            membershipSnapshot.data ?? [];

        return StreamBuilder<List<Item>>(
          stream: itemRepository!.watchItems(),
          builder: (context, itemSnapshot) {
            if (itemSnapshot.hasError) {
              return Center(
                child: Text(
                  'Failed to load items.\n'
                  '${itemSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.body,
                ),
              );
            }

            if (itemSnapshot.connectionState ==
                ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final allItems =
                itemSnapshot.data ?? [];

            final items = allItems.where((item) {
              return itemIds.contains(item.id);
            }).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(
                20,
                20,
                20,
                30,
              ),
              children: [
                _ListInfo(
                  listName: widget.listName,
                  itemCount: items.length,
                ),

                const SizedBox(height: 24),

                _SectionTitle(
                  title: 'Items',
                  count: items.length,
                ),

                const SizedBox(height: 10),

                if (items.isEmpty)
                  const _EmptyItems()
                else
                  ...items.map(
                    (item) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 12,
                        ),
                        child: _ItemCard(
                          item: item,
                          editMode: editMode,
                          onDelete: () {
                            _removeItem(item);
                          },
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 8),

                _AddItemsButton(
                  onPressed: () {
                    _addItems(
                      itemIds.toSet(),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addItems(
    Set<String> existingItemIds,
  ) async {
    final selectedItems =
        await Navigator.push<List<Item>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return AddItemsScreen(
            existingItemIds:
                existingItemIds,
          );
        },
      ),
    );

    if (!mounted ||
        selectedItems == null ||
        selectedItems.isEmpty) {
      return;
    }

    if (listRepository == null) {
      return;
    }

    try {
      await listRepository!.addItemsToList(
        listId: widget.listId,
        items: selectedItems,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${selectedItems.length} '
            '${selectedItems.length == 1 ? 'item' : 'items'} '
            'added to ${widget.listName}.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to add items: $error',
          ),
        ),
      );
    }
  }

  Future<void> _removeItem(Item item) async {
    if (listRepository == null) {
      return;
    }

    final shouldRemove =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(6),
            side: const BorderSide(
              color: AppColors.ink,
              width: 2,
            ),
          ),
          title: Text(
            'Remove Item?',
            style:
                AppTextStyles.heading.copyWith(
              fontSize: 20,
            ),
          ),
          content: Text(
            'Remove "${item.name}" from this list? '
            'The item will remain in My Items.',
            style: AppTextStyles.body,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Cancel',
                style:
                    AppTextStyles.bodyBold,
              ),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    AppColors.ink,
                foregroundColor:
                    AppColors.background,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    4,
                  ),
                ),
              ),
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              child:
                  const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (shouldRemove != true) {
      return;
    }

    try {
      await listRepository!
          .removeItemFromList(
        listId: widget.listId,
        itemId: item.id,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Item removed from list.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to remove item: $error',
          ),
        ),
      );
    }
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
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppColors.ink,
            width: 2,
          ),
        ),
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
              child: Icon(
                Icons.arrow_back,
                color: AppColors.ink,
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 4),

          Expanded(
            child: Text(
              listName,
              maxLines: 1,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  AppTextStyles.heading.copyWith(
                fontSize: 21,
              ),
            ),
          ),

          const SizedBox(width: 8),

          GestureDetector(
            onTap: onEdit,
            child: Container(
              height: 42,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration: BoxDecoration(
                color: editMode
                    ? AppColors.ink
                    : AppColors.background,
                border: Border.all(
                  color: AppColors.ink,
                  width: 2,
                ),
                borderRadius:
                    BorderRadius.circular(4),
              ),
              alignment: Alignment.center,
              child: Text(
                editMode
                    ? 'Save'
                    : 'Edit',
                style: AppTextStyles
                    .bodyBold
                    .copyWith(
                  color: editMode
                      ? AppColors.background
                      : AppColors.ink,
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

  const _ListInfo({
    required this.listName,
    required this.itemCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: AppColors.card,
            border: Border.all(
              color: AppColors.ink,
              width: 2,
            ),
            borderRadius:
                BorderRadius.circular(4),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.list_alt_outlined,
            color: AppColors.ink,
            size: 34,
          ),
        ),

        const SizedBox(width: 14),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                listName,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: AppTextStyles
                    .bodyBold
                    .copyWith(
                  fontSize: 18,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '$itemCount '
                '${itemCount == 1 ? 'item' : 'items'}',
                style: AppTextStyles.body,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final int count;

  const _SectionTitle({
    required this.title,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style:
              AppTextStyles.bodyBold.copyWith(
            fontSize: 16,
          ),
        ),

        const Spacer(),

        Text(
          '$count '
          '${count == 1 ? 'item' : 'items'}',
          style: AppTextStyles.body,
        ),
      ],
    );
  }
}

class _EmptyItems extends StatelessWidget {
  const _EmptyItems();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 36,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(
          color: AppColors.ink,
          width: 1.5,
        ),
        borderRadius:
            BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: AppColors.muted,
            size: 40,
          ),

          const SizedBox(height: 10),

          Text(
            'No items in this list',
            style:
                AppTextStyles.bodyBold,
          ),

          const SizedBox(height: 4),

          Text(
            'Add items from My Items.',
            textAlign: TextAlign.center,
            style: AppTextStyles.body,
          ),
        ],
      ),
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
        border: Border.all(
          color: AppColors.ink,
          width: 2,
        ),
        borderRadius:
            BorderRadius.circular(4),
        boxShadow: const [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(3, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: double.infinity,
            decoration: BoxDecoration(
              color: item.hasQr
                  ? AppColors.orange
                  : AppColors.muted,
              borderRadius:
                  const BorderRadius.only(
                topLeft:
                    Radius.circular(2),
                bottomLeft:
                    Radius.circular(2),
              ),
            ),
          ),

          const SizedBox(width: 12),

          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(
                color: AppColors.ink,
                width: 1.5,
              ),
              borderRadius:
                  BorderRadius.circular(3),
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
              mainAxisAlignment:
                  MainAxisAlignment.center,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: AppTextStyles
                      .bodyBold
                      .copyWith(
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  '${item.category} • Qty ${item.quantity}',
                  style:
                      AppTextStyles.body,
                ),
              ],
            ),
          ),

          if (item.hasQr)
            Container(
              width: 38,
              height: 20,
              margin:
                  const EdgeInsets.only(
                right: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.green,
                border: Border.all(
                  color: AppColors.ink,
                  width: 1.5,
                ),
                borderRadius:
                    BorderRadius.circular(2),
              ),
              alignment: Alignment.center,
              child: Text(
                'QR',
                style: AppTextStyles
                    .pixelDark
                    .copyWith(
                  color:
                      AppColors.background,
                  fontSize: 5,
                ),
              ),
            ),

          if (editMode)
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 42,
                height: double.infinity,
                alignment:
                    Alignment.center,
                child: const Icon(
                  Icons.close,
                  color: AppColors.ink,
                  size: 20,
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getItemIcon(
    String icon,
  ) {
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

class _AddItemsButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _AddItemsButton({
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.ink,
          border: Border.all(
            color: AppColors.ink,
            width: 2,
          ),
          borderRadius:
              BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: AppColors.green,
              offset: Offset(3, 3),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          '+ Add Items',
          style:
              AppTextStyles.bodyBold.copyWith(
            color: AppColors.background,
          ),
        ),
      ),
    );
  }
}