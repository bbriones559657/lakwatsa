import 'package:flutter/material.dart';

class ListIconOption {
  final String key;
  final String label;
  final String category;
  final IconData icon;
  final List<String> searchTerms;

  const ListIconOption({
    required this.key,
    required this.label,
    required this.category,
    required this.icon,
    this.searchTerms = const [],
  });

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();

    if (normalized.isEmpty) {
      return true;
    }

    return key.toLowerCase().contains(normalized) ||
        label.toLowerCase().contains(normalized) ||
        category.toLowerCase().contains(normalized) ||
        searchTerms.any((term) => term.toLowerCase().contains(normalized));
  }
}

const listIconCategories = <String>[
  'Travel',
  'School',
  'Work',
  'Fitness',
  'Daily',
  'Other',
];

const listIconOptions = <ListIconOption>[
  ListIconOption(
    key: 'beach',
    label: 'Beach',
    category: 'Travel',
    icon: Icons.beach_access,
    searchTerms: ['vacation', 'summer'],
  ),
  ListIconOption(
    key: 'flight',
    label: 'Flight',
    category: 'Travel',
    icon: Icons.flight,
    searchTerms: ['plane', 'airport', 'trip'],
  ),
  ListIconOption(
    key: 'luggage',
    label: 'Luggage',
    category: 'Travel',
    icon: Icons.luggage_outlined,
    searchTerms: ['suitcase', 'travel', 'bag'],
  ),
  ListIconOption(
    key: 'car',
    label: 'Car',
    category: 'Travel',
    icon: Icons.directions_car_outlined,
    searchTerms: ['drive', 'road', 'vehicle'],
  ),
  ListIconOption(
    key: 'boat',
    label: 'Boat',
    category: 'Travel',
    icon: Icons.directions_boat_outlined,
    searchTerms: ['ship', 'sea', 'ferry'],
  ),
  ListIconOption(
    key: 'map',
    label: 'Map',
    category: 'Travel',
    icon: Icons.map_outlined,
    searchTerms: ['route', 'place', 'travel'],
  ),
  ListIconOption(
    key: 'hotel',
    label: 'Hotel',
    category: 'Travel',
    icon: Icons.hotel_outlined,
    searchTerms: ['stay', 'room', 'lodging'],
  ),
  ListIconOption(
    key: 'explore',
    label: 'Explore',
    category: 'Travel',
    icon: Icons.explore_outlined,
    searchTerms: ['adventure', 'trip', 'compass'],
  ),
  ListIconOption(
    key: 'school',
    label: 'School',
    category: 'School',
    icon: Icons.school_outlined,
    searchTerms: ['class', 'study', 'college'],
  ),
  ListIconOption(
    key: 'book',
    label: 'Books',
    category: 'School',
    icon: Icons.menu_book_outlined,
    searchTerms: ['read', 'study'],
  ),
  ListIconOption(
    key: 'book_alt',
    label: 'Book',
    category: 'School',
    icon: Icons.book_outlined,
    searchTerms: ['read', 'notes'],
  ),
  ListIconOption(
    key: 'notes',
    label: 'Notes',
    category: 'School',
    icon: Icons.edit_note_outlined,
    searchTerms: ['write', 'paper'],
  ),
  ListIconOption(
    key: 'backpack',
    label: 'Backpack',
    category: 'School',
    icon: Icons.backpack_outlined,
    searchTerms: ['bag', 'school', 'travel'],
  ),
  ListIconOption(
    key: 'science',
    label: 'Science',
    category: 'School',
    icon: Icons.science_outlined,
    searchTerms: ['lab', 'class'],
  ),
  ListIconOption(
    key: 'calculator',
    label: 'Calculator',
    category: 'School',
    icon: Icons.calculate_outlined,
    searchTerms: ['math', 'numbers'],
  ),
  ListIconOption(
    key: 'computer',
    label: 'Computer',
    category: 'School',
    icon: Icons.computer_outlined,
    searchTerms: ['pc', 'technology'],
  ),
  ListIconOption(
    key: 'work',
    label: 'Work',
    category: 'Work',
    icon: Icons.work_outline,
    searchTerms: ['job', 'office'],
  ),
  ListIconOption(
    key: 'briefcase',
    label: 'Briefcase',
    category: 'Work',
    icon: Icons.business_center_outlined,
    searchTerms: ['office', 'business'],
  ),
  ListIconOption(
    key: 'folder',
    label: 'Folder',
    category: 'Work',
    icon: Icons.folder_outlined,
    searchTerms: ['files', 'documents'],
  ),
  ListIconOption(
    key: 'laptop',
    label: 'Laptop',
    category: 'Work',
    icon: Icons.laptop_mac_outlined,
    searchTerms: ['computer', 'device'],
  ),
  ListIconOption(
    key: 'desktop',
    label: 'Desktop',
    category: 'Work',
    icon: Icons.desktop_windows_outlined,
    searchTerms: ['computer', 'pc'],
  ),
  ListIconOption(
    key: 'calendar',
    label: 'Calendar',
    category: 'Work',
    icon: Icons.calendar_month_outlined,
    searchTerms: ['schedule', 'date', 'planner'],
  ),
  ListIconOption(
    key: 'assignment',
    label: 'Tasks',
    category: 'Work',
    icon: Icons.assignment_outlined,
    searchTerms: ['checklist', 'work'],
  ),
  ListIconOption(
    key: 'badge',
    label: 'Badge',
    category: 'Work',
    icon: Icons.badge_outlined,
    searchTerms: ['id', 'office'],
  ),
  ListIconOption(
    key: 'fitness',
    label: 'Fitness',
    category: 'Fitness',
    icon: Icons.fitness_center,
    searchTerms: ['gym', 'workout', 'exercise'],
  ),
  ListIconOption(
    key: 'running',
    label: 'Running',
    category: 'Fitness',
    icon: Icons.directions_run,
    searchTerms: ['run', 'jog'],
  ),
  ListIconOption(
    key: 'bike',
    label: 'Cycling',
    category: 'Fitness',
    icon: Icons.directions_bike,
    searchTerms: ['bike', 'bicycle'],
  ),
  ListIconOption(
    key: 'soccer',
    label: 'Soccer',
    category: 'Fitness',
    icon: Icons.sports_soccer_outlined,
    searchTerms: ['football', 'sport'],
  ),
  ListIconOption(
    key: 'basketball',
    label: 'Basketball',
    category: 'Fitness',
    icon: Icons.sports_basketball_outlined,
    searchTerms: ['ball', 'sport'],
  ),
  ListIconOption(
    key: 'tennis',
    label: 'Tennis',
    category: 'Fitness',
    icon: Icons.sports_tennis_outlined,
    searchTerms: ['racket', 'sport'],
  ),
  ListIconOption(
    key: 'swimming',
    label: 'Swimming',
    category: 'Fitness',
    icon: Icons.pool_outlined,
    searchTerms: ['pool', 'swim'],
  ),
  ListIconOption(
    key: 'sports',
    label: 'Sports',
    category: 'Fitness',
    icon: Icons.sports_outlined,
    searchTerms: ['game', 'athletics'],
  ),
  ListIconOption(
    key: 'home',
    label: 'Home',
    category: 'Daily',
    icon: Icons.home_outlined,
    searchTerms: ['house', 'daily'],
  ),
  ListIconOption(
    key: 'shopping_bag',
    label: 'Shopping Bag',
    category: 'Daily',
    icon: Icons.shopping_bag_outlined,
    searchTerms: ['shop', 'store'],
  ),
  ListIconOption(
    key: 'cart',
    label: 'Shopping Cart',
    category: 'Daily',
    icon: Icons.shopping_cart_outlined,
    searchTerms: ['shop', 'grocery'],
  ),
  ListIconOption(
    key: 'food',
    label: 'Food',
    category: 'Daily',
    icon: Icons.restaurant_outlined,
    searchTerms: ['meal', 'restaurant'],
  ),
  ListIconOption(
    key: 'coffee',
    label: 'Coffee',
    category: 'Daily',
    icon: Icons.local_cafe_outlined,
    searchTerms: ['cafe', 'drink'],
  ),
  ListIconOption(
    key: 'grocery',
    label: 'Groceries',
    category: 'Daily',
    icon: Icons.local_grocery_store_outlined,
    searchTerms: ['food', 'shopping', 'market'],
  ),
  ListIconOption(
    key: 'cleaning',
    label: 'Cleaning',
    category: 'Daily',
    icon: Icons.cleaning_services_outlined,
    searchTerms: ['chores', 'home'],
  ),
  ListIconOption(
    key: 'pets',
    label: 'Pets',
    category: 'Daily',
    icon: Icons.pets_outlined,
    searchTerms: ['dog', 'cat', 'animal'],
  ),
  ListIconOption(
    key: 'list',
    label: 'General List',
    category: 'Other',
    icon: Icons.list_alt_outlined,
    searchTerms: ['checklist', 'general'],
  ),
  ListIconOption(
    key: 'star',
    label: 'Star',
    category: 'Other',
    icon: Icons.star_outline,
    searchTerms: ['favorite', 'important'],
  ),
  ListIconOption(
    key: 'heart',
    label: 'Heart',
    category: 'Other',
    icon: Icons.favorite_border,
    searchTerms: ['favorite', 'love'],
  ),
  ListIconOption(
    key: 'event',
    label: 'Event',
    category: 'Other',
    icon: Icons.event_outlined,
    searchTerms: ['calendar', 'occasion'],
  ),
  ListIconOption(
    key: 'gift',
    label: 'Gift',
    category: 'Other',
    icon: Icons.card_giftcard_outlined,
    searchTerms: ['present', 'birthday'],
  ),
  ListIconOption(
    key: 'camera',
    label: 'Camera',
    category: 'Other',
    icon: Icons.camera_alt_outlined,
    searchTerms: ['photo', 'photography'],
  ),
  ListIconOption(
    key: 'music',
    label: 'Music',
    category: 'Other',
    icon: Icons.music_note_outlined,
    searchTerms: ['audio', 'song'],
  ),
  ListIconOption(
    key: 'more',
    label: 'Other',
    category: 'Other',
    icon: Icons.more_horiz,
    searchTerms: ['misc', 'miscellaneous'],
  ),
];

List<ListIconOption> searchListIconOptions(String query) {
  return listIconOptions.where((option) => option.matches(query)).toList();
}

IconData listIconDataForKey(String key) {
  for (final option in listIconOptions) {
    if (option.key == key) {
      return option.icon;
    }
  }

  return Icons.list_alt_outlined;
}

String listIconLabelForKey(String key) {
  for (final option in listIconOptions) {
    if (option.key == key) {
      return option.label;
    }
  }

  return 'General List';
}
