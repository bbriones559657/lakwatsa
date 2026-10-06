class ItemCategory {
  static const int maxNameLength = 40;

  static const List<String> builtInNames = [
    'Electronics',
    'Documents',
    'Clothing',
    'Toiletries',
    'Other',
  ];

  static const List<String> reservedNames = ['All', ...builtInNames];

  final String id;
  final String name;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ItemCategory({
    required this.id,
    required this.name,
    this.createdAt,
    this.updatedAt,
  });

  bool get isBuiltIn => isBuiltInName(name);

  static bool isBuiltInName(String value) {
    final normalized = value.trim().toLowerCase();

    return builtInNames.any((name) => name.toLowerCase() == normalized);
  }

  static bool sameName(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  static String validateCustomName(String value) {
    final name = value.trim();

    if (name.isEmpty) {
      throw ArgumentError('Category name is required.');
    }

    if (name.length > maxNameLength) {
      throw ArgumentError(
        'Category name must be $maxNameLength characters or fewer.',
      );
    }

    if (name == '.' || name == '..' || name.contains('/')) {
      throw ArgumentError('Category name contains unsupported characters.');
    }

    final lowerName = name.toLowerCase();

    if (reservedNames.any((reserved) => reserved.toLowerCase() == lowerName)) {
      throw ArgumentError('"$name" is already a built-in category.');
    }

    return name;
  }

  static String documentIdForCustomName(String value) {
    return validateCustomName(value).toLowerCase();
  }
}
