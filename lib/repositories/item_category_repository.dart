import '../models/item_category.dart';

abstract class ItemCategoryRepository {
  Stream<List<ItemCategory>> watchCustomCategories();

  Future<ItemCategory> addCategory(
    String name, {
    String iconKey = ItemCategory.defaultIconKey,
  });

  Future<ItemCategory?> getCategory(String name);

  Future<void> updateCategoryIcon(ItemCategory category, String iconKey);

  Future<bool> categoryExists(String name);

  Future<bool> isCategoryInUse(String name);

  Future<void> deleteCategory(ItemCategory category);
}
