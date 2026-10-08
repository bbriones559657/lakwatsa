import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/services/item_qr_export_service.dart';

void main() {
  group('QR export payload', () {
    test('preserves the stored QR payload exactly', () {
      const payload = '  lakwatsa:item:item-42  ';
      const item = Item(
        id: 'item-42',
        name: 'Passport',
        category: 'Documents',
        quantity: 1,
        icon: 'documents',
        qrCode: payload,
      );

      expect(ItemQrExportService.qrPayloadForExport(item), payload);
    });

    test('rejects a whitespace-only QR payload', () {
      const item = Item(
        id: 'blank',
        name: 'Blank',
        category: 'Documents',
        quantity: 1,
        icon: 'documents',
        qrCode: '   ',
      );

      expect(
        () => ItemQrExportService.qrPayloadForExport(item),
        throwsStateError,
      );
    });
  });
}
