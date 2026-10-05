import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item_category.dart';
import 'item_category_repository.dart';

class FirestoreItemCategoryRepository implements ItemCategoryRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreItemCategoryRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categoriesCollection {
    return firestore.collection('users').doc(userId).collection('categories');
  }

  CollectionReference<Map<String, dynamic>> get _itemsCollection {
    return firestore.collection('users').doc(userId).collection('items');
  }

  @override
  Stream<List<ItemCategory>> watchCustomCategories() {
    return _categoriesCollection.snapshots().map((snapshot) {
      final categories = snapshot.docs.map(_categoryFromDocument).toList();

      categories.sort((a, b) {
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      return categories;
    });
  }

  @override
  Future<ItemCategory> addCategory(String value) async {
    final name = ItemCategory.validateCustomName(value);
    final documentId = ItemCategory.documentIdForCustomName(name);
    final document = _categoriesCollection.doc(documentId);

    return firestore.runTransaction((transaction) async {
      final existing = await transaction.get(document);

      if (existing.exists) {
        throw StateError('A category named "$name" already exists.');
      }

      final now = DateTime.now();
      final category = ItemCategory(
        id: documentId,
        name: name,
        createdAt: now,
        updatedAt: now,
      );

      transaction.set(document, {
        'name': category.name,
        'createdAt': Timestamp.fromDate(now),
        'updatedAt': Timestamp.fromDate(now),
      });

      return category;
    });
  }

  @override
  Future<bool> categoryExists(String name) async {
    if (ItemCategory.isBuiltInName(name)) {
      return true;
    }

    try {
      final documentId = ItemCategory.documentIdForCustomName(name);
      final document = await _categoriesCollection.doc(documentId).get();

      return document.exists;
    } on ArgumentError {
      return false;
    }
  }

  @override
  Future<bool> isCategoryInUse(String name) async {
    final result = await _itemsCollection
        .where('category', isEqualTo: name)
        .limit(1)
        .get();

    return result.docs.isNotEmpty;
  }

  @override
  Future<void> deleteCategory(ItemCategory category) async {
    if (category.isBuiltIn) {
      throw StateError('Built-in categories cannot be deleted.');
    }

    if (await isCategoryInUse(category.name)) {
      throw StateError(
        'Move or delete Items using "${category.name}" before deleting it.',
      );
    }

    await _categoriesCollection.doc(category.id).delete();
  }

  ItemCategory _categoryFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError(
        'Category document ${document.id} does not contain data.',
      );
    }

    return ItemCategory(
      id: document.id,
      name: data['name'] as String? ?? '',
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }
}
