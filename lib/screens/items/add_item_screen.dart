import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../models/item.dart';
import '../../models/item_category.dart';
import '../../models/item_list.dart';
import '../../repositories/firestore_item_category_repository.dart';
import '../../repositories/firestore_item_repository.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';
import '../lists/list_details_screen.dart';
import 'item_icon_catalog.dart';
import 'item_qr_screen.dart';
import 'manage_categories_screen.dart';

class AddItemScreen extends StatefulWidget {
  final Item? item;
  final bool returnSavedItem;

  const AddItemScreen({
    super.key,
    this.item,
    this.returnSavedItem = false,
  });

  bool get isEditing => item != null;

  @override
  State<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends State<AddItemScreen> {
  final TextEditingController itemNameController = TextEditingController();

  FirestoreItemCategoryRepository? categoryRepository;

  String selectedCategory = 'Electronics';
  String selectedIconKey = 'electronics';
  String selectedCategoryDefaultIconKey = 'electronics';
  bool iconManuallySelected = false;

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
      selectedCategoryDefaultIconKey = defaultItemIconKeyForCategory(
        item.category,
      );
      selectedIconKey = item.icon.isEmpty
          ? selectedCategoryDefaultIconKey
          : item.icon;
      iconManuallySelected = selectedIconKey != selectedCategoryDefaultIconKey;
      quantity = item.quantity;
      hasQrCode = item.hasQr;
    } else {
      selectedCategoryDefaultIconKey = defaultItemIconKeyForCategory(
        selectedCategory,
      );
      selectedIconKey = selectedCategoryDefaultIconKey;
    }

    final user = AuthService().currentUser;

    if (user != null) {
      categoryRepository = FirestoreItemCategoryRepository(userId: user.uid);
      _syncSelectedCategoryDefaultIcon();
    }
  }

  @override
  void dispose() {
    itemNameController.dispose();
    super.dispose();
  }

  Future<void> _openCategoryManager() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ManageCategoriesScreen(),
      ),
    );

    await _syncSelectedCategoryDefaultIcon();
  }

  Future<String> _resolveCategoryDefaultIconKey(String category) async {
    if (ItemCategory.isBuiltInName(category)) {
      return defaultItemIconKeyForCategory(category);
    }

    final customCategory = await categoryRepository?.getCategory(category);
    return customCategory?.iconKey ?? ItemCategory.defaultIconKey;
  }

  Future<void> _syncSelectedCategoryDefaultIcon() async {
    final category = selectedCategory;
    final defaultIconKey = await _resolveCategoryDefaultIconKey(category);

    if (!mounted || selectedCategory != category) return;

    setState(() {
      final wasFollowingCategory = !iconManuallySelected;
      selectedCategoryDefaultIconKey = defaultIconKey;

      if (currentItem != null) {
        iconManuallySelected = selectedIconKey != defaultIconKey;
      } else if (wasFollowingCategory) {
        selectedIconKey = defaultIconKey;
      }
    });
  }

  Future<bool> _selectedCategoryIsAvailable(String category) async {
    if (ItemCategory.isBuiltInName(category)) {
      return true;
    }

    final originalCategory = widget.item?.category;

    if (widget.isEditing && originalCategory == category) {
      // Existing Items keep their stored category snapshot even if its custom
      // category definition was later removed.
      return true;
    }

    final repository = categoryRepository;

    if (repository == null) {
      return false;
    }

    return repository.categoryExists(category);
  }

  Future<void> _saveItem() async {
    if (isSaving || isDeleting) {
      return;
    }

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

    // Snapshot every value before the first await. Setting the busy flag here
    // makes the save single-flight even when category validation needs a read.
    final category = selectedCategory;
    final itemQuantity = quantity;
    final itemIconKey = selectedIconKey;
    final createQrCode = hasQrCode;

    setState(() {
      isSaving = true;
    });

    try {
      if (!await _selectedCategoryIsAvailable(category)) {
        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'That category is no longer available. Choose another category.',
            ),
          ),
        );

        return;
      }

      final repository = FirestoreItemRepository(userId: user.uid);
      Item? savedItem;

      if (widget.isEditing) {
        final oldItem = currentItem;

        if (oldItem == null) {
          return;
        }

        final updatedItem = Item(
          id: oldItem.id,
          name: itemName,
          category: category,
          quantity: itemQuantity,
          icon: itemIconKey,
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
        savedItem = updatedItem;
      } else {
        final newItem = Item(
          id: '',
          name: itemName,
          category: category,
          quantity: itemQuantity,
          icon: itemIconKey,

          // The toggle is only used while
          // creating a new item.
          qrCode: createQrCode ? 'lakwatsa:item:${const Uuid().v4()}' : null,
        );

        final createdItem = await repository.addItem(newItem);

        currentItem = createdItem;
        savedItem = createdItem;
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

      Navigator.pop(context, widget.returnSavedItem ? savedItem : null);
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

  Widget _buildCategoryDropdown() {
    final repository = categoryRepository;

    if (repository == null) {
      return _CategoryDropdown(
        value: selectedCategory,
        categories: _categoryNames(const []),
        unavailableValue: _isUnavailableSelection(const []),
        onChanged: isSaving ? null : _selectCategory,
      );
    }

    return StreamBuilder<List<ItemCategory>>(
      stream: repository.watchCustomCategories(),
      builder: (context, snapshot) {
        final customCategories = snapshot.data ?? [];
        final unavailableValue = snapshot.hasData && !snapshot.hasError
            ? _isUnavailableSelection(customCategories)
            : null;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CategoryDropdown(
              value: selectedCategory,
              categories: _categoryNames(customCategories),
              unavailableValue: unavailableValue,
              onChanged: isSaving ? null : _selectCategory,
            ),
            if (snapshot.hasError) ...[
              const SizedBox(height: 6),
              Text(
                'Custom categories could not be refreshed. Built-in and '
                'current categories are still shown.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ] else if (unavailableValue != null) ...[
              const SizedBox(height: 6),
              Text(
                'This category was removed. Choose another category before saving.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.muted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  List<String> _categoryNames(List<ItemCategory> customCategories) {
    final names = <String>[...ItemCategory.builtInNames];
    final customNames = customCategories
        .map((category) => category.name.trim())
        .where((name) => name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    for (final name in customNames) {
      if (!_containsCategoryName(names, name)) {
        names.add(name);
      }
    }

    // DropdownButton requires the selected value to exactly match one item.
    // Keep an existing Item's legacy casing even if it matches a built-in name
    // case-insensitively.
    if (!names.contains(selectedCategory)) {
      names.add(selectedCategory);
    }

    return names;
  }

  String? _isUnavailableSelection(List<ItemCategory> customCategories) {
    if (ItemCategory.isBuiltInName(selectedCategory)) {
      return null;
    }

    if (widget.isEditing && widget.item?.category == selectedCategory) {
      return null;
    }

    final available = customCategories.any(
      (category) => category.name == selectedCategory,
    );

    return available ? null : selectedCategory;
  }

  bool _containsCategoryName(List<String> names, String candidate) {
    final normalized = candidate.trim().toLowerCase();

    return names.any((name) => name.trim().toLowerCase() == normalized);
  }

  Future<void> _selectCategory(String value) async {
    final shouldFollowCategory = !iconManuallySelected;

    setState(() {
      selectedCategory = value;
      selectedCategoryDefaultIconKey = defaultItemIconKeyForCategory(value);

      if (shouldFollowCategory) {
        selectedIconKey = selectedCategoryDefaultIconKey;
      }
    });

    final defaultIconKey = await _resolveCategoryDefaultIconKey(value);
    if (!mounted || selectedCategory != value) return;

    setState(() {
      selectedCategoryDefaultIconKey = defaultIconKey;
      if (!iconManuallySelected) {
        selectedIconKey = defaultIconKey;
      }
    });
  }

  Future<void> _openIconPicker() async {
    if (isSaving || isDeleting) {
      return;
    }

    final defaultIconKey = await _resolveCategoryDefaultIconKey(
      selectedCategory,
    );

    if (!mounted) return;

    selectedCategoryDefaultIconKey = defaultIconKey;

    final result = await showModalBottomSheet<_IconPickerResult>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ItemIconPickerSheet(
          selectedIconKey: selectedIconKey,
          defaultIconKey: selectedCategoryDefaultIconKey,
          category: selectedCategory,
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      selectedIconKey = result.iconKey;
      iconManuallySelected = !result.followCategory;
    });
  }

  @override
  Widget build(BuildContext context) {
    final itemIcon = itemIconDataForKey(selectedIconKey);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            const LakwatsaBackgroundDots(),
            Column(
              children: [
                _TopBar(title: widget.isEditing ? 'Edit Item' : 'Add Item'),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('ITEM NAME'),
                        const SizedBox(height: 8),
                        _TextField(
                          controller: itemNameController,
                          hintText: 'Enter item name',
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            const _FieldLabel('CATEGORY'),
                            const Spacer(),
                            TextButton(
                              onPressed: isSaving ? null : _openCategoryManager,
                              style: TextButton.styleFrom(
                                minimumSize: const Size(56, 44),
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                foregroundColor: AppColors.green,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                'Manage',
                                style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildCategoryDropdown(),
                        const SizedBox(height: 18),
                        const _FieldLabel('QUANTITY'),
                        const SizedBox(height: 8),
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
                            if (quantity < 999) {
                              setState(() {
                                quantity++;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 20),
                        const _FieldLabel('APPEARANCE'),
                        const SizedBox(height: 8),
                        _AppearancePreview(
                          icon: itemIcon,
                          iconLabel: itemIconLabelForKey(selectedIconKey),
                          category: selectedCategory,
                          followsCategory: !iconManuallySelected,
                          onPressed: isSaving || isDeleting
                              ? null
                              : _openIconPicker,
                        ),
                        const SizedBox(height: 20),
                        const _FieldLabel('QR CODE'),
                        const SizedBox(height: 8),
                        if (widget.isEditing)
                          _QrActionButton(
                            label: currentItem?.hasQr == true
                                ? 'View QR Code'
                                : 'Generate QR Code',
                            selected: currentItem?.hasQr == true,
                            onPressed: isSaving || isDeleting
                                ? null
                                : _openQrScreen,
                          )
                        else
                          _QrActionButton(
                            label: hasQrCode
                                ? 'QR Ready on Save'
                                : 'Generate QR Code',
                            semanticLabel: hasQrCode
                                ? 'QR code will be generated when this item is saved'
                                : 'Generate a QR code when this item is saved',
                            selected: hasQrCode,
                            onPressed: isSaving || isDeleting
                                ? null
                                : () {
                                    setState(() {
                                      hasQrCode = !hasQrCode;
                                    });
                                  },
                          ),
                        const SizedBox(height: 26),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                text: 'Cancel',
                                filled: false,
                                onPressed: isSaving || isDeleting
                                    ? null
                                    : () {
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
                                    ? null
                                    : _saveItem,
                              ),
                            ),
                          ],
                        ),
                        if (widget.isEditing) ...[
                          const SizedBox(height: 20),
                          _DeleteButton(
                            deleting: isDeleting,
                            onPressed: isDeleting || isSaving
                                ? null
                                : _confirmDelete,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
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
      height: AppMetrics.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.ink,
            width: AppMetrics.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back',
            child: SizedBox(
              width: AppMetrics.touchTarget,
              height: AppMetrics.touchTarget,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(AppMetrics.radius),
                  child: const Icon(
                    Icons.arrow_back,
                    color: AppColors.ink,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.heading,
            ),
          ),
          const SizedBox(width: 12),
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
    return Text(
      text,
      style: AppTextStyles.pixel.copyWith(
        color: AppColors.muted,
        fontSize: 7,
      ),
    );
  }
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _TextField({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: TextField(
        controller: controller,
        style: AppTextStyles.body.copyWith(
          color: AppColors.ink,
          fontSize: 13,
        ),
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.body.copyWith(fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final List<String> categories;
  final String? unavailableValue;
  final ValueChanged<String>? onChanged;

  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.unavailableValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down,
            color: AppColors.muted,
            size: 20,
          ),
          style: AppTextStyles.body.copyWith(
            color: AppColors.ink,
            fontSize: 13,
          ),
          dropdownColor: AppColors.background,
          items: categories.map((category) {
            final unavailable = category == unavailableValue;

            return DropdownMenuItem(
              value: category,
              child: Text(
                unavailable ? '$category (Unavailable)' : category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: unavailable
                    ? AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 13,
                      )
                    : AppTextStyles.body.copyWith(
                        color: AppColors.ink,
                        fontSize: 13,
                      ),
              ),
            );
          }).toList(),
          onChanged: onChanged == null
              ? null
              : (value) {
                  if (value != null) {
                    onChanged!(value);
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
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            label: 'Decrease quantity',
            text: '−',
            onPressed: quantity > 1 ? onDecrease : null,
          ),
          Container(
            width: 64,
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
              style: AppTextStyles.bodyBold.copyWith(fontSize: 16),
            ),
          ),
          _QuantityButton(
            label: 'Increase quantity',
            text: '+',
            onPressed: quantity < 999 ? onIncrease : null,
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final String label;
  final String text;
  final VoidCallback? onPressed;

  const _QuantityButton({
    required this.label,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .45,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Material(
            color: AppColors.ink,
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: AppColors.ink, width: 2),
              borderRadius: BorderRadius.circular(AppMetrics.radius),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              child: Center(
                child: Text(
                  text,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: AppColors.background,
                    fontSize: 18,
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

class _AppearancePreview extends StatelessWidget {
  final IconData icon;
  final String iconLabel;
  final String category;
  final bool followsCategory;
  final VoidCallback? onPressed;

  const _AppearancePreview({
    required this.icon,
    required this.iconLabel,
    required this.category,
    required this.followsCategory,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final subtitle = followsCategory
        ? '$iconLabel · suggested by $category'
        : '$iconLabel · custom for this item';

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Change item icon. $subtitle',
      excludeSemantics: true,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 64),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.ink, width: 2),
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          boxShadow: const [
            BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(color: AppColors.ink, width: 1.5),
                      borderRadius: BorderRadius.circular(AppMetrics.radius),
                    ),
                    child: Icon(icon, color: AppColors.ink, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Item icon',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.body.copyWith(fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit_outlined,
                    color: enabled ? AppColors.ink : AppColors.muted,
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconPickerResult {
  final String iconKey;
  final bool followCategory;

  const _IconPickerResult({
    required this.iconKey,
    required this.followCategory,
  });
}

class _ItemIconPickerSheet extends StatefulWidget {
  final String selectedIconKey;
  final String defaultIconKey;
  final String category;

  const _ItemIconPickerSheet({
    required this.selectedIconKey,
    required this.defaultIconKey,
    required this.category,
  });

  @override
  State<_ItemIconPickerSheet> createState() => _ItemIconPickerSheetState();
}

class _ItemIconPickerSheetState extends State<_ItemIconPickerSheet> {
  final TextEditingController searchController = TextEditingController();
  final ScrollController scrollController = ScrollController();
  String query = '';
  bool expanded = false;

  @override
  void initState() {
    super.initState();
    scrollController.addListener(_expandFromScroll);
  }

  void _expandFromScroll() {
    if (!expanded && scrollController.hasClients && scrollController.offset > 0) {
      setState(() {
        expanded = true;
      });
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = searchItemIconOptions(query);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * (expanded ? 0.86 : 0.46),
      ),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: 2),
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: AppColors.ink,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            10,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Choose Item Icon',
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Search the icon library or use the category default.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: searchController,
                onTap: () {
                  if (!expanded) {
                    setState(() {
                      expanded = true;
                    });
                  }
                },
                onChanged: (value) {
                  setState(() {
                    expanded = true;
                    query = value;
                  });
                },
                style: AppTextStyles.body.copyWith(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Search icons...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear icon search',
                          onPressed: () {
                            searchController.clear();
                            setState(() {
                              query = '';
                            });
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  filled: true,
                  fillColor: AppColors.background,
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: AppColors.ink,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(
                      color: AppColors.green,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _CategoryDefaultIconButton(
                category: widget.category,
                iconKey: widget.defaultIconKey,
                selected: widget.selectedIconKey == widget.defaultIconKey,
                onPressed: () {
                  Navigator.pop(
                    context,
                    _IconPickerResult(
                      iconKey: widget.defaultIconKey,
                      followCategory: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    query.isEmpty ? 'OTHER ICONS' : 'SEARCH RESULTS',
                    style: AppTextStyles.pixel.copyWith(
                      color: AppColors.muted,
                      fontSize: 7,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${options.length}',
                    style: AppTextStyles.pixel.copyWith(
                      color: AppColors.muted,
                      fontSize: 7,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (options.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'No matching icons.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];

                    return _IconChoiceButton(
                      option: option,
                      selected: widget.selectedIconKey == option.key,
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _IconPickerResult(
                            iconKey: option.key,
                            followCategory: false,
                          ),
                        );
                      },
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryDefaultIconButton extends StatelessWidget {
  final String category;
  final String iconKey;
  final bool selected;
  final VoidCallback onPressed;

  const _CategoryDefaultIconButton({
    required this.category,
    required this.iconKey,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: selected ? AppColors.card : AppColors.background,
        border: Border.all(
          color: selected ? AppColors.green : AppColors.ink,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(3, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(
                  itemIconDataForKey(iconKey),
                  color: AppColors.ink,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Use category default',
                        style: AppTextStyles.bodyBold.copyWith(fontSize: 12),
                      ),
                      Text(
                        '$category · ${itemIconLabelForKey(iconKey)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.body.copyWith(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check,
                    color: AppColors.green,
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconChoiceButton extends StatelessWidget {
  final ItemIconOption option;
  final bool selected;
  final VoidCallback onPressed;

  const _IconChoiceButton({
    required this.option,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${option.label} item icon',
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.card : AppColors.background,
          border: Border.all(
            color: selected ? AppColors.green : AppColors.ink,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(AppMetrics.radius),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(option.icon, color: AppColors.ink, size: 23),
                const SizedBox(height: 4),
                Text(
                  option.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QrActionButton extends StatelessWidget {
  final String label;
  final String? semanticLabel;
  final bool selected;
  final VoidCallback? onPressed;

  const _QrActionButton({
    required this.label,
    this.semanticLabel,
    required this.selected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    const idleBackground = Color(0xFFFEEAD0);
    final background = selected ? AppColors.orange : idleBackground;
    final foreground = selected ? AppColors.ink : AppColors.orange;
    final borderColor = selected ? AppColors.ink : AppColors.orange;
    final shadowColor = selected ? AppColors.ink : AppColors.orange;

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: Container(
          width: double.infinity,
          height: 44,
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor, width: 2),
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            boxShadow: [
              BoxShadow(color: shadowColor, offset: const Offset(3, 3)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      selected ? Icons.check : Icons.qr_code_2,
                      color: foreground,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      maxLines: 1,
                      style: AppTextStyles.bodyBold.copyWith(
                        color: foreground,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String text;
  final bool filled;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.text,
    required this.filled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: text,
      child: Opacity(
        opacity: enabled ? 1 : .55,
        child: Container(
          height: AppMetrics.primaryButtonHeight,
          decoration: BoxDecoration(
            color: filled ? AppColors.ink : AppColors.card,
            border: Border.all(color: AppColors.ink, width: 2),
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            boxShadow: [
              BoxShadow(
                color: filled ? AppColors.green : AppColors.ink,
                offset: Offset(filled ? 4 : 3, filled ? 4 : 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              child: Center(
                child: Text(
                  text,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: filled ? AppColors.background : AppColors.ink,
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

class _DeleteButton extends StatelessWidget {
  final bool deleting;
  final VoidCallback? onPressed;

  const _DeleteButton({required this.deleting, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: deleting ? 'Deleting item' : 'Delete Item',
      child: Opacity(
        opacity: onPressed == null ? .55 : 1,
        child: Container(
          width: double.infinity,
          height: AppMetrics.primaryButtonHeight,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(
              color: AppColors.ink,
              width: AppMetrics.strongBorderWidth,
            ),
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            boxShadow: const [
              BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(AppMetrics.radius),
              child: Center(
                child: Text(
                  deleting ? 'Deleting...' : 'Delete Item',
                  style: AppTextStyles.bodyBold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
