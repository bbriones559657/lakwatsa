import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/activity.dart';
import '../models/item.dart';
import '../models/activity_item.dart';
import 'activity_repository.dart';
import '../models/activity_check.dart';
import '../models/activity_check_item.dart';
import '../models/activity_check_draft.dart';
import '../models/activity_status_policy.dart';

class _ActivityItemState {
  final int count;
  final int revision;

  const _ActivityItemState({required this.count, required this.revision});
}

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
    final expectedItemState = await _ensureActivityItemState(activityId);
    _requireUniqueActivityItems(activityItems);

    final activityDocument = _activitiesCollection.doc(activityId);
    final checkDocument = activityDocument.collection('checks').doc('return');
    final itemDocuments = activityItems
        .map((item) => _activityItemsCollection(activityId).doc(item.id))
        .toList();

    final now = DateTime.now();
    await firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final activityData = activitySnapshot.data();
      ActivityStatusPolicy.requireReturn(activityData?['status'] as String?);

      final currentItemState = _requireActivityItemState(activityData);
      ActivityStatusPolicy.requireItemSnapshotForCheck(
        currentCount: currentItemState.count,
        currentRevision: currentItemState.revision,
        submittedCount: activityItems.length,
        expectedRevision: expectedItemState.revision,
      );

      final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final document in itemDocuments) {
        itemSnapshots.add(await transaction.get(document));
      }
      if (itemSnapshots.any((snapshot) => !snapshot.exists)) {
        throw StateError(
          'Activity Items changed. Review the refreshed list and try again.',
        );
      }

      transaction.set(checkDocument, {
        'type': 'RETURN',
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': Timestamp.fromDate(now),
        'status': 'COMPLETED',
        'itemCount': currentItemState.count,
        'itemRevision': currentItemState.revision,
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
    final expectedItemState = await _ensureActivityItemState(activityId);
    _requireUniqueActivityItems(activityItems);

    final activityDocument = _activitiesCollection.doc(activityId);
    final checkDocument = activityDocument
        .collection('checks')
        .doc('before_activity');
    final itemDocuments = activityItems
        .map((item) => _activityItemsCollection(activityId).doc(item.id))
        .toList();

    final now = DateTime.now();

    await firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final activityData = activitySnapshot.data();
      ActivityStatusPolicy.requireBefore(activityData?['status'] as String?);

      final currentItemState = _requireActivityItemState(activityData);
      ActivityStatusPolicy.requireItemSnapshotForCheck(
        currentCount: currentItemState.count,
        currentRevision: currentItemState.revision,
        submittedCount: activityItems.length,
        expectedRevision: expectedItemState.revision,
      );

      final itemSnapshots = <DocumentSnapshot<Map<String, dynamic>>>[];
      for (final document in itemDocuments) {
        itemSnapshots.add(await transaction.get(document));
      }
      if (itemSnapshots.any((snapshot) => !snapshot.exists)) {
        throw StateError(
          'Activity Items changed. Review the refreshed list and try again.',
        );
      }

      transaction.set(checkDocument, {
        'type': 'BEFORE_ACTIVITY',
        'startedAt': Timestamp.fromDate(startedAt),
        'completedAt': Timestamp.fromDate(now),
        'status': 'COMPLETED',
        'itemCount': currentItemState.count,
        'itemRevision': currentItemState.revision,
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

      // The Activity only becomes ACTIVE after the Before Check is finished.
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
    throw UnsupportedError(
      'Activities must be created with at least one Item.',
    );
  }

  @override
  Future<ActivityItem> addItemToActivity({
    required String activityId,
    required Item item,
  }) async {
    final results = await addItemsToActivity(
      activityId: activityId,
      items: [item],
    );

    return results.single;
  }

  @override
  Future<List<ActivityItem>> addItemsToActivity({
    required String activityId,
    required List<Item> items,
  }) async {
    if (items.isEmpty) {
      return const [];
    }

    await _ensureActivityItemState(activityId);

    final uniqueItems = <String, Item>{
      for (final item in items) item.id: item,
    }.values.toList();
    final results = <ActivityItem>[];

    // Add one Item per transaction so Firestore Rules can tie every parent
    // count/revision change to the exact child document being created.
    for (final item in uniqueItems) {
      results.add(
        await _addSingleItemToActivity(
          activityId: activityId,
          item: item,
        ),
      );
    }

    return results;
  }

  Future<ActivityItem> _addSingleItemToActivity({
    required String activityId,
    required Item item,
  }) async {
    final activityDocument = _activitiesCollection.doc(activityId);
    final itemDocument = _activityItemsCollection(activityId).doc(item.id);

    return firestore.runTransaction<ActivityItem>((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      final existingSnapshot = await transaction.get(itemDocument);

      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final activityData = activitySnapshot.data();
      final status = activityData?['status'] as String?;
      final addedDuringActivity =
          ActivityStatusPolicy.addedDuringActivityFor(status);
      final currentItemState = _requireActivityItemState(activityData);

      if (existingSnapshot.exists) {
        return _activityItemFromDocument(existingSnapshot);
      }
      if (currentItemState.count >= 200) {
        throw StateError('An Activity can contain at most 200 Items.');
      }

      final now = DateTime.now();
      transaction.set(itemDocument, {
        'itemId': item.id,
        'itemName': item.name,
        'category': item.category,
        'quantity': item.quantity,
        'icon': item.icon,
        'photoUrl': item.photoUrl,
        'qrCode': item.qrCode,
        'addedDuringActivity': addedDuringActivity,
        'createdAt': Timestamp.fromDate(now),
      });
      transaction.update(activityDocument, {
        'itemCount': currentItemState.count + 1,
        'itemRevision': currentItemState.revision + 1,
        'itemMutationId': item.id,
        'itemMutationType': 'ADD',
        'updatedAt': Timestamp.fromDate(now),
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
        addedDuringActivity: addedDuringActivity,
        createdAt: now,
      );
    });
  }

  @override
  Future<void> removeItemFromActivity({
    required String activityId,
    required String itemId,
  }) async {
    await _ensureActivityItemState(activityId);

    final activityDocument = _activitiesCollection.doc(activityId);
    final itemDocument = _activityItemsCollection(activityId).doc(itemId);
    final draftDocument = _draftDocument(
      activityId: activityId,
      checkType: 'BEFORE_ACTIVITY',
    );

    await firestore.runTransaction((transaction) async {
      // Keep a partially completed Before draft consistent with item removal.
      final activitySnapshot = await transaction.get(activityDocument);
      final itemSnapshot = await transaction.get(itemDocument);
      final draftSnapshot = await transaction.get(draftDocument);

      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }
      if (!itemSnapshot.exists) {
        throw StateError('Item is no longer part of this Activity.');
      }

      final activityData = activitySnapshot.data();
      ActivityStatusPolicy.requireItemRemoval(activityData?['status'] as String?);
      final currentItemState = _requireActivityItemState(activityData);
      ActivityStatusPolicy.requireItemCountForRemoval(currentItemState.count);

      final now = DateTime.now();
      if (draftSnapshot.exists) {
        final draftData = draftSnapshot.data();
        final methods = <String, String>{};
        final rawMethods = draftData?['foundMethods'];

        if (rawMethods is Map) {
          for (final entry in rawMethods.entries) {
            if (entry.key is String &&
                (entry.value == 'QR' || entry.value == 'MANUAL')) {
              methods[entry.key as String] = entry.value as String;
            }
          }
        }

        methods.remove(itemId);

        transaction.update(draftDocument, {
          'foundMethods': methods,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      transaction.delete(itemDocument);
      transaction.update(activityDocument, {
        'itemCount': currentItemState.count - 1,
        'itemRevision': currentItemState.revision + 1,
        'itemMutationId': itemId,
        'itemMutationType': 'REMOVE',
        'updatedAt': Timestamp.fromDate(now),
      });
    });
  }

  @override
  Future<Activity> addActivityWithItems({
    required Activity activity,
    required List<Item> items,
  }) async {
    ActivityStatusPolicy.requireNew(activity.status);

    final uniqueItems = <String, Item>{
      for (final item in items) item.id: item,
    }.values.toList();
    if (uniqueItems.isEmpty) {
      throw StateError('An Activity must contain at least one Item.');
    }
    if (uniqueItems.length > 200) {
      throw StateError('An Activity can contain at most 200 Items.');
    }

    final activityDocument = _activitiesCollection.doc();
    final now = DateTime.now();
    final newActivity = activity.copyWith(
      id: activityDocument.id,
      createdAt: now,
      updatedAt: now,
    );

    final batch = firestore.batch();
    batch.set(
      activityDocument,
      _activityToMap(
        newActivity,
        now,
        itemCount: uniqueItems.length,
        itemRevision: 0,
      ),
    );

    for (final item in uniqueItems) {
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
    final activityDocument = _activitiesCollection.doc(activity.id);

    await firestore.runTransaction((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final currentStatus = activitySnapshot.data()?['status'] as String?;
      ActivityStatusPolicy.requireMetadataEdit(currentStatus);

      if (activity.status != currentStatus) {
        throw StateError(
          'Activity status changed. Reopen the Activity and try again.',
        );
      }

      final updates = <String, dynamic>{
        'name': activity.name.trim(),
        'type': activity.type,
        'endAt': Timestamp.fromDate(activity.endAt),
        'reminderEnabled': activity.reminderEnabled,
        'reminderMinutes': activity.reminderMinutes,
        'updatedAt': Timestamp.now(),
      };

      // Once an Activity is ACTIVE, its original date/start time is history.
      if (currentStatus == 'UPCOMING') {
        updates['activityDate'] = Timestamp.fromDate(activity.activityDate);
        updates['startAt'] = Timestamp.fromDate(activity.startAt);
      }

      transaction.update(activityDocument, updates);
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

  Future<_ActivityItemState> _ensureActivityItemState(
    String activityId,
  ) async {
    final activityDocument = _activitiesCollection.doc(activityId);
    final firstSnapshot = await activityDocument.get();
    if (!firstSnapshot.exists) {
      throw StateError('Activity no longer exists.');
    }

    final existingState = _activityItemStateFromData(firstSnapshot.data());
    if (existingState != null) {
      return existingState;
    }

    // Legacy Activities predate itemCount/itemRevision. New rules block Item
    // mutations until this one-time state initialization is completed, so the
    // collection count remains stable while it is measured.
    final itemsSnapshot = await _activityItemsCollection(activityId).get();
    final itemCount = itemsSnapshot.docs.length;
    if (itemCount < 1) {
      throw StateError('An Activity must contain at least one Item.');
    }
    if (itemCount > 200) {
      throw StateError('An Activity can contain at most 200 Items.');
    }

    return firestore.runTransaction<_ActivityItemState>((transaction) async {
      final activitySnapshot = await transaction.get(activityDocument);
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final activityData = activitySnapshot.data();
      final concurrentState = _activityItemStateFromData(activityData);
      if (concurrentState != null) {
        return concurrentState;
      }

      ActivityStatusPolicy.requireEditable(activityData?['status'] as String?);
      transaction.update(activityDocument, {
        'itemCount': itemCount,
        'itemRevision': 0,
        'updatedAt': Timestamp.now(),
      });

      return _ActivityItemState(count: itemCount, revision: 0);
    });
  }

  _ActivityItemState? _activityItemStateFromData(
    Map<String, dynamic>? data,
  ) {
    final count = data?['itemCount'];
    final revision = data?['itemRevision'];
    if (count is int && revision is int) {
      return _ActivityItemState(count: count, revision: revision);
    }
    return null;
  }

  _ActivityItemState _requireActivityItemState(Map<String, dynamic>? data) {
    final state = _activityItemStateFromData(data);
    if (state == null || state.count < 1 || state.revision < 0) {
      throw StateError('Activity Item state is invalid. Reopen the Activity.');
    }
    return state;
  }

  void _requireUniqueActivityItems(List<ActivityItem> activityItems) {
    final uniqueIds = activityItems.map((item) => item.id).toSet();
    if (uniqueIds.length != activityItems.length) {
      throw StateError(
        'Activity Items changed. Review the refreshed list and try again.',
      );
    }
  }

  Map<String, dynamic> _activityToMap(
    Activity activity,
    DateTime now, {
    required int itemCount,
    required int itemRevision,
  }) {
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

      'itemCount': itemCount,

      'itemRevision': itemRevision,

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
