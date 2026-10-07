import 'package:flutter/material.dart';

import '../../models/item_category.dart';
import '../../repositories/firestore_item_category_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';
import 'item_icon_catalog.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final TextEditingController nameController = TextEditingController();

  FirestoreItemCategoryRepository? categoryRepository;
  bool isSaving = false;
  String newCategoryIconKey = ItemCategory.defaultIconKey;
  String? deletingCategoryId;
  String? updatingCategoryId;

  @override
  void initState() {
    super.initState();

    final user = AuthService().currentUser;

    if (user != null) {
      categoryRepository = FirestoreItemCategoryRepository(userId: user.uid);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    final repository = categoryRepository;

    if (repository == null || isSaving) {
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await repository.addCategory(
        nameController.text,
        iconKey: newCategoryIconKey,
      );

      if (!mounted) {
        return;
      }

      nameController.clear();
      setState(() {
        newCategoryIconKey = ItemCategory.defaultIconKey;
      });
      _showMessage('Category added.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<String?> _pickCategoryIcon({
    required String selectedIconKey,
    required String title,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryIconPickerSheet(
        title: title,
        selectedIconKey: selectedIconKey,
      ),
    );
  }

  Future<void> _chooseNewCategoryIcon() async {
    if (isSaving) return;

    final iconKey = await _pickCategoryIcon(
      selectedIconKey: newCategoryIconKey,
      title: 'Choose Category Icon',
    );

    if (!mounted || iconKey == null) return;

    setState(() {
      newCategoryIconKey = iconKey;
    });
  }

  Future<void> _changeCategoryIcon(ItemCategory category) async {
    final repository = categoryRepository;
    if (repository == null || updatingCategoryId != null) return;

    final iconKey = await _pickCategoryIcon(
      selectedIconKey: category.iconKey,
      title: 'Icon for ${category.name}',
    );

    if (!mounted || iconKey == null || iconKey == category.iconKey) return;

    setState(() {
      updatingCategoryId = category.id;
    });

    try {
      await repository.updateCategoryIcon(category, iconKey);
      if (mounted) _showMessage('Category icon updated.');
    } catch (error) {
      if (mounted) _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          updatingCategoryId = null;
        });
      }
    }
  }

  Future<void> _deleteCategory(ItemCategory category) async {
    final repository = categoryRepository;

    if (repository == null || deletingCategoryId != null) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: const BorderSide(color: AppColors.ink, width: 2),
          ),
          title: Text(
            'Delete Category?',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: Text(
            'Delete "${category.name}" from your available categories?',
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

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      deletingCategoryId = category.id;
    });

    try {
      await repository.deleteCategory(category);

      if (!mounted) {
        return;
      }

      _showMessage('Category deleted.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          deletingCategoryId = null;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final repository = categoryRepository;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        title: Text(
          'Categories',
          style: AppTextStyles.heading,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.ink),
        ),
      ),
      body: Stack(
        children: [
          const LakwatsaBackgroundDots(),
          Positioned.fill(
            child: repository == null
                ? Center(
                    child: Text(
                      'Please sign in again.',
                      style: AppTextStyles.body,
                    ),
                  )
                : StreamBuilder<List<ItemCategory>>(
                    stream: repository.watchCustomCategories(),
                    builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Could not load categories. Please try again.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.body,
                      ),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final customCategories = snapshot.data ?? [];

                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  children: [
                    Text(
                      'CREATE CATEGORY',
                      style: AppTextStyles.pixel.copyWith(
                        color: AppColors.muted,
                        fontSize: 7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameController,
                            enabled: !isSaving,
                            maxLength: ItemCategory.maxNameLength,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) {
                              _addCategory();
                            },
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.ink,
                              fontSize: 13,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Example: Travel Gear',
                              counterText: '',
                              hintStyle: AppTextStyles.body.copyWith(
                                fontSize: 13,
                              ),
                              filled: true,
                              fillColor: AppColors.background,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 13,
                              ),
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
                        ),
                        const SizedBox(width: 10),
                        Semantics(
                          button: true,
                          enabled: !isSaving,
                          label: 'Add category',
                          child: Opacity(
                            opacity: isSaving ? .55 : 1,
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.ink,
                                border: Border.all(
                                  color: AppColors.ink,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(
                                  AppMetrics.radius,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: AppColors.green,
                                    offset: Offset(3, 3),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: isSaving ? null : _addCategory,
                                  borderRadius: BorderRadius.circular(
                                    AppMetrics.radius,
                                  ),
                                  child: Center(
                                    child: isSaving
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.background,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.add,
                                            color: AppColors.background,
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CATEGORY ICON',
                      style: AppTextStyles.pixel.copyWith(
                        color: AppColors.muted,
                        fontSize: 7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _CategoryIconSelector(
                      iconKey: newCategoryIconKey,
                      label: itemIconLabelForKey(newCategoryIconKey),
                      onTap: isSaving ? null : _chooseNewCategoryIcon,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'BUILT-IN',
                      style: AppTextStyles.pixelDark.copyWith(fontSize: 7),
                    ),
                    const SizedBox(height: 8),
                    ...ItemCategory.builtInNames.map(
                      (name) => _CategoryRow(
                        name: name,
                        iconKey: defaultItemIconKeyForCategory(name),
                        builtIn: true,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'CUSTOM',
                            style: AppTextStyles.pixelDark.copyWith(fontSize: 7),
                          ),
                        ),
                        Text(
                          '${customCategories.length}',
                          style: AppTextStyles.body.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Custom categories can be removed only when no My Item uses them.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.muted,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (customCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No custom categories yet.',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.muted,
                          ),
                        ),
                      )
                    else
                      ...customCategories.map(
                        (category) => _CategoryRow(
                          name: category.name,
                          iconKey: category.iconKey,
                          builtIn: false,
                          updating: updatingCategoryId == category.id,
                          deleting: deletingCategoryId == category.id,
                          onEditIcon: () {
                            _changeCategoryIcon(category);
                          },
                          onDelete: () {
                            _deleteCategory(category);
                          },
                        ),
                      ),
                  ],
                );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final String iconKey;
  final bool builtIn;
  final bool updating;
  final bool deleting;
  final VoidCallback? onEditIcon;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.name,
    required this.iconKey,
    required this.builtIn,
    this.updating = false,
    this.deleting = false,
    this.onEditIcon,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: BorderRadius.circular(AppMetrics.radius),
        boxShadow: const [
          BoxShadow(color: AppColors.ink, offset: Offset(2, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.card,
              border: Border.all(color: AppColors.ink, width: 1.5),
              borderRadius: BorderRadius.circular(3),
            ),
            alignment: Alignment.center,
            child: Icon(
              itemIconDataForKey(iconKey),
              color: AppColors.ink,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
            ),
          ),
          if (builtIn)
            Text(
              'BUILT-IN',
              style: AppTextStyles.pixelDark.copyWith(
                color: AppColors.muted,
                fontSize: 5,
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CategoryRowAction(
                  label: 'Change $name category icon',
                  icon: Icons.edit_outlined,
                  loading: updating,
                  onTap: deleting || updating ? null : onEditIcon,
                ),
                _CategoryRowAction(
                  label: 'Delete $name category',
                  icon: Icons.delete_outline,
                  loading: deleting,
                  onTap: deleting || updating ? null : onDelete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryIconSelector extends StatelessWidget {
  final String iconKey;
  final String label;
  final VoidCallback? onTap;

  const _CategoryIconSelector({
    required this.iconKey,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
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
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppMetrics.radius),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(itemIconDataForKey(iconKey), color: AppColors.ink),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label, style: AppTextStyles.bodyBold),
                ),
                const Icon(Icons.edit_outlined, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryRowAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback? onTap;

  const _CategoryRowAction({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: SizedBox(
        width: 40,
        height: 44,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppMetrics.radius),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(icon, color: AppColors.ink, size: 20),
          ),
        ),
      ),
    );
  }
}

class _CategoryIconPickerSheet extends StatefulWidget {
  final String title;
  final String selectedIconKey;

  const _CategoryIconPickerSheet({
    required this.title,
    required this.selectedIconKey,
  });

  @override
  State<_CategoryIconPickerSheet> createState() =>
      _CategoryIconPickerSheetState();
}

class _CategoryIconPickerSheetState extends State<_CategoryIconPickerSheet> {
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
        border: Border(top: BorderSide(color: AppColors.ink, width: 2)),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [BoxShadow(color: AppColors.ink, offset: Offset(0, -5))],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            20,
            12,
            20,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: AppTextStyles.heading.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'This becomes the default icon for Items in this category.',
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
              Row(
                children: [
                  Text(
                    query.isEmpty ? 'ICON LIBRARY' : 'SEARCH RESULTS',
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
                    final selected = option.key == widget.selectedIconKey;

                    return Semantics(
                      button: true,
                      selected: selected,
                      label: '${option.label} category icon',
                      child: Container(
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.card
                              : AppColors.background,
                          border: Border.all(
                            color: selected ? AppColors.green : AppColors.ink,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(AppMetrics.radius),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.pop(context, option.key),
                            borderRadius: BorderRadius.circular(
                              AppMetrics.radius,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  option.icon,
                                  color: AppColors.ink,
                                  size: 23,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyBold.copyWith(
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
