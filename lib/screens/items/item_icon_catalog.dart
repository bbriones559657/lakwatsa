import 'package:flutter/material.dart';

class ItemIconOption {
  final String key;
  final String label;
  final IconData icon;
  final List<String> searchTerms;

  const ItemIconOption({
    required this.key,
    required this.label,
    required this.icon,
    this.searchTerms = const [],
  });

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;

    final haystack = <String>[
      key,
      label,
      ...searchTerms,
    ].join(' ').toLowerCase();

    return normalized
        .split(RegExp(r'\\s+'))
        .where((part) => part.isNotEmpty)
        .every(haystack.contains);
  }
}

const itemIconOptions = <ItemIconOption>[
  ItemIconOption(
    key: 'inventory',
    label: 'General',
    icon: Icons.inventory_2_outlined,
    searchTerms: ['item', 'box', 'storage', 'stuff'],
  ),
  ItemIconOption(
    key: 'star',
    label: 'Star',
    icon: Icons.star_outline,
    searchTerms: ['favorite', 'important', 'special'],
  ),
  ItemIconOption(
    key: 'favorite',
    label: 'Favorite',
    icon: Icons.favorite_border,
    searchTerms: ['heart', 'love', 'important'],
  ),
  ItemIconOption(
    key: 'gift',
    label: 'Gift',
    icon: Icons.redeem_outlined,
    searchTerms: ['present', 'box', 'reward'],
  ),
  ItemIconOption(
    key: 'bookmark',
    label: 'Bookmark',
    icon: Icons.bookmark_border,
    searchTerms: ['saved', 'important', 'marker'],
  ),
  ItemIconOption(
    key: 'electronics',
    label: 'Devices',
    icon: Icons.devices_outlined,
    searchTerms: ['electronics', 'tech', 'gadget'],
  ),
  ItemIconOption(
    key: 'laptop',
    label: 'Laptop',
    icon: Icons.laptop_mac,
    searchTerms: ['computer', 'macbook', 'notebook', 'electronics'],
  ),
  ItemIconOption(
    key: 'phone',
    label: 'Phone',
    icon: Icons.smartphone,
    searchTerms: ['mobile', 'smartphone', 'android', 'iphone'],
  ),
  ItemIconOption(
    key: 'camera',
    label: 'Camera',
    icon: Icons.photo_camera_outlined,
    searchTerms: ['photo', 'picture', 'photography'],
  ),
  ItemIconOption(
    key: 'camera_alt',
    label: 'Photo Camera',
    icon: Icons.camera_alt_outlined,
    searchTerms: ['camera', 'photo', 'picture', 'photography'],
  ),
  ItemIconOption(
    key: 'camera_front',
    label: 'Front Camera',
    icon: Icons.camera_front_outlined,
    searchTerms: ['camera', 'selfie', 'front', 'photo'],
  ),
  ItemIconOption(
    key: 'camera_rear',
    label: 'Rear Camera',
    icon: Icons.camera_rear_outlined,
    searchTerms: ['camera', 'rear', 'back', 'photo'],
  ),
  ItemIconOption(
    key: 'video_camera',
    label: 'Video Camera',
    icon: Icons.videocam_outlined,
    searchTerms: ['camera', 'video', 'camcorder', 'recording'],
  ),
  ItemIconOption(
    key: 'headphones',
    label: 'Headphones',
    icon: Icons.headphones,
    searchTerms: ['audio', 'music', 'earphones', 'headset'],
  ),
  ItemIconOption(
    key: 'charger',
    label: 'Charger',
    icon: Icons.battery_charging_full,
    searchTerms: ['power', 'charging', 'adapter', 'electronics'],
  ),
  ItemIconOption(
    key: 'battery',
    label: 'Battery',
    icon: Icons.battery_5_bar,
    searchTerms: ['power', 'charge', 'electronics'],
  ),
  ItemIconOption(
    key: 'cable',
    label: 'Cable',
    icon: Icons.cable,
    searchTerms: ['wire', 'usb', 'cord', 'electronics'],
  ),
  ItemIconOption(
    key: 'keyboard',
    label: 'Keyboard',
    icon: Icons.keyboard_outlined,
    searchTerms: ['computer', 'typing', 'electronics'],
  ),
  ItemIconOption(
    key: 'mouse',
    label: 'Mouse',
    icon: Icons.mouse_outlined,
    searchTerms: ['computer', 'pointer', 'electronics'],
  ),
  ItemIconOption(
    key: 'watch',
    label: 'Watch',
    icon: Icons.watch_outlined,
    searchTerms: ['clock', 'wearable', 'time'],
  ),
  ItemIconOption(
    key: 'passport',
    label: 'Passport',
    icon: Icons.badge_outlined,
    searchTerms: ['travel', 'document', 'identity'],
  ),
  ItemIconOption(
    key: 'id',
    label: 'ID Card',
    icon: Icons.credit_card,
    searchTerms: ['identity', 'card', 'license', 'document'],
  ),
  ItemIconOption(
    key: 'wallet',
    label: 'Wallet',
    icon: Icons.account_balance_wallet_outlined,
    searchTerms: ['money', 'cash', 'cards', 'everyday'],
  ),
  ItemIconOption(
    key: 'keys',
    label: 'Keys',
    icon: Icons.vpn_key_outlined,
    searchTerms: ['key', 'lock', 'house', 'car'],
  ),
  ItemIconOption(
    key: 'luggage',
    label: 'Luggage',
    icon: Icons.luggage,
    searchTerms: ['travel', 'suitcase', 'bag', 'trip'],
  ),
  ItemIconOption(
    key: 'backpack',
    label: 'Backpack',
    icon: Icons.backpack_outlined,
    searchTerms: ['bag', 'school', 'travel', 'pack'],
  ),
  ItemIconOption(
    key: 'umbrella',
    label: 'Umbrella',
    icon: Icons.umbrella_outlined,
    searchTerms: ['rain', 'weather', 'travel'],
  ),
  ItemIconOption(
    key: 'map',
    label: 'Map',
    icon: Icons.map_outlined,
    searchTerms: ['travel', 'location', 'navigation', 'trip'],
  ),
  ItemIconOption(
    key: 'beach',
    label: 'Beach',
    icon: Icons.beach_access,
    searchTerms: ['summer', 'vacation', 'travel', 'umbrella'],
  ),
  ItemIconOption(
    key: 'clothing',
    label: 'Clothing',
    icon: Icons.checkroom_outlined,
    searchTerms: ['shirt', 'jacket', 'clothes', 'wear'],
  ),
  ItemIconOption(
    key: 'toiletries',
    label: 'Care',
    icon: Icons.cleaning_services_outlined,
    searchTerms: ['facial', 'toiletry', 'hygiene', 'cleaning', 'skincare'],
  ),
  ItemIconOption(
    key: 'medicine',
    label: 'Medicine',
    icon: Icons.medication_outlined,
    searchTerms: ['medication', 'pills', 'health', 'medical'],
  ),
  ItemIconOption(
    key: 'first_aid',
    label: 'First Aid',
    icon: Icons.medical_services_outlined,
    searchTerms: ['medical', 'health', 'emergency', 'kit'],
  ),
  ItemIconOption(
    key: 'health',
    label: 'Health',
    icon: Icons.health_and_safety_outlined,
    searchTerms: ['medical', 'wellness', 'safety'],
  ),
  ItemIconOption(
    key: 'documents',
    label: 'Documents',
    icon: Icons.description_outlined,
    searchTerms: ['paper', 'file', 'document', 'forms'],
  ),
  ItemIconOption(
    key: 'book',
    label: 'Book',
    icon: Icons.menu_book_outlined,
    searchTerms: ['reading', 'school', 'study', 'textbook'],
  ),
  ItemIconOption(
    key: 'school',
    label: 'School',
    icon: Icons.school_outlined,
    searchTerms: ['class', 'study', 'college', 'education'],
  ),
  ItemIconOption(
    key: 'work',
    label: 'Work',
    icon: Icons.work_outline,
    searchTerms: ['office', 'job', 'business', 'briefcase'],
  ),
  ItemIconOption(
    key: 'notes',
    label: 'Notes',
    icon: Icons.sticky_note_2_outlined,
    searchTerms: ['paper', 'memo', 'school', 'work'],
  ),
  ItemIconOption(
    key: 'food',
    label: 'Food',
    icon: Icons.restaurant_outlined,
    searchTerms: ['meal', 'eat', 'snack', 'restaurant'],
  ),
  ItemIconOption(
    key: 'drink',
    label: 'Drink',
    icon: Icons.local_cafe_outlined,
    searchTerms: ['coffee', 'water', 'beverage', 'cup'],
  ),
  ItemIconOption(
    key: 'kitchen',
    label: 'Kitchen',
    icon: Icons.kitchen_outlined,
    searchTerms: ['food', 'cook', 'home'],
  ),
  ItemIconOption(
    key: 'home',
    label: 'Home',
    icon: Icons.home_outlined,
    searchTerms: ['house', 'room', 'personal'],
  ),
  ItemIconOption(
    key: 'water',
    label: 'Water',
    icon: Icons.water_drop_outlined,
    searchTerms: ['drink', 'bottle', 'hydration'],
  ),
  ItemIconOption(
    key: 'fitness',
    label: 'Fitness',
    icon: Icons.fitness_center,
    searchTerms: ['gym', 'exercise', 'workout', 'weights'],
  ),
  ItemIconOption(
    key: 'sports',
    label: 'Sports',
    icon: Icons.sports_basketball_outlined,
    searchTerms: ['ball', 'game', 'athletics'],
  ),
  ItemIconOption(
    key: 'pets',
    label: 'Pets',
    icon: Icons.pets_outlined,
    searchTerms: ['pet', 'dog', 'cat', 'animal'],
  ),
  ItemIconOption(
    key: 'baby',
    label: 'Baby',
    icon: Icons.child_friendly,
    searchTerms: ['child', 'kids', 'infant', 'family'],
  ),
  ItemIconOption(
    key: 'tools',
    label: 'Tools',
    icon: Icons.build_outlined,
    searchTerms: ['repair', 'equipment', 'hardware'],
  ),
  ItemIconOption(
    key: 'flashlight',
    label: 'Flashlight',
    icon: Icons.flashlight_on_outlined,
    searchTerms: ['torch', 'light', 'emergency'],
  ),
  ItemIconOption(
    key: 'tablet',
    label: 'Tablet',
    icon: Icons.tablet_mac,
    searchTerms: ['ipad', 'device', 'electronics', 'screen'],
  ),
  ItemIconOption(
    key: 'desktop',
    label: 'Desktop',
    icon: Icons.desktop_windows,
    searchTerms: ['computer', 'pc', 'monitor', 'electronics'],
  ),
  ItemIconOption(
    key: 'speaker',
    label: 'Speaker',
    icon: Icons.speaker,
    searchTerms: ['audio', 'music', 'sound', 'bluetooth'],
  ),
  ItemIconOption(
    key: 'earbuds',
    label: 'Earbuds',
    icon: Icons.earbuds,
    searchTerms: ['earphones', 'audio', 'music', 'wireless'],
  ),
  ItemIconOption(
    key: 'usb',
    label: 'USB',
    icon: Icons.usb,
    searchTerms: ['flash drive', 'storage', 'computer', 'electronics'],
  ),
  ItemIconOption(
    key: 'gamepad',
    label: 'Gaming',
    icon: Icons.sports_esports,
    searchTerms: ['game', 'controller', 'console', 'esports'],
  ),
  ItemIconOption(
    key: 'calculator',
    label: 'Calculator',
    icon: Icons.calculate,
    searchTerms: ['math', 'school', 'study', 'office'],
  ),
  ItemIconOption(
    key: 'pen',
    label: 'Pen',
    icon: Icons.edit,
    searchTerms: ['pencil', 'write', 'school', 'stationery'],
  ),
  ItemIconOption(
    key: 'folder',
    label: 'Folder',
    icon: Icons.folder_open,
    searchTerms: ['files', 'documents', 'school', 'work'],
  ),
  ItemIconOption(
    key: 'clipboard',
    label: 'Clipboard',
    icon: Icons.content_paste,
    searchTerms: ['checklist', 'notes', 'work', 'forms'],
  ),
  ItemIconOption(
    key: 'ticket',
    label: 'Ticket',
    icon: Icons.confirmation_number,
    searchTerms: ['travel', 'event', 'pass', 'booking'],
  ),
  ItemIconOption(
    key: 'car',
    label: 'Car',
    icon: Icons.directions_car,
    searchTerms: ['vehicle', 'drive', 'transport', 'travel'],
  ),
  ItemIconOption(
    key: 'bicycle',
    label: 'Bicycle',
    icon: Icons.pedal_bike,
    searchTerms: ['bike', 'cycling', 'transport', 'fitness'],
  ),
  ItemIconOption(
    key: 'plane',
    label: 'Plane',
    icon: Icons.flight,
    searchTerms: ['airplane', 'flight', 'airport', 'travel'],
  ),
  ItemIconOption(
    key: 'bus',
    label: 'Bus',
    icon: Icons.directions_bus,
    searchTerms: ['transport', 'commute', 'travel'],
  ),
  ItemIconOption(
    key: 'train',
    label: 'Train',
    icon: Icons.train,
    searchTerms: ['rail', 'transport', 'commute', 'travel'],
  ),
  ItemIconOption(
    key: 'bed',
    label: 'Bed',
    icon: Icons.bed,
    searchTerms: ['sleep', 'hotel', 'home', 'travel'],
  ),
  ItemIconOption(
    key: 'laundry',
    label: 'Laundry',
    icon: Icons.local_laundry_service,
    searchTerms: ['clothes', 'washing', 'cleaning', 'home'],
  ),
  ItemIconOption(
    key: 'soap',
    label: 'Soap',
    icon: Icons.soap,
    searchTerms: ['hygiene', 'bath', 'care', 'toiletries'],
  ),
  ItemIconOption(
    key: 'brush',
    label: 'Brush',
    icon: Icons.brush,
    searchTerms: ['makeup', 'art', 'paint', 'care'],
  ),
  ItemIconOption(
    key: 'glasses',
    label: 'Glasses',
    icon: Icons.visibility,
    searchTerms: ['eyeglasses', 'vision', 'eyes', 'accessory'],
  ),
  ItemIconOption(
    key: 'bottle',
    label: 'Bottle',
    icon: Icons.local_drink,
    searchTerms: ['water', 'drink', 'container', 'travel'],
  ),
  ItemIconOption(
    key: 'shopping_bag',
    label: 'Shopping Bag',
    icon: Icons.shopping_bag,
    searchTerms: ['shopping', 'grocery', 'bag', 'store'],
  ),
  ItemIconOption(
    key: 'shopping_cart',
    label: 'Shopping Cart',
    icon: Icons.shopping_cart,
    searchTerms: ['shopping', 'grocery', 'store', 'buy'],
  ),
  ItemIconOption(
    key: 'coffee',
    label: 'Coffee',
    icon: Icons.coffee,
    searchTerms: ['drink', 'cafe', 'mug', 'beverage'],
  ),
  ItemIconOption(
    key: 'camping',
    label: 'Camping',
    icon: Icons.terrain,
    searchTerms: ['camp', 'outdoor', 'mountain', 'travel'],
  ),
  ItemIconOption(
    key: 'hiking',
    label: 'Hiking',
    icon: Icons.hiking,
    searchTerms: ['walk', 'trail', 'outdoor', 'travel'],
  ),
  ItemIconOption(
    key: 'soccer',
    label: 'Soccer',
    icon: Icons.sports_soccer,
    searchTerms: ['football', 'ball', 'sports', 'game'],
  ),
  ItemIconOption(
    key: 'swimming',
    label: 'Swimming',
    icon: Icons.pool,
    searchTerms: ['pool', 'swim', 'water', 'sports'],
  ),
  ItemIconOption(
    key: 'music',
    label: 'Music',
    icon: Icons.music_note,
    searchTerms: ['song', 'audio', 'instrument', 'entertainment'],
  ),
  ItemIconOption(
    key: 'microphone',
    label: 'Microphone',
    icon: Icons.mic_none,
    searchTerms: ['mic', 'audio', 'recording', 'singing'],
  ),
  ItemIconOption(
    key: 'palette',
    label: 'Art',
    icon: Icons.palette,
    searchTerms: ['paint', 'drawing', 'creative', 'color'],
  ),
  ItemIconOption(
    key: 'lock',
    label: 'Lock',
    icon: Icons.lock_outline,
    searchTerms: ['security', 'safe', 'key', 'private'],
  ),
  ItemIconOption(
    key: 'money',
    label: 'Money',
    icon: Icons.payments,
    searchTerms: ['cash', 'finance', 'payment', 'budget'],
  ),
  ItemIconOption(
    key: 'receipt',
    label: 'Receipt',
    icon: Icons.receipt_long,
    searchTerms: ['purchase', 'bill', 'expense', 'shopping'],
  ),
  ItemIconOption(
    key: 'calendar',
    label: 'Calendar',
    icon: Icons.calendar_month,
    searchTerms: ['date', 'schedule', 'event', 'plan'],
  ),
  ItemIconOption(
    key: 'clock',
    label: 'Clock',
    icon: Icons.schedule,
    searchTerms: ['time', 'schedule', 'alarm', 'reminder'],
  ),
  ItemIconOption(
    key: 'sun',
    label: 'Sun',
    icon: Icons.wb_sunny,
    searchTerms: ['weather', 'summer', 'day', 'outdoor'],
  ),
  ItemIconOption(
    key: 'moon',
    label: 'Moon',
    icon: Icons.dark_mode,
    searchTerms: ['night', 'sleep', 'evening', 'travel'],
  ),
  ItemIconOption(
    key: 'plant',
    label: 'Plant',
    icon: Icons.local_florist,
    searchTerms: ['flower', 'garden', 'nature', 'home'],
  ),
];

List<ItemIconOption> searchItemIconOptions(String query) {
  return itemIconOptions.where((option) => option.matches(query)).toList();
}

String defaultItemIconKeyForCategory(String category) {
  switch (category.trim().toLowerCase()) {
    case 'electronics':
      return 'electronics';
    case 'documents':
      return 'documents';
    case 'clothing':
      return 'clothing';
    case 'toiletries':
      return 'toiletries';
    default:
      return 'inventory';
  }
}

IconData itemIconDataForKey(String key) {
  for (final option in itemIconOptions) {
    if (option.key == key) {
      return option.icon;
    }
  }

  // Preserve compatibility with older Item icon keys that already exist in
  // Firestore even if they are not shown as separate choices in the picker.
  switch (key) {
    case 'jacket':
    case 'shirt':
      return Icons.checkroom;
    case 'toothbrush':
      return Icons.cleaning_services_outlined;
    default:
      return Icons.inventory_2_outlined;
  }
}

String itemIconLabelForKey(String key) {
  for (final option in itemIconOptions) {
    if (option.key == key) {
      return option.label;
    }
  }

  switch (key) {
    case 'jacket':
      return 'Jacket';
    case 'shirt':
      return 'Shirt';
    case 'toothbrush':
      return 'Toothbrush';
    default:
      return 'Item icon';
  }
}
