import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../models/item.dart';
import '../theme/app_theme.dart';

typedef QrExportProgress = void Function(int completed, int total);

class ItemQrExportService {
  const ItemQrExportService();

  static const double _cardWidth = 560;
  static const double _cardHeight = 760;
  static const double _qrSize = 280;
  static const int tagsPerPdfPage = 12;
  static const Duration _fontLoadTimeout = Duration(milliseconds: 450);

  static Future<void>? _fontPreparation;

  static String fileStemForName(String itemName) {
    var token = itemName
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');

    if (token.isEmpty) {
      token = 'item';
    }

    if (token.length > 48) {
      token = token.substring(0, 48).replaceFirst(RegExp(r'_+$'), '');
    }

    return 'lakwatsa_${token}_qr';
  }

  static String fileStemFor(Item item) {
    return fileStemForName(item.name);
  }

  static List<String> bulkPngFileNames(List<Item> items) {
    final seen = <String, int>{};
    final names = <String>[];

    for (final item in items) {
      final stem = fileStemFor(item);
      final count = (seen[stem] ?? 0) + 1;
      seen[stem] = count;

      names.add(count == 1 ? '$stem.png' : '${stem}_$count.png');
    }

    return names;
  }

  static int pdfSheetPageCountForItemCount(int itemCount) {
    if (itemCount <= 0) {
      return 0;
    }

    return ((itemCount - 1) ~/ tagsPerPdfPage) + 1;
  }

  Future<Uint8List> buildQrPng(Item item) async {
    final qrData = qrPayloadForExport(item);
    await _prepareExportFont();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = const Size(_cardWidth, _cardHeight);

    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.background);

    final cardRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(16, 16, _cardWidth - 32, _cardHeight - 32),
      const Radius.circular(20),
    );

    canvas.drawRRect(
      cardRect.shift(const Offset(6, 6)),
      Paint()..color = AppColors.ink,
    );
    canvas.drawRRect(cardRect, Paint()..color = AppColors.background);
    canvas.drawRRect(
      cardRect,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    canvas.save();
    canvas.clipRRect(cardRect);
    canvas.drawRect(
      const Rect.fromLTWH(16, 16, _cardWidth - 32, 74),
      Paint()..color = AppColors.green,
    );
    canvas.drawRect(
      const Rect.fromLTWH(16, 90, _cardWidth - 32, 6),
      Paint()..color = AppColors.orange,
    );
    canvas.restore();

    _drawCenteredText(
      canvas,
      text: 'LAKWATSA',
      y: 32,
      maxWidth: 470,
      style: GoogleFonts.pressStart2p(
        fontSize: 18,
        letterSpacing: 0.5,
        color: AppColors.background,
      ),
    );
    _drawCenteredText(
      canvas,
      text: 'QR TAG',
      y: 59,
      maxWidth: 470,
      style: GoogleFonts.pressStart2p(
        fontSize: 9,
        letterSpacing: 0.8,
        color: AppColors.background,
      ),
    );

    const qrBox = Rect.fromLTWH(80, 120, 400, 400);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        qrBox.shift(const Offset(5, 5)),
        const Radius.circular(14),
      ),
      Paint()..color = AppColors.ink,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(qrBox, const Radius.circular(14)),
      Paint()..color = Colors.white,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(qrBox, const Radius.circular(14)),
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final qrPainter = QrPainter(
      data: qrData,
      version: QrVersions.auto,
      gapless: true,
      eyeStyle: const QrEyeStyle(
        eyeShape: QrEyeShape.square,
        color: Colors.black,
      ),
      dataModuleStyle: const QrDataModuleStyle(
        dataModuleShape: QrDataModuleShape.square,
        color: Colors.black,
      ),
    );

    canvas.save();
    canvas.translate(140, 180);
    qrPainter.paint(canvas, const Size.square(_qrSize));
    canvas.restore();

    final nameHeight = _drawCenteredText(
      canvas,
      text: item.name.trim().isEmpty ? 'Unnamed item' : item.name.trim(),
      y: 552,
      maxWidth: 450,
      maxLines: 2,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 28,
        height: 1.06,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    );

    _drawMetadataRow(
      canvas,
      category: item.category,
      quantity: item.quantity,
      y: 552 + nameHeight + 10,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(220, 697, 120, 4),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.orange,
    );

    _drawCenteredText(
      canvas,
      text: 'SCAN WITH LAKWATSA',
      y: 710,
      maxWidth: 430,
      maxLines: 1,
      style: GoogleFonts.pressStart2p(
        fontSize: 8,
        letterSpacing: 0.5,
        color: AppColors.muted,
      ),
    );

    final image = await recorder.endRecording().toImage(
      _cardWidth.toInt(),
      _cardHeight.toInt(),
    );

    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw StateError('Could not render the QR card image.');
      }

      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  Future<Uint8List> buildQrPdf(Item item) async {
    qrPayloadForExport(item);

    final cardPng = await buildQrPng(item);

    // PDF encoding is CPU-heavy enough to pause Flutter animations on larger
    // devices/files. Keep it off the UI isolate so the processing indicator
    // remains visibly active while the document is finalized.
    return compute<Uint8List, Uint8List>(
      _buildSingleQrPdfBytes,
      cardPng,
      debugLabel: 'lakwatsa-single-qr-pdf',
    );
  }

  Future<Uint8List> buildQrSheetPdf(
    List<Item> items, {
    QrExportProgress? onProgress,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Select at least one item to export.');
    }

    final cardPngs = <Uint8List>[];

    for (var index = 0; index < items.length; index++) {
      final item = items[index];
      qrPayloadForExport(item);
      cardPngs.add(await buildQrPng(item));
      onProgress?.call(index + 1, items.length);

      // Yield between cards so progress frames can be painted during the
      // rendering stage. Final PDF encoding is moved to compute() below.
      await Future<void>.delayed(Duration.zero);
    }

    return compute<List<Uint8List>, Uint8List>(
      _buildQrSheetPdfBytes,
      cardPngs,
      debugLabel: 'lakwatsa-qr-sheet-pdf',
    );
  }

  Future<bool> saveQrPng(Item item) async {
    final bytes = await buildQrPng(item);
    final result = await FileSaver.instance.saveAs(
      name: fileStemFor(item),
      bytes: bytes,
      fileExtension: 'png',
      mimeType: MimeType.png,
      dialogTitle: 'Save Lakwatsa QR card',
    );

    return result != null;
  }

  Future<void> shareQrPng(Item item, {Rect? sharePositionOrigin}) async {
    final bytes = await buildQrPng(item);
    final fileName = '${fileStemFor(item)}.png';

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: fileName)],
        fileNameOverrides: [fileName],
        title: 'Share ${item.name} QR card',
        subject: '${item.name} QR card',
        text: 'Lakwatsa QR card for ${item.name}.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<void> shareQrPngs(
    List<Item> items, {
    Rect? sharePositionOrigin,
    QrExportProgress? onProgress,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError('Select at least one item to export.');
    }

    final fileNames = bulkPngFileNames(items);
    final files = <XFile>[];

    for (var index = 0; index < items.length; index++) {
      final bytes = await buildQrPng(items[index]);
      files.add(
        XFile.fromData(bytes, mimeType: 'image/png', name: fileNames[index]),
      );
      onProgress?.call(index + 1, items.length);
      await Future<void>.delayed(Duration.zero);
    }

    await SharePlus.instance.share(
      ShareParams(
        files: files,
        fileNameOverrides: fileNames,
        title: 'Export Lakwatsa QR cards',
        subject: 'Lakwatsa QR cards',
        text: '${items.length} individual Lakwatsa QR cards.',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  Future<bool> exportQrPdf(Item item) async {
    final bytes = await buildQrPdf(item);
    final result = await FileSaver.instance.saveAs(
      name: '${fileStemFor(item)}_label',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      dialogTitle: 'Export Lakwatsa QR label',
    );

    return result != null;
  }

  Future<bool> exportQrSheetPdf(
    List<Item> items, {
    QrExportProgress? onProgress,
  }) async {
    final bytes = await buildQrSheetPdf(items, onProgress: onProgress);
    final result = await FileSaver.instance.saveAs(
      name: 'lakwatsa_qr_tag_sheet',
      bytes: bytes,
      fileExtension: 'pdf',
      mimeType: MimeType.pdf,
      dialogTitle: 'Export Lakwatsa QR tag sheet',
    );

    return result != null;
  }

  Future<void> _prepareExportFont() {
    return _fontPreparation ??= _prepareExportFontOnce();
  }

  Future<void> _prepareExportFontOnce() async {
    final styles = <TextStyle>[
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
      GoogleFonts.pressStart2p(),
    ];

    try {
      await GoogleFonts.pendingFonts(styles).timeout(_fontLoadTimeout);
    } on TimeoutException {
      // Do not make exports depend on network font loading. The requested
      // TextStyles keep their platform fallback when the font is unavailable.
    } catch (_) {
      // Font loading is cosmetic. QR export must still continue.
    }
  }

  double _drawCenteredText(
    Canvas canvas, {
    required String text,
    required double y,
    required double maxWidth,
    required TextStyle style,
    int maxLines = 1,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);

    painter.paint(canvas, Offset((_cardWidth - painter.width) / 2, y));

    return painter.height;
  }

  void _drawMetadataRow(
    Canvas canvas, {
    required String category,
    required int quantity,
    required double y,
  }) {
    const rowWidth = 450.0;
    const categoryWidth = 310.0;
    const quantityWidth = 120.0;
    const gap = 20.0;
    const rowLeft = (_cardWidth - rowWidth) / 2;

    final categoryPainter = TextPainter(
      text: TextSpan(
        text: category.trim().isEmpty ? 'Uncategorized' : category.trim(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: categoryWidth);

    final quantityPainter = TextPainter(
      text: TextSpan(
        text: 'Qty $quantity',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
        ),
      ),
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: quantityWidth);

    categoryPainter.paint(canvas, Offset(rowLeft, y));
    quantityPainter.paint(
      canvas,
      Offset(
        rowLeft + categoryWidth + gap + quantityWidth - quantityPainter.width,
        y,
      ),
    );
  }

  static String qrPayloadForExport(Item item) {
    final value = item.qrCode;

    if (value == null || value.trim().isEmpty) {
      throw StateError('This item does not have a QR code yet.');
    }

    // Firestore lookup uses exact QR equality. Preserve the stored payload
    // byte-for-byte instead of normalizing whitespace during export.
    return value;
  }
}

Future<Uint8List> _buildSingleQrPdfBytes(Uint8List cardPng) async {
  final document = pw.Document();
  final cardImage = pw.MemoryImage(cardPng);

  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.all(18 * PdfPageFormat.mm),
      build: (context) {
        return pw.Center(
          child: pw.Image(
            cardImage,
            width: 58 * PdfPageFormat.mm,
            fit: pw.BoxFit.contain,
          ),
        );
      },
    ),
  );

  return document.save();
}

Future<Uint8List> _buildQrSheetPdfBytes(List<Uint8List> cardPngs) async {
  final cardImages = cardPngs
      .map((bytes) => pw.MemoryImage(bytes))
      .toList(growable: false);
  final document = pw.Document();

  for (
    var start = 0;
    start < cardImages.length;
    start += ItemQrExportService.tagsPerPdfPage
  ) {
    final end = (start + ItemQrExportService.tagsPerPdfPage < cardImages.length)
        ? start + ItemQrExportService.tagsPerPdfPage
        : cardImages.length;
    final pageImages = cardImages.sublist(start, end);

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(6 * PdfPageFormat.mm),
        build: (context) {
          return _buildPdfTagGrid(pageImages);
        },
      ),
    );
  }

  return document.save();
}

pw.Widget _buildPdfTagGrid(List<pw.MemoryImage> images) {
  const rows = 4;
  const columns = 3;

  return pw.Column(
    children: List.generate(rows, (rowIndex) {
      return pw.Expanded(
        child: pw.Row(
          children: List.generate(columns, (columnIndex) {
            final index = rowIndex * columns + columnIndex;

            return pw.Expanded(
              child: pw.Padding(
                padding: pw.EdgeInsets.all(1.5 * PdfPageFormat.mm),
                child: index < images.length
                    ? pw.Image(images[index], fit: pw.BoxFit.contain)
                    : pw.SizedBox(),
              ),
            );
          }),
        ),
      );
    }),
  );
}
