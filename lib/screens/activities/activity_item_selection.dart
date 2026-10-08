import '../../models/item.dart';

List<Item> buildActivityItemSelection({
  required Iterable<Item> importedItems,
  required Iterable<Item> manuallyAddedItems,
  Set<String> removedItemIds = const <String>{},
  Map<String, int> quantityOverrides = const <String, int>{},
}) {
  final merged = <String, Item>{};

  for (final item in importedItems) {
    _mergeWithHighestQuantity(merged, item);
  }

  for (final item in manuallyAddedItems) {
    _mergeWithHighestQuantity(merged, item);
  }

  for (final itemId in removedItemIds) {
    merged.remove(itemId);
  }

  return merged.values.map((item) {
    final quantity = quantityOverrides[item.id];
    return quantity == null ? item : item.copyWith(quantity: quantity);
  }).toList();
}

List<Item> dedupeActivityItems(Iterable<Iterable<Item>> groups) {
  final merged = <String, Item>{};

  for (final items in groups) {
    for (final item in items) {
      _mergeWithHighestQuantity(merged, item);
    }
  }

  return merged.values.toList();
}

void _mergeWithHighestQuantity(Map<String, Item> merged, Item item) {
  final existing = merged[item.id];

  if (existing == null) {
    merged[item.id] = item;
    return;
  }

  if (item.quantity > existing.quantity) {
    // Keep one snapshot for the Item. Quantities from overlapping Lists are
    // alternatives, not quantities to add together, so the highest wins.
    merged[item.id] = existing.copyWith(quantity: item.quantity);
  }
}
