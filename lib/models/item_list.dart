class ItemList {
  final String id;
  final String name;
  final String icon;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ItemList({
    required this.id,
    required this.name,
    required this.icon,
    this.createdAt,
    this.updatedAt,
  });

  ItemList copyWith({
    String? id,
    String? name,
    String? icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ItemList(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory ItemList.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return ItemList(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? 'list',
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }
}