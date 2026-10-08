class ItemCategory {
  static const int maxNameLength = 40;
  static const String defaultIconKey = 'inventory';

  static const List<String> allowedIconKeys = [
    'inventory',
    'star',
    'favorite',
    'gift',
    'bookmark',
    'electronics',
    'laptop',
    'phone',
    'camera',
    'camera_alt',
    'camera_front',
    'camera_rear',
    'video_camera',
    'headphones',
    'charger',
    'battery',
    'cable',
    'keyboard',
    'mouse',
    'watch',
    'passport',
    'id',
    'wallet',
    'keys',
    'luggage',
    'backpack',
    'umbrella',
    'map',
    'beach',
    'clothing',
    'toiletries',
    'medicine',
    'first_aid',
    'health',
    'documents',
    'book',
    'school',
    'work',
    'notes',
    'food',
    'drink',
    'kitchen',
    'home',
    'water',
    'fitness',
    'sports',
    'pets',
    'baby',
    'tools',
    'flashlight',
    'tablet',
    'desktop',
    'speaker',
    'earbuds',
    'usb',
    'gamepad',
    'calculator',
    'pen',
    'folder',
    'clipboard',
    'ticket',
    'car',
    'bicycle',
    'plane',
    'bus',
    'train',
    'bed',
    'laundry',
    'soap',
    'brush',
    'glasses',
    'bottle',
    'shopping_bag',
    'shopping_cart',
    'coffee',
    'camping',
    'hiking',
    'soccer',
    'swimming',
    'music',
    'microphone',
    'palette',
    'lock',
    'money',
    'receipt',
    'calendar',
    'clock',
    'sun',
    'moon',
    'plant',
  ];

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
  final String iconKey;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ItemCategory({
    required this.id,
    required this.name,
    this.iconKey = defaultIconKey,
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

  static String validateIconKey(String value) {
    final iconKey = value.trim();

    if (!allowedIconKeys.contains(iconKey)) {
      throw ArgumentError('Unsupported category icon.');
    }

    return iconKey;
  }

  static String documentIdForCustomName(String value) {
    return validateCustomName(value).toLowerCase();
  }
}
