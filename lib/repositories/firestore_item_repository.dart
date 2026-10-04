import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/item.dart';
import 'item_repository.dart';

class FirestoreItemRepository implements ItemRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreItemRepository({required this.userId, FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _itemsCollection {
    return firestore.collection('users').doc(userId).collection('items');
  }

  @override
  Stream<List<Item>> watchItems() {
    return _itemsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return _itemFromDocument(doc);
          }).toList();
        });
  }

  @override
  Future<Item?> getItem(String itemId) async {
    final document = await _itemsCollection.doc(itemId).get();

    if (!document.exists) {
      return null;
    }

    return _itemFromDocument(document);
  }

  @override
  Future<Item?> getItemByQrCode(String qrCode) async {
    final snapshot = await _itemsCollection
        .where('qrCode', isEqualTo: qrCode)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return _itemFromDocument(snapshot.docs.first);
  }

  @override
  Future<Item> addItem(Item item) async {
    final document = _itemsCollection.doc();

    final now = DateTime.now();

    final newItem = item.copyWith(
      id: document.id,
      createdAt: now,
      updatedAt: now,
    );

    await document.set({
      'name': newItem.name.trim(),
      'category': newItem.category,
      'quantity': newItem.quantity,
      'icon': newItem.icon,
      'photoUrl': newItem.photoUrl,
      'qrCode': newItem.qrCode,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    });

    return newItem;
  }

  @override
  Future<void> updateItem(Item item) async {
    await _itemsCollection.doc(item.id).update({
      'name': item.name.trim(),
      'category': item.category,
      'quantity': item.quantity,
      'icon': item.icon,
      'photoUrl': item.photoUrl,
      'qrCode': item.qrCode,
      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> deleteItem(String itemId) async {
    await _itemsCollection.doc(itemId).delete();
  }

  Item _itemFromDocument(DocumentSnapshot<Map<String, dynamic>> document) {
    final data = document.data();

    if (data == null) {
      throw StateError('Item document ${document.id} does not contain data.');
    }

    return Item(
      id: document.id,
      name: data['name'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      icon: data['icon'] as String? ?? 'inventory',
      photoUrl: data['photoUrl'] as String?,
      qrCode: data['qrCode'] as String?,
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
