enum ActivityStatus { planned, active, completed, cancelled }

enum CheckMethod { manual, qr }

String requiredName(String value) {
  final name = value.trim();
  if (name.isEmpty || name.length > 100) {
    throw ArgumentError('Use a name between 1 and 100 characters.');
  }
  return name;
}

class Belonging {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final bool archived;

  Belonging({
    required this.id,
    required String name,
    required this.category,
    required this.quantity,
    this.archived = false,
  }) : name = requiredName(name) {
    if (quantity < 1 || quantity > 999) {
      throw ArgumentError('Quantity must be between 1 and 999.');
    }
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'archived': archived,
  };

  factory Belonging.fromMap(String id, Map<String, dynamic> map) => Belonging(
    id: id,
    name: map['name'] as String,
    category: map['category'] as String,
    quantity: map['quantity'] as int,
    archived: map['archived'] == true,
  );
}

class PackingList {
  final String id;
  final String name;
  final Map<String, int> quantities;
  PackingList({
    required this.id,
    required String name,
    required Map<String, int> quantities,
  }) : name = requiredName(name),
       quantities = Map.unmodifiable(quantities) {
    if (quantities.length > 200 ||
        quantities.values.any((q) => q < 1 || q > 999)) {
      throw ArgumentError('Use up to 200 items with quantities from 1 to 999.');
    }
  }
  Map<String, dynamic> toMap() => {'name': name, 'quantities': quantities};
  factory PackingList.fromMap(String id, Map<String, dynamic> map) =>
      PackingList(
        id: id,
        name: map['name'] as String,
        quantities: Map<String, int>.from(map['quantities'] as Map),
      );
}

class PackedItem {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final bool addedDuringActivity;
  const PackedItem({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    this.addedDuringActivity = false,
  });
  Map<String, dynamic> toMap() => {
    'name': name,
    'category': category,
    'quantity': quantity,
    'addedDuringActivity': addedDuringActivity,
  };
  factory PackedItem.fromMap(String id, Map<String, dynamic> map) => PackedItem(
    id: id,
    name: map['name'] as String,
    category: map['category'] as String,
    quantity: map['quantity'] as int,
    addedDuringActivity: map['addedDuringActivity'] == true,
  );
}

class CheckRecord {
  final DateTime startedAt;
  final DateTime completedAt;
  final List<String> itemIds;
  final Map<String, CheckMethod> found;
  CheckRecord({
    required this.startedAt,
    required this.completedAt,
    required List<String> itemIds,
    required Map<String, CheckMethod> found,
  }) : itemIds = List.unmodifiable(itemIds),
       found = Map.unmodifiable(found) {
    if (found.keys.any((id) => !itemIds.contains(id))) {
      throw ArgumentError('Check contains an item outside this activity.');
    }
  }
  int get missingCount => itemIds.length - found.length;
  Map<String, dynamic> toMap() => {
    'startedAt': startedAt.toUtc().toIso8601String(),
    'completedAt': completedAt.toUtc().toIso8601String(),
    'itemIds': itemIds,
    'found': found.map((id, method) => MapEntry(id, method.name)),
  };
  factory CheckRecord.fromMap(Map<String, dynamic> map) => CheckRecord(
    startedAt: DateTime.parse(map['startedAt'] as String),
    completedAt: DateTime.parse(map['completedAt'] as String),
    itemIds: List<String>.from(map['itemIds'] as List),
    found: readMethods(map['found']),
  );
}

Map<String, CheckMethod> readMethods(dynamic value) =>
    Map<String, dynamic>.from(value as Map? ?? {}).map(
      (id, method) => MapEntry(id, CheckMethod.values.byName(method as String)),
    );

class PackingActivity {
  final String id;
  final String name;
  final String type;
  final ActivityStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final int reminderMinutes;
  final Map<String, PackedItem> items;
  final CheckRecord? before;
  final CheckRecord? returned;
  final Map<String, CheckMethod> draft;
  final DateTime? draftStartedAt;
  final DateTime? reminderUpdatedAt;

  PackingActivity({
    required this.id,
    required String name,
    required this.type,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.reminderMinutes,
    required Map<String, PackedItem> items,
    this.before,
    this.returned,
    Map<String, CheckMethod> draft = const {},
    this.draftStartedAt,
    this.reminderUpdatedAt,
  }) : name = requiredName(name),
       items = Map.unmodifiable(items),
       draft = Map.unmodifiable(draft) {
    if (!endsAt.isAfter(startsAt)) {
      throw ArgumentError('End must be after start.');
    }
    if (reminderMinutes < 0 || reminderMinutes > 1440) {
      throw ArgumentError('Reminder must be between 0 and 1440 minutes.');
    }
    if (items.isEmpty || items.length > 200) {
      throw ArgumentError('An activity needs between 1 and 200 items.');
    }
  }
  bool get editable =>
      status == ActivityStatus.planned || status == ActivityStatus.active;
  DateTime get reminderAt =>
      endsAt.subtract(Duration(minutes: reminderMinutes));
  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type,
    'status': status.name,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'reminderMinutes': reminderMinutes,
    'items': items.map((id, item) => MapEntry(id, item.toMap())),
    'before': before?.toMap(),
    'returned': returned?.toMap(),
    'draft': draft.map((id, method) => MapEntry(id, method.name)),
    'draftStartedAt': draftStartedAt?.toUtc().toIso8601String(),
    'reminderUpdatedAt': reminderUpdatedAt?.toUtc().toIso8601String(),
  };
  factory PackingActivity.fromMap(String id, Map<String, dynamic> map) =>
      PackingActivity(
        id: id,
        name: map['name'] as String,
        type: map['type'] as String,
        status: ActivityStatus.values.byName(map['status'] as String),
        startsAt: DateTime.parse(map['startsAt'] as String),
        endsAt: DateTime.parse(map['endsAt'] as String),
        reminderMinutes: map['reminderMinutes'] as int,
        reminderUpdatedAt: map['reminderUpdatedAt'] == null
            ? null
            : DateTime.parse(map['reminderUpdatedAt'] as String),
        items: Map<String, dynamic>.from(map['items'] as Map).map(
          (key, value) => MapEntry(
            key,
            PackedItem.fromMap(key, Map<String, dynamic>.from(value as Map)),
          ),
        ),
        before: map['before'] == null
            ? null
            : CheckRecord.fromMap(
                Map<String, dynamic>.from(map['before'] as Map),
              ),
        returned: map['returned'] == null
            ? null
            : CheckRecord.fromMap(
                Map<String, dynamic>.from(map['returned'] as Map),
              ),
        draft: readMethods(map['draft']),
        draftStartedAt: map['draftStartedAt'] == null
            ? null
            : DateTime.parse(map['draftStartedAt'] as String),
      );
}

String itemQrPayload(String ownerId, String itemId) => Uri(
  scheme: 'lakwatsa',
  host: 'item',
  pathSegments: [ownerId, itemId],
).toString();

String parseItemQr(String payload, String ownerId) {
  final uri = Uri.tryParse(payload);
  if (uri == null ||
      uri.scheme != 'lakwatsa' ||
      uri.host != 'item' ||
      uri.pathSegments.length != 2 ||
      uri.pathSegments.first != ownerId ||
      uri.pathSegments.last.isEmpty ||
      uri.pathSegments.last.contains('/') ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw const FormatException(
      'Scan a Lakwatsa item QR code belonging to your account.',
    );
  }
  return uri.pathSegments.last;
}
