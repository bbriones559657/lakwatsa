import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../models/item_list.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../lists/list_details_screen.dart';
import 'item_qr_screen.dart';

class AddItemScreen extends StatefulWidget {
  final Item? item;

  const AddItemScreen({super.key, this.item});

  bool get isEditing => item != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController itemNameController = TextEditingController();

  String selectedCategory = 'Electronics';

  int quantity = 1;

  bool hasQrCode = false;
  bool isSaving = false;
  bool isDeleting = false;

  Item? currentItem;

  @override
  void initState() {
    super.initState();

    currentItem = widget.item;

    final item = currentItem;

    if (item != null) {
      itemNameController.text = item.name;
      selectedCategory = item.category;
      quantity = item.quantity;
      hasQrCode = item.hasQr;
    }
  }

  @override
  void dispose() {
    itemNameController.dispose();
    super.dispose();
  }

  Future<void> _saveItem() async {
    final itemName = itemNameController.text.trim();

    if (itemName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an item name.')),
      );

      return;
    }

    final user = AuthService().currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('You must be signed in.')));

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final repository = FirestoreItemRepository(userId: user.uid);

      if (widget.isEditing) {
        final oldItem = currentItem;

        if (oldItem == null) {
          return;
        }

        final updatedItem = Item(
          id: oldItem.id,
          name: itemName,
          category: selectedCategory,
          quantity: quantity,
          icon: _getIconKey(selectedCategory),
          photoUrl: oldItem.photoUrl,

          // Important:
          // Editing the item should NOT replace
          // or remove an already assigned QR.
          qrCode: oldItem.qrCode,

          createdAt: oldItem.createdAt,
          updatedAt: DateTime.now(),
        );

        await repository.updateItem(updatedItem);

        currentItem = updatedItem;
      } else {
        final newItem = Item(
          id: '',
          name: itemName,
          category: selectedCategory,
          quantity: quantity,
          icon: _getIconKey(selectedCategory),

          // The toggle is only used while
          // creating a new item.
          qrCode: hasQrCode ? 'lakwatsa:item:${const Uuid().v4()}' : null,
        );

        await repository.addItem(newItem);
      }

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Item updated successfully.'
                : 'Item added successfully.',
          ),
        ),
      );

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Failed to update item: $error'
                : 'Failed to add item: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _openQrScreen() async {
    final item = currentItem;

    if (item == null) {
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ItemQrScreen(item: item);
        },
      ),
    );

    final user = AuthService().currentUser;

    if (user == null) {
      return;
    }

    final repository = FirestoreItemRepository(userId: user.uid);

    final refreshedItem = await repository.getItem(item.id);

    if (!mounted || refreshedItem == null) {
      return;
    }

    setState(() {
      currentItem = refreshedItem;
      hasQrCode = refreshedItem.hasQr;
    });
  }

  Future<void> _deleteItem() async {
    final item = currentItem;
    final user = AuthService().currentUser;

    if (item == null || user == null) {
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {
      final repository = FirestoreItemRepository(userId: user.uid);

      await repository.deleteItem(item.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Item deleted.')));

      Navigator.pop(context);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete item: $error')));
    } finally {
      if (mounted) {
        setState(() {
          isDeleting = false;
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final item = currentItem;
    final user = AuthService().currentUser;

    if (item == null || user == null) {
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {
      final listRepository = FirestoreListRepository(userId: user.uid);

      final usedByLists = await listRepository.getListsContainingItem(item.id);

      if (!mounted) {
        return;
      }

      if (usedByLists.isNotEmpty) {
        setState(() {
          isDeleting = false;
        });

        await _showItemInUseDialog(item.name, usedByLists);

        return;
      }

      setState(() {
        isDeleting = false;
      });

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
              'Delete Item?',
              style: AppTextStyles.heading.copyWith(fontSize: 20),
            ),
            content: Text(
              'Delete "${item.name}" from My Items?',
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

      if (shouldDelete == true) {
        await _deleteItem();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        isDeleting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check item usage: $error')),
      );
    }
  }

  Future<void> _showItemInUseDialog(
    String itemName,
    List<ItemList> lists,
  ) async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          title: Text(
            'Cannot Delete Item',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: SizedBox(
            width: 320,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"$itemName" is currently used in:',
                  style: AppTextStyles.body,
                ),

                const SizedBox(height: 14),

                ...lists.map((list) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(dialogContext);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) {
                              return ListDetailsScreen(
                                listId: list.id,
                                listName: list.name,
                              );
                            },
                          ),
                        );
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(color: AppColors.ink, width: 1.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.list_alt_outlined,
                              color: AppColors.ink,
                              size: 20,
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                list.name,
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
                  );
                }),

                const SizedBox(height: 6),

                Text(
                  'Remove the item from these lists before deleting it.',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text('OK', style: AppTextStyles.bodyBold),
            ),
          ],
        );
      },
    );
  }

  String _getIconKey(String category) {
    switch (category) {
      case 'Electronics':
        return 'electronics';

      case 'Documents':
        return 'documents';

      case 'Clothing':
        return 'clothing';

      case 'Toiletries':
        return 'toiletries';

      default:
        return 'inventory';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(title: widget.isEditing ? 'Edit Item' : 'New Item'),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.isEditing ? 'Edit Item' : 'Add Item',
                      style: AppTextStyles.heading.copyWith(fontSize: 24),
                    ),

                    const SizedBox(height: 22),

                    const _FieldLabel('Item Name'),

                    const SizedBox(height: 7),

                    _TextField(
                      controller: itemNameController,
                      hintText: 'Enter item name',
                    ),

                    const SizedBox(height: 18),

                    const _FieldLabel('Category'),

                    const SizedBox(height: 7),

                    _CategoryDropdown(
                      value: selectedCategory,
                      onChanged: (value) {
                        setState(() {
                          selectedCategory = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    const _FieldLabel('Quantity'),

                    const SizedBox(height: 7),

                    _QuantitySelector(
                      quantity: quantity,
                      onDecrease: () {
                        if (quantity > 1) {
                          setState(() {
                            quantity--;
                          });
                        }
                      },
                      onIncrease: () {
                        setState(() {
                          quantity++;
                        });
                      },
                    ),

                    const SizedBox(height: 22),

                    const _FieldLabel('Item Icon'),

                    const SizedBox(height: 7),

                    const _IconPreview(),

                    const SizedBox(height: 18),

                    const _FieldLabel('Photo'),

                    const SizedBox(height: 7),

                    const _PhotoButton(),

                    // QR toggle only appears
                    // while creating a NEW item.
                    if (!widget.isEditing) ...[
                      const SizedBox(height: 22),

                      _QrSection(
                        hasQrCode: hasQrCode,
                        onChanged: (value) {
                          setState(() {
                            hasQrCode = value;
                          });
                        },
                      ),
                    ],

                    const SizedBox(height: 28),

                    Row(
                      children: [
                        Expanded(
                          child: _ActionButton(
                            text: 'Cancel',
                            filled: false,
                            onPressed: () {
                              Navigator.pop(context);
                            },
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: _ActionButton(
                            text: isSaving
                                ? 'Saving...'
                                : widget.isEditing
                                ? 'Save Changes'
                                : 'Save Item',
                            filled: true,
                            onPressed: isSaving || isDeleting
                                ? () {}
                                : _saveItem,
                          ),
                        ),
                      ],
                    ),

                    // QR management for an
                    // EXISTING item.
                    if (widget.isEditing) ...[
                      const SizedBox(height: 18),

                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          border: Border.all(color: AppColors.ink, width: 2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.qr_code_2,
                                  color: AppColors.ink,
                                  size: 28,
                                ),

                                const SizedBox(width: 12),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'QR Code',
                                        style: AppTextStyles.bodyBold,
                                      ),

                                      const SizedBox(height: 3),

                                      Text(
                                        currentItem?.hasQr == true
                                            ? 'QR code assigned to this item.'
                                            : 'No QR code assigned.',
                                        style: AppTextStyles.body,
                                      ),
                                    ],
                                  ),
                                ),

                                if (currentItem?.hasQr == true)
                                  const Icon(
                                    Icons.check_circle,
                                    color: AppColors.green,
                                    size: 24,
                                  ),
                              ],
                            ),

                            const SizedBox(height: 14),

                            GestureDetector(
                              onTap: _openQrScreen,
                              child: Container(
                                width: double.infinity,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: currentItem?.hasQr == true
                                      ? AppColors.background
                                      : AppColors.ink,
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  currentItem?.hasQr == true
                                      ? 'View QR Code'
                                      : 'Generate QR Code',
                                  style: AppTextStyles.bodyBold.copyWith(
                                    color: currentItem?.hasQr == true
                                        ? AppColors.ink
                                        : AppColors.background,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      GestureDetector(
                        onTap: isDeleting || isSaving ? null : _confirmDelete,
                        child: Container(
                          width: double.infinity,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            border: Border.all(color: AppColors.ink, width: 2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isDeleting ? 'Deleting...' : 'Delete Item',
                            style: AppTextStyles.bodyBold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;

  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(bottom: BorderSide(color: AppColors.ink, width: 2)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
            },
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.arrow_back, color: AppColors.ink, size: 24),
            ),
          ),

          const Spacer(),

          Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 14)),

          const Spacer(),

          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;

  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.bodyBold.copyWith(fontSize: 13));
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _TextField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.body.copyWith(fontSize: 13),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.green, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.ink),
          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
          dropdownColor: AppColors.background,
          items: const [
            DropdownMenuItem(value: 'Electronics', child: Text('Electronics')),
            DropdownMenuItem(value: 'Documents', child: Text('Documents')),
            DropdownMenuItem(value: 'Clothing', child: Text('Clothing')),
            DropdownMenuItem(value: 'Toiletries', child: Text('Toiletries')),
            DropdownMenuItem(value: 'Other', child: Text('Other')),
          ],
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  const _QuantitySelector({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QuantityButton(text: '−', onPressed: onDecrease),

        Container(
          width: 70,
          height: 44,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.background,
            border: Border.symmetric(
              horizontal: BorderSide(color: AppColors.ink, width: 2),
            ),
          ),
          child: Text(
            quantity.toString(),
            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
          ),
        ),

        _QuantityButton(text: '+', onPressed: onIncrease),
      ],
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _QuantityButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.ink,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.bodyBold.copyWith(
            color: AppColors.background,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

class _IconPreview extends StatelessWidget {
  const _IconPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 82,
      height: 82,
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.inventory_2_outlined,
        color: AppColors.ink,
        size: 38,
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      alignment: Alignment.center,
      child: Text(
        '+ Add Photo',
        style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
      ),
    );
  }
}

class _QrSection extends StatelessWidget {
  final bool hasQrCode;
  final ValueChanged<bool> onChanged;

  const _QrSection({required this.hasQrCode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const Icon(Icons.qr_code_2, size: 36, color: AppColors.ink),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QR Code', style: AppTextStyles.bodyBold),

                const SizedBox(height: 3),

                Text(
                  hasQrCode
                      ? 'QR code will be created when this item is saved.'
                      : 'Optional. You can generate one later.',
                  style: AppTextStyles.body,
                ),
              ],
            ),
          ),

          Switch(
            value: hasQrCode,
            onChanged: onChanged,
            activeThumbColor: AppColors.background,
            activeTrackColor: AppColors.green,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final bool filled;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.text,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: filled ? AppColors.ink : AppColors.background,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(4),
          boxShadow: filled
              ? const [BoxShadow(color: AppColors.green, offset: Offset(3, 3))]
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: AppTextStyles.bodyBold.copyWith(
            color: filled ? AppColors.background : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
