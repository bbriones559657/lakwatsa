import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/services/item_qr_export_service.dart';

void main() {
  group('ItemQrExportService filenames', () {
    test('creates a readable safe filename from an item name', () {
      expect(
        ItemQrExportService.fileStemForName('USB-C Charger / Work'),
        'lakwatsa_usb_c_charger_work_qr',
      );
    });

    test('falls back when the item name has no filename-safe characters', () {
      expect(
        ItemQrExportService.fileStemForName('   !!!   '),
        'lakwatsa_item_qr',
      );
    });

    test('limits very long filename tokens', () {
      final result = ItemQrExportService.fileStemForName(
        List.filled(80, 'A').join(),
      );

      expect(result.startsWith('lakwatsa_'), isTrue);
      expect(result.endsWith('_qr'), isTrue);
      expect(result.length, lessThanOrEqualTo(60));
    });
  });
}
