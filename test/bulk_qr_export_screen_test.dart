import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakwatsa/models/item.dart';
import 'package:lakwatsa/screens/items/bulk_qr_export_screen.dart';
import 'package:lakwatsa/services/item_qr_export_service.dart';

void main() {
  const items = <Item>[
    Item(
      id: 'laptop',
      name: 'Laptop',
      category: 'Electronics',
      quantity: 1,
      icon: 'laptop',
      qrCode: 'lakwatsa:item:laptop',
    ),
    Item(
      id: 'charger',
      name: 'Charger',
      category: 'Electronics',
      quantity: 2,
      icon: 'charger',
      qrCode: 'lakwatsa:item:charger',
    ),
    Item(
      id: 'shirt',
      name: 'Shirt without QR',
      category: 'Clothing',
      quantity: 1,
      icon: 'shirt',
    ),
  ];

  testWidgets('bulk QR export lists QR-ready items and supports selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: BulkQrExportScreen(itemsStream: Stream.value(items))),
    );
    await tester.pumpAndSettle();

    expect(find.text('2 QR-ready items'), findsOneWidget);
    expect(find.textContaining('12 cut-out tags'), findsOneWidget);
    expect(find.text('Shirt without QR'), findsNothing);
    expect(find.text('0 selected'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('bulk-qr-item-laptop')));
    await tester.pump();

    expect(find.text('1 selected'), findsOneWidget);

    await tester.tap(find.text('Select all'));
    await tester.pump();

    expect(find.text('2 selected'), findsOneWidget);
    expect(find.text('Clear all'), findsOneWidget);
  });

  testWidgets('PDF export shows blocking processing progress', (tester) async {
    final exportService = _ControlledExportService();

    await tester.pumpWidget(
      MaterialApp(
        home: BulkQrExportScreen(
          itemsStream: Stream.value(items),
          exportService: exportService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bulk-qr-item-laptop')));
    await tester.pump();
    await tester.tap(find.text('Export PDF Sheet'));

    // First frame makes the busy state visible before export work begins.
    await tester.pump();
    expect(
      find.byKey(const ValueKey('qr-export-processing-overlay')),
      findsOneWidget,
    );
    expect(find.text('Preparing PDF tags'), findsOneWidget);

    // The service reports card-render progress while the operation is pending.
    await tester.pump();
    expect(find.text('Finalizing PDF...'), findsOneWidget);
    expect(
      find.text('Still working. This can take a few seconds.'),
      findsOneWidget,
    );

    final busyPopScope = tester.widget<PopScope<Object?>>(
      find.byType(PopScope<Object?>),
    );
    expect(busyPopScope.canPop, isFalse);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isFalse,
    );

    exportService.complete(false);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('qr-export-processing-overlay')),
      findsNothing,
    );

    final idlePopScope = tester.widget<PopScope<Object?>>(
      find.byType(PopScope<Object?>),
    );
    expect(idlePopScope.canPop, isTrue);
    expect(
      tester.widget<AppBar>(find.byType(AppBar)).automaticallyImplyLeading,
      isTrue,
    );
  });
}

class _ControlledExportService extends ItemQrExportService {
  final Completer<bool> _pdfCompleter = Completer<bool>();

  @override
  Future<bool> exportQrSheetPdf(
    List<Item> items, {
    QrExportProgress? onProgress,
  }) {
    onProgress?.call(items.length, items.length);
    return _pdfCompleter.future;
  }

  void complete(bool value) {
    _pdfCompleter.complete(value);
  }
}
