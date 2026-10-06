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
  final Map<String, Map<String, dynamic>> manifest;

  const _ActivityItemState({
    required this.count,
    required this.revision,
    required this.manifest,
  });
}

class PartialActivityCreationException implements Exception {
  final String activityId;
  final Object cause;

  const PartialActivityCreationException(this.activityId, this.cause);

  @override
  String toString() =>
      'Activity $activityId was created, but some Items could not be added. '
      'Open it to add the remaining Items.';
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

    return _activityCheckDraftFromData(document.data());
  }

  @override
  Stream<ActivityCheckDraft?> watchCheckDraft({
    required String activityId,
    required String checkType,
  }) {
    return _draftDocument(
      activityId: activityId,
      checkType: checkType,
    ).snapshots().map((document) {
      return _activityCheckDraftFromData(document.data());
    });
  }

  @override
  Future<void> saveCheckDraft({
    required String activityId,
    required String checkType,
    required DateTime startedAt,
    required Map<String, String> foundMethods,
  }) async {
    await _ensureActivityItemState(activityId);

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

      final activityData = activitySnapshot.data();
      ActivityStatusPolicy.requireDraft(
        activityData?['status'] as String?,
        checkType,
      );
      final itemState = _requireActivityItemState(activityData);
      final allowedIds = itemState.manifest.keys.toSet();
      final sanitizedMethods = <String, String>{};
      for (final entry in foundMethods.entries) {
        if (allowedIds.contains(entry.key) &&
            (entry.value == 'QR' || entry.value == 'MANUAL')) {
          sanitizedMethods[entry.key] = entry.value;
        }
      }

      transaction.set(draftDocument, {
        // Drafts are not completed checks and do not appear in History.
        'type': 'DRAFT',
        'checkType': checkType,
        'status': 'IN_PROGRESS',
        'startedAt': Timestamp.fromDate(startedAt),
        'foundMethods': sanitizedMethods,
        'itemRevision': itemState.revision,
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
    final checkDocument = _activitiesCollection
        .doc(activityId)
        .collection('checks')
        .doc(checkId);
    final checkSnapshot = await checkDocument.get();
    final checkData = checkSnapshot.data();

    final manifestItems = _checkItemsFromCompletedCheck(checkData);
    if (manifestItems != null) {
      return manifestItems;
    }

    // Legacy completed checks stored each result only in a child collection.
    final snapshot = await checkDocument.collection('items').get();
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
    _requireActivityItemsMatchManifest(activityItems, expectedItemState);

    final activityDocument = _activitiesCollection.doc(activityId);
    final checkDocument = activityDocument.collection('checks').doc('return');
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
      _requireActivityItemsMatchManifest(activityItems, currentItemState);

      transaction.set(
        checkDocument,
        _completedCheckMap(
          type: 'RETURN',
          itemState: currentItemState,
          foundMethods: foundMethods,
          startedAt: startedAt,
          completedAt: now,
        ),
      );

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
    _requireActivityItemsMatchManifest(activityItems, expectedItemState);

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

      final activityData = activitySnapshot.data();
      ActivityStatusPolicy.requireBefore(activityData?['status'] as String?);
      final currentItemState = _requireActivityItemState(activityData);
      ActivityStatusPolicy.requireItemSnapshotForCheck(
        currentCount: currentItemState.count,
        currentRevision: currentItemState.revision,
        submittedCount: activityItems.length,
        expectedRevision: expectedItemState.revision,
      );
      _requireActivityItemsMatchManifest(activityItems, currentItemState);

      transaction.set(
        checkDocument,
        _completedCheckMap(
          type: 'BEFORE_ACTIVITY',
          itemState: currentItemState,
          foundMethods: foundMethods,
          startedAt: startedAt,
          completedAt: now,
        ),
      );

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

    final uniqueItems = <String, Item>{for (final item in items) item.id: item}
        .values
        .toList();
    final results = <ActivityItem>[];

    // Add one Item per transaction so Firestore Rules can tie every parent
    // count/revision change to the exact child document being created.
    for (final item in uniqueItems) {
      results.add(
        await _addSingleItemToActivity(activityId: activityId, item: item),
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
      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final activityData = activitySnapshot.data();
      final status = activityData?['status'] as String?;
      final addedDuringActivity = ActivityStatusPolicy.addedDuringActivityFor(
        status,
      );
      final currentItemState = _requireActivityItemState(activityData);

      final existing = currentItemState.manifest[item.id];
      if (existing != null) {
        return _activityItemFromMap(item.id, existing);
      }
      if (currentItemState.count >= 200) {
        throw StateError('An Activity can contain at most 200 Items.');
      }

      final now = DateTime.now();
      final itemMap = _activityItemMap(
        item: item,
        addedDuringActivity: addedDuringActivity,
        createdAt: now,
      );
      final nextManifest = <String, Map<String, dynamic>>{
        ...currentItemState.manifest,
        item.id: itemMap,
      };

      transaction.set(itemDocument, itemMap);
      transaction.update(activityDocument, {
        'itemCount': currentItemState.count + 1,
        'itemRevision': currentItemState.revision + 1,
        'itemManifest': nextManifest,
        'itemMutationId': item.id,
        'itemMutationType': 'ADD',
        'updatedAt': Timestamp.fromDate(now),
      });

      return _activityItemFromMap(item.id, itemMap);
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
      final draftSnapshot = await transaction.get(draftDocument);

      if (!activitySnapshot.exists) {
        throw StateError('Activity no longer exists.');
      }

      final activityData = activitySnapshot.data();
      ActivityStatusPolicy.requireItemRemoval(
        activityData?['status'] as String?,
      );
      final currentItemState = _requireActivityItemState(activityData);
      ActivityStatusPolicy.requireItemCountForRemoval(currentItemState.count);
      if (!currentItemState.manifest.containsKey(itemId)) {
        throw StateError('Item is no longer part of this Activity.');
      }

      final now = DateTime.now();
      final nextRevision = currentItemState.revision + 1;
      final nextManifest = <String, Map<String, dynamic>>{
        ...currentItemState.manifest,
      }..remove(itemId);

      if (draftSnapshot.exists) {
        final draftData = draftSnapshot.data();
        final methods = <String, String>{};
        final rawMethods = draftData?['foundMethods'];

        if (rawMethods is Map) {
          for (final entry in rawMethods.entries) {
            if (entry.key is String &&
                entry.key != itemId &&
                nextManifest.containsKey(entry.key) &&
                (entry.value == 'QR' || entry.value == 'MANUAL')) {
              methods[entry.key as String] = entry.value as String;
            }
          }
        }

        transaction.update(draftDocument, {
          'foundMethods': methods,
          'itemRevision': nextRevision,
          'updatedAt': Timestamp.fromDate(now),
        });
      }

      transaction.delete(itemDocument);
      transaction.update(activityDocument, {
        'itemCount': currentItemState.count - 1,
        'itemRevision': nextRevision,
        'itemManifest': nextManifest,
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

    final uniqueItems = <String, Item>{for (final item in items) item.id: item}
        .values
        .toList();
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

    final firstItem = uniqueItems.first;
    final firstItemData = _activityItemMap(
      item: firstItem,
      addedDuringActivity: false,
      createdAt: now,
    );
    final itemManifest = <String, Map<String, dynamic>>{
      firstItem.id: firstItemData,
    };

    final batch = firestore.batch();
    batch.set(
      activityDocument,
      _activityToMap(
        newActivity,
        now,
        itemCount: 1,
        itemRevision: 0,
        itemManifest: itemManifest,
      ),
    );

    batch.set(
      activityDocument.collection('items').doc(firstItem.id),
      firstItemData,
    );

    await batch.commit();
    if (uniqueItems.length > 1) {
      try {
        await addItemsToActivity(
          activityId: activityDocument.id,
          items: uniqueItems.skip(1).toList(),
        );
      } catch (error) {
        // The first Item is committed and the Activity remains valid. Surface
        // the partial result so a retry does not create a duplicate Activity.
        throw PartialActivityCreationException(activityDocument.id, error);
      }
    }
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
  Stream<List<ActivityItem>> watchActivityItems(String activityId) async* {
    final activityDocument = _activitiesCollection.doc(activityId);
    final initialActivity = await activityDocument.get();
    final initialState = _activityItemStateFromData(initialActivity.data());

    if (initialState != null) {
      // New and migrated Activities keep the authoritative Item snapshot on the
      // parent document so the Item set is rules-verifiable atomically.
      yield* activityDocument.snapshots().map((snapshot) {
        final state = _activityItemStateFromData(snapshot.data());
        if (state == null) return const <ActivityItem>[];
        return state.manifest.entries
            .map((entry) => _activityItemFromMap(entry.key, entry.value))
            .toList();
      });
      return;
    }

    // Legacy Activities remain readable, but require a trusted migration
    // before any Item mutation or check completion.
    yield* _activityItemsCollection(activityId).snapshots().map((snapshot) {
      return snapshot.docs.map((document) {
        return _activityItemFromDocument(document);
      }).toList();
    });
  }

  Future<_ActivityItemState> _ensureActivityItemState(String activityId) async {
    final activityDocument = _activitiesCollection.doc(activityId);
    final firstSnapshot = await activityDocument.get();
    if (!firstSnapshot.exists) {
      throw StateError('Activity no longer exists.');
    }

    final firstData = firstSnapshot.data();
    final existingState = _activityItemStateFromData(firstData);
    if (existingState != null) {
      return existingState;
    }

    // Client rules cannot verify a legacy subcollection's complete Item set.
    // Only a trusted server migration may install an authoritative manifest.
    throw StateError(
      'This older Activity needs a secure migration before checking or '
      'changing Items.',
    );
  }

  _ActivityItemState? _activityItemStateFromData(Map<String, dynamic>? data) {
    final count = data?['itemCount'];
    final revision = data?['itemRevision'];
    final rawManifest = data?['itemManifest'];
    if (count is! int || revision is! int || rawManifest is! Map) {
      return null;
    }

    final manifest = <String, Map<String, dynamic>>{};
    for (final entry in rawManifest.entries) {
      if (entry.key is! String || entry.value is! Map) {
        return null;
      }
      manifest[entry.key as String] = Map<String, dynamic>.from(
        entry.value as Map,
      );
    }
    if (count < 1 || count > 200 || revision < 0 || manifest.length != count) {
      return null;
    }

    return _ActivityItemState(
      count: count,
      revision: revision,
      manifest: manifest,
    );
  }

  _ActivityItemState _requireActivityItemState(Map<String, dynamic>? data) {
    final state = _activityItemStateFromData(data);
    if (state == null) {
      throw StateError('Activity Item state is invalid. Reopen the Activity.');
    }
    return state;
  }

  void _requireActivityItemsMatchManifest(
    List<ActivityItem> activityItems,
    _ActivityItemState itemState,
  ) {
    final submittedIds = activityItems.map((item) => item.id).toSet();
    final manifestIds = itemState.manifest.keys.toSet();
    if (submittedIds.length != activityItems.length ||
        submittedIds.length != manifestIds.length ||
        !submittedIds.containsAll(manifestIds)) {
      throw StateError(
        'Activity Items changed. Review the refreshed list and try again.',
      );
    }
  }

  Map<String, dynamic> _completedCheckMap({
    required String type,
    required _ActivityItemState itemState,
    required Map<String, String> foundMethods,
    required DateTime startedAt,
    required DateTime completedAt,
  }) {
    final itemIds = itemState.manifest.keys.toList();
    final allowedIds = itemIds.toSet();
    for (final entry in foundMethods.entries) {
      if (!allowedIds.contains(entry.key) ||
          (entry.value != 'MANUAL' && entry.value != 'QR')) {
        throw StateError(
          'Activity Items changed. Review the refreshed list and try again.',
        );
      }
    }

    final manualItemIds = <String>[];
    final qrItemIds = <String>[];
    final missingItemIds = <String>[];
    for (final itemId in itemIds) {
      final method = foundMethods[itemId];
      if (method == 'MANUAL') {
        manualItemIds.add(itemId);
      } else if (method == 'QR') {
        qrItemIds.add(itemId);
      } else {
        missingItemIds.add(itemId);
      }
    }

    return {
      'type': type,
      'startedAt': Timestamp.fromDate(startedAt),
      'completedAt': Timestamp.fromDate(completedAt),
      'status': 'COMPLETED',
      'itemCount': itemState.count,
      'itemRevision': itemState.revision,
      'itemIds': itemIds,
      'manualItemIds': manualItemIds,
      'qrItemIds': qrItemIds,
      'missingItemIds': missingItemIds,
    };
  }

  List<ActivityCheckItem>? _checkItemsFromCompletedCheck(
    Map<String, dynamic>? data,
  ) {
    final itemIds = _stringList(data?['itemIds']);
    final manualIds = _stringList(data?['manualItemIds']);
    final qrIds = _stringList(data?['qrItemIds']);
    final missingIds = _stringList(data?['missingItemIds']);
    if (itemIds == null ||
        manualIds == null ||
        qrIds == null ||
        missingIds == null) {
      return null;
    }

    final itemSet = itemIds.toSet();
    final manualSet = manualIds.toSet();
    final qrSet = qrIds.toSet();
    final missingSet = missingIds.toSet();
    if (itemSet.length != itemIds.length ||
        manualSet.length != manualIds.length ||
        qrSet.length != qrIds.length ||
        missingSet.length != missingIds.length ||
        !itemSet.containsAll(manualSet) ||
        !itemSet.containsAll(qrSet) ||
        !itemSet.containsAll(missingSet) ||
        manualSet.intersection(qrSet).isNotEmpty ||
        manualSet.intersection(missingSet).isNotEmpty ||
        qrSet.intersection(missingSet).isNotEmpty ||
        manualSet.length + qrSet.length + missingSet.length != itemSet.length) {
      return null;
    }

    final completedAt = _toDateTime(data?['completedAt']);
    return itemIds.map((itemId) {
      final isManual = manualSet.contains(itemId);
      final isQr = qrSet.contains(itemId);
      final found = isManual || isQr;
      return ActivityCheckItem(
        id: itemId,
        activityItemId: itemId,
        status: found ? 'FOUND' : 'NOT_FOUND',
        method: isManual ? 'MANUAL' : (isQr ? 'QR' : null),
        checkedAt: found ? completedAt : null,
      );
    }).toList();
  }

  ActivityCheckDraft? _activityCheckDraftFromData(
    Map<String, dynamic>? data,
  ) {
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

  List<String>? _stringList(dynamic raw) {
    if (raw is! List || raw.any((value) => value is! String)) return null;
    return raw.cast<String>();
  }

  Map<String, dynamic> _activityItemMap({
    required Item item,
    required bool addedDuringActivity,
    required DateTime createdAt,
  }) {
    return {
      'itemId': item.id,
      'itemName': item.name,
      'category': item.category,
      'quantity': item.quantity,
      'icon': item.icon,
      'photoUrl': item.photoUrl,
      'qrCode': item.qrCode,
      'addedDuringActivity': addedDuringActivity,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  ActivityItem _activityItemFromMap(String id, Map<String, dynamic> data) {
    return ActivityItem(
      id: id,
      itemId: data['itemId'] as String? ?? id,
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

  Map<String, dynamic> _activityToMap(
    Activity activity,
    DateTime now, {
    required int itemCount,
    required int itemRevision,
    required Map<String, Map<String, dynamic>> itemManifest,
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

      'itemManifest': itemManifest,

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
