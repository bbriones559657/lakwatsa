import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../domain/packing.dart';

class ItemQrScreen extends StatelessWidget {
  final Belonging item;
  final String userId;
  const ItemQrScreen({super.key, required this.item, required this.userId});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Item QR code')),
    body: Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              item.name,
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: QrImageView(
                data: itemQrPayload(userId, item.id),
                size: 250,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Capture or print this code and attach it to your item.\nScan it during an activity check.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SelectableText(
              itemQrPayload(userId, item.id),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ),
  );
}
