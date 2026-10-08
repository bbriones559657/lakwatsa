import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/activity.dart';
import 'package:lakwatsa/models/activity_item.dart';
import 'package:lakwatsa/models/item.dart';

void main() {
  group('Item', () {
    test('editing an item preserves its identity and QR code', () {
      const original = Item(
        id: 'item-1',
        name: 'Laptop',
        category: 'Electronics',
        quantity: 1,
        icon: 'electronics',
        qrCode: 'lakwatsa:item:example',
      );

      final updated = original.copyWith(name: 'School laptop', quantity: 2);

      expect(updated.id, 'item-1');
      expect(updated.name, 'School laptop');
      expect(updated.quantity, 2);
      expect(updated.qrCode, original.qrCode);
      expect(updated.hasQr, isTrue);
    });

    test('missing optional map values get reasonable defaults', () {
      final item = Item.fromMap(id: 'item-2', data: {'name': 'Charger'});

      expect(item.category, 'Other');
      expect(item.quantity, 1);
      expect(item.icon, 'inventory');
      expect(item.hasQr, isFalse);
    });
  });

  test('Activity status helpers track status changes', () {
    final start = DateTime(2026, 10, 4, 8);
    final original = Activity(
      id: 'activity-1',
      listId: 'list-1',
      name: 'School',
      type: 'School',
      activityDate: start,
      startAt: start,
      endAt: DateTime(2026, 10, 4, 17),
      reminderEnabled: false,
      reminderMinutes: 30,
      status: 'UPCOMING',
    );

    expect(original.isUpcoming, isTrue);
    expect(original.isActive, isFalse);
    expect(original.copyWith(status: 'ACTIVE').isActive, isTrue);
    expect(original.copyWith(status: 'COMPLETED').isCompleted, isTrue);

    final cancelled = original.copyWith(status: 'CANCELLED');
    expect(cancelled.isCancelled, isTrue);
    expect(cancelled.isFinished, isTrue);
    expect(original.copyWith(status: 'COMPLETED').isFinished, isTrue);
  });

  test('ActivityItem QR availability follows its snapshot', () {
    const noQr = ActivityItem(
      id: 'activity-item-1',
      itemId: 'item-1',
      itemName: 'Notebook',
      category: 'School',
      quantity: 1,
      icon: 'inventory',
      addedDuringActivity: false,
    );
    const withQr = ActivityItem(
      id: 'activity-item-2',
      itemId: 'item-2',
      itemName: 'Laptop',
      category: 'Electronics',
      quantity: 1,
      icon: 'electronics',
      qrCode: 'lakwatsa:item:example',
      addedDuringActivity: true,
    );

    expect(noQr.hasQr, isFalse);
    expect(withQr.hasQr, isTrue);
    expect(withQr.addedDuringActivity, isTrue);
  });
}
