import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../domain/packing.dart';

class PackingRepository {
  final FirebaseFirestore firestore;
  final String userId;
  PackingRepository({required this.userId, FirebaseFirestore? firestore})
    : firestore = firestore ?? FirebaseFirestore.instance;
  // Isolate the rebuilt schema from the unavailable app's existing records.
  DocumentReference<Map<String, dynamic>> get _user =>
      firestore.collection('lakwatsa_v2_users').doc(userId);
  CollectionReference<Map<String, dynamic>> get _items =>
      _user.collection('items');
  CollectionReference<Map<String, dynamic>> get _lists =>
      _user.collection('lists');
  CollectionReference<Map<String, dynamic>> get _activities =>
      _user.collection('activities');
  String newId() => const Uuid().v4();

  Stream<List<Belonging>> watchItems() => _items.snapshots().map(
    (s) =>
        s.docs.map((d) => Belonging.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );
  Stream<List<PackingList>> watchLists() => _lists.snapshots().map(
    (s) =>
        s.docs.map((d) => PackingList.fromMap(d.id, d.data())).toList()
          ..sort((a, b) => a.name.compareTo(b.name)),
  );
  Stream<List<PackingActivity>> watchActivities() =>
      _activities.snapshots().map(
        (s) =>
            s.docs.map((d) => PackingActivity.fromMap(d.id, d.data())).toList()
              ..sort((a, b) => b.startsAt.compareTo(a.startsAt)),
      );
  Stream<PackingActivity?> watchActivity(String id) => _activities
      .doc(id)
      .snapshots()
      .map((d) => d.exists ? PackingActivity.fromMap(d.id, d.data()!) : null);

  Future<void> saveItem(Belonging item) => _items
      .doc(item.id)
      .set(item.toMap())
      .timeout(const Duration(seconds: 20));
  // Archiving preserves references in existing lists and activity history.
  Future<void> archiveItem(String id, bool archived) => _items
      .doc(id)
      .update({'archived': archived})
      .timeout(const Duration(seconds: 20));
  Future<void> saveList(PackingList list) => _lists
      .doc(list.id)
      .set(list.toMap())
      .timeout(const Duration(seconds: 20));
  Future<void> deleteList(String id) =>
      _lists.doc(id).delete().timeout(const Duration(seconds: 20));
  Future<Belonging?> getItem(String id) async {
    final doc = await _items.doc(id).get();
    return doc.exists ? Belonging.fromMap(doc.id, doc.data()!) : null;
  }

  Future<void> createActivity(PackingActivity activity) async {
    if (activity.status != ActivityStatus.planned ||
        activity.before != null ||
        activity.returned != null) {
      throw StateError('New activities must start as planned.');
    }
    if (!activity.endsAt.isAfter(DateTime.now())) {
      throw ArgumentError('Choose a future end time.');
    }
    await firestore.runTransaction((tx) async {
      final ref = _activities.doc(activity.id);
      if ((await tx.get(ref)).exists) {
        throw StateError('This activity already exists.');
      }
      tx.set(ref, activity.toMap());
    });
  }

  Future<void> markItem(
    String activityId,
    ActivityStatus expectedStatus,
    String itemId,
    CheckMethod? method, {
    Belonging? addition,
  }) async {
    await firestore.runTransaction((tx) async {
      final ref = _activities.doc(activityId);
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Activity no longer exists.');
      final activity = PackingActivity.fromMap(doc.id, doc.data()!);
      if (!activity.editable || activity.status != expectedStatus) {
        throw StateError('Activity changed. Reopen it before checking items.');
      }
      final items = Map<String, PackedItem>.from(activity.items);
      if (!items.containsKey(itemId)) {
        if (addition == null ||
            addition.id != itemId ||
            addition.archived ||
            items.length >= 200) {
          throw StateError('This item cannot be added to the activity.');
        }
        // Recheck ownership/existence inside the transaction.
        final owned = await tx.get(_items.doc(itemId));
        if (!owned.exists || owned.data()!['archived'] == true) {
          throw StateError('Item is unavailable.');
        }
        final item = Belonging.fromMap(owned.id, owned.data()!);
        items[itemId] = PackedItem(
          id: itemId,
          name: item.name,
          category: item.category,
          quantity: item.quantity,
          addedDuringActivity: true,
        );
      }
      final draft = Map<String, CheckMethod>.from(activity.draft);
      if (method == null) {
        draft.remove(itemId);
      } else {
        draft[itemId] = method;
      }
      tx.set(ref, {
        ...activity.toMap(),
        'items': items.map((id, item) => MapEntry(id, item.toMap())),
        'draft': draft.map((id, method) => MapEntry(id, method.name)),
        'draftStartedAt': (activity.draftStartedAt ?? DateTime.now())
            .toUtc()
            .toIso8601String(),
      });
    });
  }

  Future<void> completeCheck(PackingActivity expected) async {
    await firestore.runTransaction((tx) async {
      final ref = _activities.doc(expected.id);
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Activity no longer exists.');
      final current = PackingActivity.fromMap(doc.id, doc.data()!);
      if (!current.editable || current.status != expected.status) {
        throw StateError('This check was already completed or cancelled.');
      }
      // Do not commit a result different from the user's confirmation dialog.
      if (current.items.length != expected.items.length ||
          current.draft.length != expected.draft.length ||
          current.items.keys.any((id) => !expected.items.containsKey(id)) ||
          current.draft.entries.any((e) => expected.draft[e.key] != e.value)) {
        throw StateError(
          'The check changed on another device. Review and finish again.',
        );
      }
      final now = DateTime.now();
      final check = CheckRecord(
        startedAt: current.draftStartedAt ?? now,
        completedAt: now,
        itemIds: current.items.keys.toList(),
        found: current.draft,
      );
      final isBefore = current.status == ActivityStatus.planned;
      tx.set(ref, {
        ...current.toMap(),
        isBefore ? 'before' : 'returned': check.toMap(),
        'status': isBefore ? 'active' : 'completed',
        'draft': <String, String>{},
        'draftStartedAt': null,
      });
    });
  }

  Future<void> cancelActivity(String id) =>
      _changeOpenActivity(id, (_) => {'status': 'cancelled'});
  Future<void> reschedule(String id, DateTime end, int minutes) =>
      _changeOpenActivity(id, (activity) {
        if (!end.isAfter(DateTime.now()) ||
            !end.isAfter(activity.startsAt) ||
            minutes < 0 ||
            minutes > 1440) {
          throw ArgumentError(
            'Choose a future end after the start, and a valid reminder.',
          );
        }
        return {
          'endsAt': end.toUtc().toIso8601String(),
          'reminderMinutes': minutes,
          'reminderUpdatedAt': DateTime.now().toUtc().toIso8601String(),
        };
      });
  Future<void> _changeOpenActivity(
    String id,
    Map<String, dynamic> Function(PackingActivity) change,
  ) async {
    await firestore.runTransaction((tx) async {
      final ref = _activities.doc(id);
      final doc = await tx.get(ref);
      if (!doc.exists) throw StateError('Activity no longer exists.');
      final activity = PackingActivity.fromMap(id, doc.data()!);
      if (!activity.editable) {
        throw StateError(
          'Completed and cancelled activities cannot be changed.',
        );
      }
      tx.update(ref, change(activity));
    });
  }
}
