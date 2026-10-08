import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/services/item_qr_export_service.dart';

void main() {
  Item item(String id, String name) {
    return Item(
      id: id,
      name: name,
      category: 'Electronics',
      quantity: 1,
      icon: 'electronics',
      qrCode: 'lakwatsa:item:$id',
    );
  }

  group('bulk QR export helpers', () {
    test('duplicate item names receive unique PNG filenames', () {
      final names = ItemQrExportService.bulkPngFileNames([
        item('one', 'Charger'),
        item('two', 'Charger'),
        item('three', 'Passport'),
      ]);

      expect(names, [
        'lakwatsa_charger_qr.png',
        'lakwatsa_charger_qr_2.png',
        'lakwatsa_passport_qr.png',
      ]);
    });

    test('PDF sheet uses twelve compact tags per page', () {
      expect(ItemQrExportService.pdfSheetPageCountForItemCount(0), 0);
      expect(ItemQrExportService.pdfSheetPageCountForItemCount(1), 1);
      expect(ItemQrExportService.pdfSheetPageCountForItemCount(12), 1);
      expect(ItemQrExportService.pdfSheetPageCountForItemCount(13), 2);
      expect(ItemQrExportService.pdfSheetPageCountForItemCount(24), 2);
      expect(ItemQrExportService.pdfSheetPageCountForItemCount(25), 3);
    });
  });
}
