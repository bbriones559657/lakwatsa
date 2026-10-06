import 'package:flutter/material.dart';

import '../../models/item_category.dart';
import '../../repositories/firestore_item_category_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class ManageCategoriesScreen extends StatefulWidget {
  const ManageCategoriesScreen({super.key});

  @override
  State<ManageCategoriesScreen> createState() => _ManageCategoriesScreenState();
}

class _ManageCategoriesScreenState extends State<ManageCategoriesScreen> {
  final TextEditingController nameController = TextEditingController();

  FirestoreItemCategoryRepository? categoryRepository;
  bool isSaving = false;
  String? deletingCategoryId;

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
      await repository.addCategory(nameController.text);

      if (!mounted) {
        return;
      }

      nameController.clear();
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
          'Item Categories',
          style: AppTextStyles.heading.copyWith(fontSize: 21),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: Container(height: 2, color: AppColors.ink),
        ),
      ),
      body: repository == null
          ? Center(
              child: Text('Please sign in again.', style: AppTextStyles.body),
            )
          : StreamBuilder<List<ItemCategory>>(
              stream: repository.watchCustomCategories(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Failed to load categories.\n${snapshot.error}',
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
                      'Create Category',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 15),
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
                            style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
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
                        GestureDetector(
                          onTap: isSaving ? null : _addCategory,
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              border: Border.all(
                                color: AppColors.ink,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: const [
                                BoxShadow(
                                  color: AppColors.green,
                                  offset: Offset(3, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
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
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Built-in',
                      style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    ...ItemCategory.builtInNames.map(
                      (name) => _CategoryRow(name: name, builtIn: true),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Custom',
                            style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
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
                          builtIn: false,
                          deleting: deletingCategoryId == category.id,
                          onDelete: () {
                            _deleteCategory(category);
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final String name;
  final bool builtIn;
  final bool deleting;
  final VoidCallback? onDelete;

  const _CategoryRow({
    required this.name,
    required this.builtIn,
    this.deleting = false,
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
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(
            builtIn ? Icons.lock_outline : Icons.label_outline,
            color: AppColors.ink,
            size: 20,
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
            GestureDetector(
              onTap: deleting ? null : onDelete,
              child: SizedBox(
                width: 40,
                height: 40,
                child: deleting
                    ? const Padding(
                        padding: EdgeInsets.all(11),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.delete_outline,
                        color: AppColors.ink,
                        size: 21,
                      ),
              ),
            ),
        ],
      ),
    );
  }
}
