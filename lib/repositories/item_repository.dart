import '../models/item.dart';

abstract class ItemRepository {
  Stream<List<Item>> watchItems();

  Future<Item?> getItem(String itemId);

  Future<Item?> getItemByQrCode(String qrCode);

  Future<Item> addItem(Item item);

  Future<void> updateItem(Item item);

  Future<void> deleteItem(String itemId);
}
