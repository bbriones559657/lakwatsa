import '../models/item.dart';
import '../models/item_list.dart';

abstract class ListRepository {
  Stream<List<ItemList>> watchLists();

  Future<ItemList?> getList(String listId);

  Future<ItemList> addList(ItemList list);

  Future<void> updateList(ItemList list);

  Future<void> deleteList(String listId);

  Stream<List<String>> watchListItemIds(String listId);

  Future<void> addItemToList({required String listId, required String itemId});

  Future<void> addItemsToList({
    required String listId,
    required List<Item> items,
  });

  Future<void> removeItemFromList({
    required String listId,
    required String itemId,
  });

  Future<bool> containsItem({required String listId, required String itemId});

  Future<List<ItemList>> getListsContainingItem(String itemId);
  Future<List<String>> getListItemIds(String listId);
}
