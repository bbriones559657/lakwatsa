import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import '../models/item_list.dart';
import 'list_repository.dart';

class FirestoreListRepository implements ListRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreListRepository({required this.userId, FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _listsCollection {
    return firestore.collection('users').doc(userId).collection('lists');
  }

  CollectionReference<Map<String, dynamic>> _listItemsCollection(
    String listId,
  ) {
    return _listsCollection.doc(listId).collection('items');
  }

  @override
  Stream<List<ItemList>> watchLists() {
    return _listsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return _listFromDocument(doc);
          }).toList();
        });
  }

  @override
  Future<ItemList?> getList(String listId) async {
    final document = await _listsCollection.doc(listId).get();

    if (!document.exists) {
      return null;
    }

    return _listFromDocument(document);
  }

  @override
  Future<ItemList> addList(ItemList list) async {
    final document = _listsCollection.doc();

    final now = DateTime.now();

    final newList = list.copyWith(
      id: document.id,
      createdAt: now,
      updatedAt: now,
    );

    await document.set({
      'name': newList.name.trim(),
      'icon': newList.icon,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return newList;
  }

  @override
  Future<void> updateList(ItemList list) async {
    await _listsCollection.doc(list.id).update({
      'name': list.name.trim(),
      'icon': list.icon,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> deleteList(String listId) async {
    final itemsSnapshot = await _listItemsCollection(listId).get();

    final batch = firestore.batch();

    for (final document in itemsSnapshot.docs) {
      batch.delete(document.reference);
    }

    batch.delete(_listsCollection.doc(listId));

    await batch.commit();
  }

  @override
  Stream<List<String>> watchListItemIds(String listId) {
    return _listItemsCollection(listId).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => doc.id).toList();
    });
  }

  @override
  Future<void> addItemToList({
    required String listId,
    required String itemId,
  }) async {
    await _listItemsCollection(listId)
        .doc(itemId)
        .set({'itemId': itemId, 'addedAt': Timestamp.now()});
  }

  @override
  Future<void> addItemsToList({
    required String listId,
    required List<Item> items,
  }) async {
    final batch = firestore.batch();

    for (final item in items) {
      final document = _listItemsCollection(listId).doc(item.id);

      batch.set(document, {'itemId': item.id, 'addedAt': Timestamp.now()});
    }

    await batch.commit();
  }

  @override
  Future<void> removeItemFromList({
    required String listId,
    required String itemId,
  }) async {
    await _listItemsCollection(listId).doc(itemId).delete();
  }

  @override
  Future<bool> containsItem({
    required String listId,
    required String itemId,
  }) async {
    final document = await _listItemsCollection(listId).doc(itemId).get();

    return document.exists;
  }

  @override
  Future<List<ItemList>> getListsContainingItem(String itemId) async {
    final listsSnapshot = await _listsCollection.get();

    final matchingLists = <ItemList>[];

    for (final listDocument in listsSnapshot.docs) {
      final itemDocument = await _listItemsCollection(listDocument.id)
          .doc(itemId)
          .get();

      if (itemDocument.exists) {
        matchingLists.add(_listFromDocument(listDocument));
      }
    }

    return matchingLists;
  }

  @override
  Future<List<String>> getListItemIds(String listId) async {
    final snapshot = await _listItemsCollection(listId).get();

    return snapshot.docs.map((document) => document.id).toList();
  }

  ItemList _listFromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    if (data == null) {
      throw StateError('List document ${document.id} does not contain data.');
    }

    return ItemList(
      id: document.id,
      name: data['name'] as String? ?? '',
      icon: data['icon'] as String? ?? 'list',
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
