class Item {
  final String id;
  final String name;
  final String category;
  final int quantity;
  final String icon;
  final String? photoUrl;
  final String? qrCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Item({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.icon,
    this.photoUrl,
    this.qrCode,
    this.createdAt,
    this.updatedAt,
  });

  bool get hasQr {
    return qrCode != null && qrCode!.isNotEmpty;
  }

  Item copyWith({
    String? id,
    String? name,
    String? category,
    int? quantity,
    String? icon,
    String? photoUrl,
    String? qrCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      quantity: quantity ?? this.quantity,
      icon: icon ?? this.icon,
      photoUrl: photoUrl ?? this.photoUrl,
      qrCode: qrCode ?? this.qrCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'quantity': quantity,
      'icon': icon,
      'photoUrl': photoUrl,
      'qrCode': qrCode,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory Item.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return Item(
      id: id,
      name: data['name'] ?? '',
      category: data['category'] ?? 'Other',
      quantity: data['quantity'] ?? 1,
      icon: data['icon'] ?? 'inventory',
      photoUrl: data['photoUrl'],
      qrCode: data['qrCode'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }
}