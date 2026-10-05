import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity.dart';
import '../models/item.dart';
import '../models/activity_item.dart';
import 'activity_repository.dart';
import '../models/activity_check.dart';
import '../models/activity_check_item.dart';
import '../models/activity_check_draft.dart';
import '../models/activity_status_policy.dart';

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

  DocumentReference<Map<String, dynamic>> _draftDocument({
    required String activityId,
    required String checkType,
  }) {
    final draftId = switch (checkType) {
      'BEFORE_ACTIVITY' => 'draft_before_activity',
      'RETURN' => 'draft_return',
      _ => throw ArgumentError.value(checkType, 'checkType'),
    };

    return _activitiesCollection
        .doc(activityId)
        .collection('checks')
        .doc(draftId);
  }

  @override
  Future<ActivityCheckDraft?> getCheckDraft({
    required String activityId,
    required String checkType,
  }) async {
    final document = await _draftDocument(
      activityId: activityId,
      checkType: checkType,
    ).get();

    final data = document.data();
    if (data == null) return null;

    final methods = <String, String>{};
    final raw = data['foundMethods'];
    if (raw is Map) {
      for (final entry in raw.entries) {
        if (entry.key is String &&
            (entry.value == 'QR' || entry.value == 'MANUAL')) {
          methods[entry.key as String] = entry.value as String;
        }
      }
    }

    return ActivityCheckDraft(
      startedAt: _toDateTime(data['startedAt']) ?? DateTime.now(),
      foundMethods: methods,
    );
  }

  @override
  Future<void> saveCheckDraft({
    required String activityId,
    required String checkType,
    required DateTime startedAt,
    required Map<String, String> foundMethods,
  }) async {
    final activityDocument = _activitiesCollection.doc(activityId);
    final draftDocument = _draftDocument(
      activityId: activityId,
      checkType: checkType,
    );

    await firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }
      ActivityStatusPolicy.requireDraft(
        activitySnapshot.data()?['status'] as String?,
        checkType,
      );

      transaction.set(draftDocument, {
        // Drafts are not completed checks and do not appear in History.
        'type': 'DRAFT',
        'checkType': checkType,
        'status': 'IN_PROGRESS',
        'startedAt': Timestamp.fromDate(startedAt),
        'foundMethods': Map<String, String>.from(foundMethods),
        'updatedAt': Timestamp.now(),
      });
    });
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

    final checkDocument = activityDocument.collection('checks').doc('return');

    final now = DateTime.now();
    await firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }
      ActivityStatusPolicy.requireReturn(
        activitySnapshot.data()?['status'] as String?,
      );

      transaction.set(checkDocument, {
        'type': 'RETURN',
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': Timestamp.fromDate(now),
        'status': 'COMPLETED',
      });

      for (final item in activityItems) {
        final method = foundMethods[item.id];
        final isFound = method != null;

        final checkItemDocument = checkDocument
            .collection('items')
            .doc(item.id);

        transaction.set(checkItemDocument, {
          'activityItemId': item.id,
          'status': isFound ? 'FOUND' : 'NOT_FOUND',
          'method': method,
          'checkedAt': isFound ? Timestamp.fromDate(now) : null,
        });
      }

      transaction.update(activityDocument, {
        'status': 'COMPLETED',
        'updatedAt': Timestamp.fromDate(now),
      });

      transaction.delete(
        _draftDocument(activityId: activityId, checkType: 'RETURN'),
      );
    });
  }

  @override
  Future<void> completeBeforeActivityCheck({
    required String activityId,
    required List<ActivityItem> activityItems,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
  }) async {
    final activityDocument = _activitiesCollection.doc(activityId);

    final checkDocument = activityDocument
        .collection('checks')
        .doc('before_activity');

    final now = DateTime.now();

    await firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }
      ActivityStatusPolicy.requireBefore(
        activitySnapshot.data()?['status'] as String?,
      );

      transaction.set(checkDocument, {
        'type': 'BEFORE_ACTIVITY',
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': Timestamp.fromDate(now),
        'status': 'COMPLETED',
      });

      for (final item in activityItems) {
        final method = foundMethods[item.id];

        final isFound = method != null;

        final checkItemDocument = checkDocument
            .collection('items')
            .doc(item.id);

        transaction.set(checkItemDocument, {
          'activityItemId': item.id,
          'status': isFound ? 'FOUND' : 'NOT_FOUND',
          'method': method,
          'checkedAt': isFound ? Timestamp.fromDate(now) : null,
        });
      }

      // The Activity only becomes ACTIVE
      // after the before-check is finished.
      transaction.update(activityDocument, {
        'status': 'ACTIVE',
        'updatedAt': Timestamp.fromDate(now),
      });

      transaction.delete(
        _draftDocument(activityId: activityId, checkType: 'BEFORE_ACTIVITY'),
      );
    });
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
    ActivityStatusPolicy.requireNew(activity.status);
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
    final activityDocument = _activitiesCollection.doc(activityId);
    final document = _activityItemsCollection(activityId).doc(item.id);

    return firestore.runTransaction<ActivityItem>((transaction) async {
      // Firestore transactions require all reads before any writes.
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }
      ActivityStatusPolicy.requireEditable(
        activitySnapshot.data()?['status'] as String?,
      );

      final existing = await transaction.get(document);
      if (existing.exists) {
        return _activityItemFromDocument(existing);
      }

      final now = DateTime.now();
      transaction.set(document, {
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
    });
  }

  @override
  Future<Activity> addActivityWithItems({
    required Activity activity,
    required List<Item> items,
  }) async {
    ActivityStatusPolicy.requireNew(activity.status);
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

      // Status is controlled by the transactional completion methods.
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
    throw UnsupportedError(
      'Use the transactional Before or Return check to change Activity status.',
    );
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
