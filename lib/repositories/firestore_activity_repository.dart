import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity.dart';
import '../models/item.dart';
import '../models/activity_item.dart';
import 'activity_repository.dart';
import '../models/activity_check.dart';
import '../models/activity_check_item.dart';

class FirestoreActivityRepository implements ActivityRepository {
  final FirebaseFirestore firestore;
  final String userId;

  FirestoreActivityRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _activitiesCollection {
    return firestore.collection('users').doc(userId).collection('activities');
  }

  @override
  Future<ActivityCheck?> getActivityCheckByType({
    required String activityId,
    required String type,
  }) async {
    final snapshot = await _activitiesCollection
        .doc(activityId)
        .collection('checks')
        .get();

    final matching = snapshot.docs.where((document) {
      final data = document.data();

      return data['type'] == type;
    }).toList();

    if (matching.isEmpty) {
      return null;
    }

    matching.sort((a, b) {
      final aDate =
          _toDateTime(a.data()['completedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      final bDate =
          _toDateTime(b.data()['completedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0);

      return bDate.compareTo(aDate);
    });

    return _activityCheckFromDocument(matching.first);
  }

  @override
  Future<List<ActivityCheckItem>> getActivityCheckItems({
    required String activityId,
    required String checkId,
  }) async {
    final snapshot = await _activitiesCollection
        .doc(activityId)
        .collection('checks')
        .doc(checkId)
        .collection('items')
        .get();

    return snapshot.docs.map((document) {
      return _activityCheckItemFromDocument(document);
    }).toList();
  }

  @override
  Future<void> completeReturnCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  }) async {
    final activityDocument = _activitiesCollection.doc(activityId);

    final checkDocument = activityDocument.collection('checks').doc();

    final now = DateTime.now();
    final batch = firestore.batch();

    batch.set(checkDocument, {
      'type': 'RETURN',
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(now),
      'status': 'COMPLETED',
    });

    for (final item in activityItems) {
      final method = foundMethods[item.id];
      final isFound = method != null;

      final checkItemDocument = checkDocument.collection('items').doc(item.id);

      batch.set(checkItemDocument, {
        'activityItemId': item.id,
        'status': isFound ? 'FOUND' : 'NOT_FOUND',
        'method': method,
        'checkedAt': isFound ? Timestamp.fromDate(now) : null,
      });
    }

    batch.update(activityDocument, {
      'status': 'COMPLETED',
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }

  @override
  Future<void> completeBeforeActivityCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  }) async {
    final activityDocument = _activitiesCollection.doc(activityId);

    final checkDocument = activityDocument.collection('checks').doc();

    final now = DateTime.now();

    final batch = firestore.batch();

    batch.set(checkDocument, {
      'type': 'BEFORE_ACTIVITY',
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(now),
      'status': 'COMPLETED',
    });

    for (final item in activityItems) {
      final method = foundMethods[item.id];

      final isFound = method != null;

      final checkItemDocument = checkDocument.collection('items').doc(item.id);

      batch.set(checkItemDocument, {
        'activityItemId': item.id,
        'status': isFound ? 'FOUND' : 'NOT_FOUND',
        'method': method,
        'checkedAt': isFound ? Timestamp.fromDate(now) : null,
      });
    }

    // The Activity only becomes ACTIVE
    // after the before-check is finished.
    batch.update(activityDocument, {
      'status': 'ACTIVE',
      'updatedAt': Timestamp.fromDate(now),
    });

    await batch.commit();
  }

  @override
  Stream<List<Activity>> watchActivities() {
    return _activitiesCollection
        .orderBy('startAt', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((document) {
            return _activityFromDocument(document);
          }).toList();
        });
  }

  @override
  Future<Activity?> getActivity(String activityId) async {
    final document = await _activitiesCollection.doc(activityId).get();

    if (!document.exists) {
      return null;
    }

    return _activityFromDocument(document);
  }

  @override
  Future<Activity> addActivity(Activity activity) async {
    final document = _activitiesCollection.doc();

    final now = DateTime.now();

    final newActivity = activity.copyWith(
      id: document.id,
      createdAt: now,
      updatedAt: now,
    );

    await document.set(_activityToMap(newActivity, now));

    return newActivity;
  }

  @override
  Future<ActivityItem> addItemToActivity({
    required String activityId,
    required Item item,
  }) async {
    final document = _activityItemsCollection(activityId).doc(item.id);

    final existing = await document.get();

    if (existing.exists) {
      return _activityItemFromDocument(existing);
    }

    final now = DateTime.now();

    await document.set({
      'itemId': item.id,
      'itemName': item.name,
      'category': item.category,
      'quantity': item.quantity,
      'icon': item.icon,
      'photoUrl': item.photoUrl,
      'qrCode': item.qrCode,
      'addedDuringActivity': true,
      'createdAt': Timestamp.fromDate(now),
    });

    return ActivityItem(
      id: item.id,
      itemId: item.id,
      itemName: item.name,
      category: item.category,
      quantity: item.quantity,
      icon: item.icon,
      photoUrl: item.photoUrl,
      qrCode: item.qrCode,
      addedDuringActivity: true,
      createdAt: now,
    );
  }

  @override
  Future<Activity> addActivityWithItems({
    required Activity activity,
    required List<Item> items,
  }) async {
    final activityDocument = _activitiesCollection.doc();

    final now = DateTime.now();

    final newActivity = activity.copyWith(
      id: activityDocument.id,
      createdAt: now,
      updatedAt: now,
    );

    final batch = firestore.batch();

    batch.set(activityDocument, _activityToMap(newActivity, now));

    for (final item in items) {
      final itemDocument = activityDocument.collection('items').doc(item.id);

      batch.set(itemDocument, {
        'itemId': item.id,
        'itemName': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'icon': item.icon,
        'photoUrl': item.photoUrl,
        'qrCode': item.qrCode,
        'addedDuringActivity': false,
        'createdAt': Timestamp.fromDate(now),
      });
    }

    await batch.commit();

    return newActivity;
  }

  @override
  Future<void> updateActivity(Activity activity) async {
    await _activitiesCollection.doc(activity.id).update({
      'listId': activity.listId,
      'name': activity.name.trim(),
      'type': activity.type,

      'activityDate': Timestamp.fromDate(activity.activityDate),

      'startAt': Timestamp.fromDate(activity.startAt),

      'endAt': Timestamp.fromDate(activity.endAt),

      'reminderEnabled': activity.reminderEnabled,

      'reminderMinutes': activity.reminderMinutes,

      'status': activity.status,

      'updatedAt': Timestamp.now(),
    });
  }

  @override
  Future<void> deleteActivity(String activityId) async {
    await _activitiesCollection.doc(activityId).delete();
  }

  @override
  Future<void> updateActivityStatus({
    required String activityId,
    required String status,
  }) async {
    await _activitiesCollection.doc(activityId).update({
      'status': status,
      'updatedAt': Timestamp.now(),
    });
  }

  CollectionReference<Map<String, dynamic>> _activityItemsCollection(
    String activityId,
  ) {
    return _activitiesCollection.doc(activityId).collection('items');
  }

  @override
  Stream<List<ActivityItem>> watchActivityItems(String activityId) {
    return _activityItemsCollection(activityId).snapshots().map((snapshot) {
      return snapshot.docs.map((document) {
        return _activityItemFromDocument(document);
      }).toList();
    });
  }

  Map<String, dynamic> _activityToMap(Activity activity, DateTime now) {
    return {
      'listId': activity.listId,
      'name': activity.name.trim(),
      'type': activity.type,

      'activityDate': Timestamp.fromDate(activity.activityDate),

      'startAt': Timestamp.fromDate(activity.startAt),

      'endAt': Timestamp.fromDate(activity.endAt),

      'reminderEnabled': activity.reminderEnabled,

      'reminderMinutes': activity.reminderMinutes,

      'status': activity.status,

      'createdAt': Timestamp.fromDate(activity.createdAt ?? now),

      'updatedAt': Timestamp.fromDate(now),
    };
  }

  Activity _activityFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Activity ${document.id} has no data.');
    }

    return Activity(
      id: document.id,

      listId: data['listId'] as String? ?? '',

      name: data['name'] as String? ?? '',

      type: data['type'] as String? ?? 'Other',

      activityDate: _toDateTime(data['activityDate']) ?? DateTime.now(),

      startAt: _toDateTime(data['startAt']) ?? DateTime.now(),

      endAt: _toDateTime(data['endAt']) ?? DateTime.now(),

      reminderEnabled: data['reminderEnabled'] as bool? ?? false,

      reminderMinutes: (data['reminderMinutes'] as num?)?.toInt() ?? 30,

      status: data['status'] as String? ?? 'UPCOMING',

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

  ActivityItem _activityItemFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Activity item ${document.id} has no data.');
    }

    return ActivityItem(
      id: document.id,
      itemId: data['itemId'] as String? ?? document.id,
      itemName: data['itemName'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      icon: data['icon'] as String? ?? 'inventory',
      photoUrl: data['photoUrl'] as String?,
      qrCode: data['qrCode'] as String?,
      addedDuringActivity: data['addedDuringActivity'] as bool? ?? false,
      createdAt: _toDateTime(data['createdAt']),
    );
  }

  ActivityCheck _activityCheckFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Check ${document.id} has no data.');
    }

    return ActivityCheck(
      id: document.id,
      type: data['type'] as String? ?? '',
      status: data['status'] as String? ?? '',
      startedAt: _toDateTime(data['startedAt']),
      completedAt: _toDateTime(data['completedAt']),
    );
  }

  ActivityCheckItem _activityCheckItemFromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data();

    if (data == null) {
      throw StateError('Check item ${document.id} has no data.');
    }

    return ActivityCheckItem(
      id: document.id,
      activityItemId: data['activityItemId'] as String? ?? document.id,
      status: data['status'] as String? ?? 'NOT_FOUND',
      method: data['method'] as String?,
      checkedAt: _toDateTime(data['checkedAt']),
    );
  }
}
