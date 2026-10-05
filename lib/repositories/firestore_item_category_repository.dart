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
    return _categoriesCollection.orderBy('name').snapshots().map((snapshot) {
      return snapshot.docs.map(_categoryFromDocument).toList();
    });
  }

  @override
  Future<ItemCategory> addCategory(String value) async {
    final name = ItemCategory.validateCustomName(value);
    final documentId = ItemCategory.documentIdForCustomName(name);
    final document = _categoriesCollection.doc(documentId);
    final existing = await document.get();

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

    await document.set({
      'name': category.name,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return category;
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
