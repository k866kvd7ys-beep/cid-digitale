import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/driver_personal_qr_data.dart';

typedef DriverQrDetectedCallback = Future<void> Function(
  DriverPersonalQrData data,
);

class DriverQrScannerScreen extends StatefulWidget {
  const DriverQrScannerScreen({
    super.key,
    required this.title,
    required this.hint,
    required this.invalidMessage,
    required this.onDetected,
  });

  final String title;
  final String hint;
  final String invalidMessage;
  final DriverQrDetectedCallback onDetected;

  @override
  State<DriverQrScannerScreen> createState() => _DriverQrScannerScreenState();
}

class _DriverQrScannerScreenState extends State<DriverQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [BarcodeFormat.qrCode],
  );

  bool _handlingDetection = false;
  Timer? _restartTimer;

  @override
  void dispose() {
    _restartTimer?.cancel();
    unawaited(_controller.dispose());
    super.dispose();
  }

  Future<void> _restartScanner() async {
    _restartTimer?.cancel();
    _restartTimer = Timer(const Duration(milliseconds: 900), () async {
      if (!mounted) return;
      _handlingDetection = false;
      await _controller.start();
    });
  }

  Future<void> _handleDetection(BarcodeCapture capture) async {
    if (_handlingDetection) return;

    final rawValue = capture.barcodes
        .map((barcode) => barcode.rawValue?.trim() ?? '')
        .firstWhere((value) => value.isNotEmpty, orElse: () => '');
    if (rawValue.isEmpty) return;

    _handlingDetection = true;
    debugPrint('[DriverQR] scan detected rawLength=${rawValue.length}');
    await _controller.stop();

    final parsedData = driverPersonalQrDataFromQrPayload(rawValue);
    if (parsedData == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.invalidMessage)),
      );
      await _restartScanner();
      return;
    }

    try {
      await widget.onDetected(parsedData);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e, st) {
      debugPrint('[DriverQR] import failed $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.invalidMessage)),
      );
      await _restartScanner();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            fit: BoxFit.cover,
            onDetect: _handleDetection,
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                    width: 32,
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.qr_code_scanner_outlined,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.hint,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
