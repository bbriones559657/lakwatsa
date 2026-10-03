import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../domain/packing.dart';

class QrScannerScreen extends StatefulWidget {
  final String userId;
  const QrScannerScreen({super.key, required this.userId});
  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with WidgetsBindingObserver {
  final _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _returned = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_controller.value.isInitialized || _returned) return;
    if (state == AppLifecycleState.resumed) {
      _start();
    } else {
      _controller.stop();
    }
  }

  Future<void> _start() async {
    try {
      await _controller.start();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Camera unavailable. Allow camera access in Android Settings, then retry.',
        );
      }
    }
  }

  void _detect(BarcodeCapture capture) {
    if (_returned) return;
    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .firstOrNull;
    if (raw == null) return;
    try {
      final id = parseItemQr(raw, widget.userId);
      _returned = true;
      Navigator.pop(context, id);
    } on FormatException catch (e) {
      setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Scan item'),
      actions: [
        IconButton(
          tooltip: 'Toggle torch',
          onPressed: () async {
            try {
              await _controller.toggleTorch();
            } catch (_) {
              if (mounted) setState(() => _error = 'Torch unavailable.');
            }
          },
          icon: const Icon(Icons.flash_on),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: _controller,
            onDetect: _detect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Camera unavailable. Allow camera access in Android Settings and retry.',
                    ),
                    TextButton(
                      onPressed: _start,
                      child: const Text('Retry camera'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              _error ?? 'Point the camera at a Lakwatsa QR label belonging to this account.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    ),
  );
}
