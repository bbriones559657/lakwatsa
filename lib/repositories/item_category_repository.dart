import '../models/item_category.dart';

abstract class ItemCategoryRepository {
  Stream<List<ItemCategory>> watchCustomCategories();

  Future<ItemCategory> addCategory(String name);

  Future<bool> isCategoryInUse(String name);

  Future<void> deleteCategory(ItemCategory category);
}
