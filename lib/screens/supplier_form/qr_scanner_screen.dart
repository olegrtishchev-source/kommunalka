import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Полноэкранное сканирование QR-кода камерой (ТЗ §4.11, Этап 5 п. 5.10).
/// Возвращает первый распознанный [Barcode] через Navigator.pop; null —
/// пользователь закрыл экран, ничего не распознав.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _handled = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Наведите камеру на QR-код')),
      body: MobileScanner(
        controller: _controller,
        onDetect: (BarcodeCapture capture) {
          if (_handled || capture.barcodes.isEmpty) return;
          _handled = true;
          Navigator.pop(context, capture.barcodes.first);
        },
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
