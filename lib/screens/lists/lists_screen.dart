import 'package:flutter/material.dart';

import '../../models/item_list.dart';
import '../../repositories/firestore_list_repository.dart';
import '../../repositories/list_repository.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/lakwatsa_ui.dart';
import 'list_details_screen.dart';
import 'list_icon_catalog.dart';

class ListsScreen extends StatefulWidget {
  final bool openCreateOnStart;
  final ListRepository? listRepository;

  const ListsScreen({
    super.key,
    this.openCreateOnStart = false,
    this.listRepository,
  });

  @override
  State<ListsScreen> createState() => _ListsScreenState();
}

class _ListsScreenState extends State<ListsScreen> {
  bool editMode = false;

  final TextEditingController searchController = TextEditingController();

  ListRepository? listRepository;

  @override
  void initState() {
    super.initState();

    listRepository = widget.listRepository;
    final user = listRepository == null ? AuthService().currentUser : null;

    if (user != null) {
      listRepository = FirestoreListRepository(userId: user.uid);
    }

    if (widget.openCreateOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showCreateListDialog();
        }
      });
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
      body: SafeArea(
        child: Stack(
          children: [
            const LakwatsaBackgroundDots(),
            Column(
              children: [
                LakwatsaTopBar(
                  title: 'Lists',
                  actions: [
                    LakwatsaHeaderAction(
                      text: editMode ? 'Done' : 'Edit',
                      label: editMode ? 'Finish editing lists' : 'Edit lists',
                      bordered: false,
                      onPressed: () {
                        setState(() {
                          editMode = !editMode;
                        });
                      },
                    ),
                    LakwatsaHeaderAction(
                      text: '+',
                      label: 'Create list',
                      filled: true,
                      onPressed: _showCreateListDialog,
                    ),
                  ],
                ),
                Expanded(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      LakwatsaSearchField(
                        controller: searchController,
                        hintText: 'Search lists...',
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildLists()),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLists() {
    if (listRepository == null) {
      return Center(
        child: Text('Please sign in again.', style: AppTextStyles.body),
      );
    }

    return StreamBuilder<List<ItemList>>(
      stream: listRepository!.watchLists(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Failed to load lists.\n${snapshot.error}',
                textAlign: TextAlign.center,
                style: AppTextStyles.body,
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final lists = snapshot.data ?? [];

        final searchText = searchController.text.trim().toLowerCase();

        final filteredLists = lists.where((list) {
          if (searchText.isEmpty) {
            return true;
          }

          return list.name.toLowerCase().contains(searchText);
        }).toList();

        if (lists.isEmpty) {
          return const _EmptyState(
            title: 'No lists yet',
            message: 'Create your first reusable item list.',
          );
        }

        if (filteredLists.isEmpty) {
          return const _EmptyState(
            title: 'No lists found',
            message: 'Try a different search.',
          );
        }

        return _ListGrid(
          lists: filteredLists,
          repository: listRepository!,
          editMode: editMode,
          onDelete: _deleteList,
          onTap: (list) {
            if (editMode) {
              _showListDialog(existingList: list);
            } else {
              _openList(list);
            }
          },
        );
      },
    );
  }

  void _showCreateListDialog() {
    _showListDialog();
  }

  Future<void> _showListDialog({ItemList? existingList}) async {
    final pageContext = context;
    var draftName = existingList?.name ?? '';
    var selectedIconKey = existingList?.icon ?? 'list';
    var isSaving = false;
    final isEditing = existingList != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            final maxDialogHeight =
                (MediaQuery.sizeOf(dialogContext).height -
                        MediaQuery.viewInsetsOf(dialogContext).bottom -
                        80)
                    .clamp(0.0, double.infinity);
            return Dialog(
              backgroundColor: AppColors.background,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
                side: const BorderSide(color: AppColors.ink, width: 2),
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight: maxDialogHeight,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit List' : 'New List',
                          style: AppTextStyles.heading.copyWith(fontSize: 20),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'List Name',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 7),
                        TextFormField(
                          initialValue: draftName,
                          onChanged: (value) => draftName = value,
                          enabled: !isSaving,
                          textInputAction: TextInputAction.done,
                          style: AppTextStyles.bodyBold,
                          decoration: InputDecoration(
                            hintText: 'e.g. Weekend Trip',
                            hintStyle: AppTextStyles.body,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            enabledBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.ink,
                                width: 2,
                              ),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(
                                color: AppColors.green,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Icon',
                          style: AppTextStyles.bodyBold.copyWith(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        Semantics(
                          button: true,
                          label: 'Choose list icon',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: isSaving
                                  ? null
                                  : () async {
                                      final iconKey = await _showIconLibrary(
                                        dialogContext,
                                        selectedIconKey,
                                      );

                                      if (iconKey != null &&
                                          dialogContext.mounted) {
                                        setDialogState(() {
                                          selectedIconKey = iconKey;
                                        });
                                      }
                                    },
                              borderRadius: BorderRadius.circular(4),
                              child: Container(
                                height: 62,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  border: Border.all(
                                    color: AppColors.ink,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: AppColors.card,
                                        border: Border.all(
                                          color: AppColors.ink,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      alignment: Alignment.center,
                                      child: Icon(
                                        listIconDataForKey(selectedIconKey),
                                        color: AppColors.ink,
                                        size: 23,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        listIconLabelForKey(selectedIconKey),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                          ),
                        ),
                        const SizedBox(height: 24),
                        Wrap(
                          alignment: WrapAlignment.end,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              onPressed: isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                    },
                              child: Text(
                                'Cancel',
                                style: AppTextStyles.bodyBold,
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.ink,
                                foregroundColor: AppColors.background,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              onPressed: isSaving
                                  ? null
                                  : () async {
                                      if (isSaving) return;

                                      final name = draftName.trim();

                                      if (name.isEmpty) {
                                        ScaffoldMessenger.of(pageContext)
                                            .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Please enter a list name.',
                                                ),
                                              ),
                                            );
                                        return;
                                      }

                                      final repository = listRepository;
                                      if (repository == null) {
                                        return;
                                      }

                                      setDialogState(() {
                                        isSaving = true;
                                      });

                                      try {
                                        if (existingList == null) {
                                          await repository.addList(
                                            ItemList(
                                              id: '',
                                              name: name,
                                              icon: selectedIconKey,
                                            ),
                                          );
                                        } else {
                                          await repository.updateList(
                                            existingList.copyWith(
                                              name: name,
                                              icon: selectedIconKey,
                                            ),
                                          );
                                        }

                                        if (!mounted ||
                                            !dialogContext.mounted) {
                                          return;
                                        }

                                        Navigator.pop(dialogContext);
                                        ScaffoldMessenger.of(pageContext)
                                            .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  isEditing ? 'List updated.' : 'List created successfully.',
                                                ),
                                              ),
                                            );
                                      } catch (error) {
                                        if (!mounted) {
                                          return;
                                        }

                                        if (dialogContext.mounted) {
                                          setDialogState(() {
                                            isSaving = false;
                                          });
                                        }

                                        ScaffoldMessenger.of(
                                          pageContext,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing
                                                  ? 'Failed to update list: $error'
                                                  : 'Failed to create list: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                              child: isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.background,
                                      ),
                                    )
                                  : Text(isEditing ? 'Save Changes' : 'Create'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _showIconLibrary(
    BuildContext context,
    String selectedIconKey,
  ) async {
    final searchFieldKey = GlobalKey<FormFieldState<String>>();
    var query = '';

    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final options = searchListIconOptions(query);

            return SafeArea(
              top: false,
              child: Container(
                height: MediaQuery.sizeOf(sheetContext).height * .68,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(
                    top: BorderSide(color: AppColors.ink, width: 2),
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                  boxShadow: [
                    BoxShadow(color: AppColors.ink, offset: Offset(0, -5)),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Choose an Icon',
                              style: AppTextStyles.heading.copyWith(
                                fontSize: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close icon picker',
                            onPressed: () {
                              Navigator.pop(sheetContext);
                            },
                            icon: const Icon(
                              Icons.close,
                              color: AppColors.ink,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: TextFormField(
                        key: searchFieldKey,
                        onChanged: (value) {
                          setSheetState(() {
                            query = value;
                          });
                        },
                        textInputAction: TextInputAction.search,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.ink,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search icons...',
                          hintStyle: AppTextStyles.body.copyWith(fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.search,
                            color: AppColors.ink,
                            size: 20,
                          ),
                          suffixIcon: query.trim().isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Clear icon search',
                                  onPressed: () {
                                    searchFieldKey.currentState?.reset();
                                    setSheetState(() {
                                      query = '';
                                    });
                                  },
                                  icon: const Icon(Icons.close, size: 18),
                                ),
                          enabledBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.ink,
                              width: 2,
                            ),
                          ),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(
                              color: AppColors.green,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: options.isEmpty
                          ? Center(
                              child: Text(
                                'No matching icons.',
                                style: AppTextStyles.body,
                              ),
                            )
                          : ListView(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              children: [
                                for (final category in listIconCategories)
                                  if (options.any(
                                    (option) => option.category == category,
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 18,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            category,
                                            style: AppTextStyles.bodyBold
                                                .copyWith(fontSize: 14),
                                          ),
                                          const SizedBox(height: 8),
                                          GridView.count(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            crossAxisCount: 6,
                                            crossAxisSpacing: 8,
                                            mainAxisSpacing: 8,
                                            children: [
                                              for (final option
                                                  in options.where(
                                                    (option) =>
                                                        option.category ==
                                                        category,
                                                  ))
                                                Tooltip(
                                                  message: option.label,
                                                  child: Semantics(
                                                    button: true,
                                                    selected:
                                                        option.key ==
                                                        selectedIconKey,
                                                    label:
                                                        'Use ${option.label} icon',
                                                    child: Material(
                                                      color: Colors.transparent,
                                                      child: InkWell(
                                                        onTap: () {
                                                          Navigator.pop(
                                                            sheetContext,
                                                            option.key,
                                                          );
                                                        },
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                        child: Container(
                                                          decoration: BoxDecoration(
                                                            color:
                                                                option.key ==
                                                                    selectedIconKey
                                                                ? AppColors.ink
                                                                : AppColors
                                                                      .card,
                                                            border: Border.all(
                                                              color:
                                                                  AppColors.ink,
                                                              width: 2,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  4,
                                                                ),
                                                          ),
                                                          alignment:
                                                              Alignment.center,
                                                          child: Icon(
                                                            option.icon,
                                                            color:
                                                                option.key ==
                                                                    selectedIconKey
                                                                ? AppColors
                                                                      .background
                                                                : AppColors.ink,
                                                            size: 23,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                              ],
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    return result;
  }

  Future<void> _deleteList(ItemList list) async {
    if (listRepository == null) {
      return;
    }

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
            'Delete List?',
            style: AppTextStyles.heading.copyWith(fontSize: 20),
          ),
          content: Text(
            'Delete "${list.name}"? '
            'The items inside it will not be deleted.',
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
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

    if (shouldDelete != true) {
      return;
    }

    try {
      await listRepository!.deleteList(list.id);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('List deleted.')));
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete list: $error')));
    }
  }

  void _openList(ItemList list) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) {
          return ListDetailsScreen(
            listId: list.id,
            listName: list.name,
            listIcon: list.icon,
          );
        },
      ),
    );
  }
}

class _ListGrid extends StatelessWidget {
  final List<ItemList> lists;
  final ListRepository repository;
  final bool editMode;
  final ValueChanged<ItemList> onDelete;
  final ValueChanged<ItemList> onTap;

  const _ListGrid({
    required this.lists,
    required this.repository,
    required this.editMode,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.95,
      ),
      itemCount: lists.length,
      itemBuilder: (context, index) {
        final list = lists[index];

        return _ListCard(
          list: list,
          repository: repository,
          editMode: editMode,
          onDelete: () {
            onDelete(list);
          },
          onTap: () {
            onTap(list);
          },
        );
      },
    );
  }
}

class _ListCard extends StatelessWidget {
  final ItemList list;
  final ListRepository repository;
  final bool editMode;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ListCard({
    required this.list,
    required this.repository,
    required this.editMode,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              border: Border.all(color: AppColors.ink, width: 2),
              borderRadius: BorderRadius.circular(5),
              boxShadow: const [
                BoxShadow(color: AppColors.ink, offset: Offset(4, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    border: Border.all(color: AppColors.ink, width: 2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    listIconDataForKey(list.icon),
                    color: AppColors.ink,
                    size: 27,
                  ),
                ),

                const Spacer(),

                Text(
                  list.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyBold.copyWith(fontSize: 14),
                ),

                const SizedBox(height: 4),

                StreamBuilder<List<String>>(
                  stream: repository.watchListItemIds(list.id),
                  builder: (context, snapshot) {
                    final count = snapshot.data?.length ?? 0;

                    return Text(
                      '$count '
                      '${count == 1 ? 'item' : 'items'}',
                      style: AppTextStyles.body,
                    );
                  },
                ),
              ],
            ),
          ),

          if (editMode)
            Positioned(
              top: 0,
              right: 0,
              child: Semantics(
                button: true,
                label: 'Delete ${list.name}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onDelete,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.ink,
                          border: Border.all(color: AppColors.ink, width: 2),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '×',
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
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String message;

  const _EmptyState({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.list_alt_outlined,
              color: AppColors.muted,
              size: 48,
            ),

            const SizedBox(height: 14),

            Text(title, style: AppTextStyles.bodyBold.copyWith(fontSize: 16)),

            const SizedBox(height: 5),

            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.body,
            ),
          ],
        ),
      ),
    );
  }
}
