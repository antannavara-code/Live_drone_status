import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'drone_detail_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final TextEditingController manualController = TextEditingController();
  final MobileScannerController scannerController = MobileScannerController();
  bool _processing = false;

  void _openDroneDetail(String droneId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DroneDetailScreen(droneId: droneId),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_processing) return;
    final barcode = capture.barcodes.first;
    final droneId = barcode.rawValue;
    if (droneId != null && droneId.isNotEmpty) {
      _processing = true;
      _openDroneDetail(droneId);
    }
  }

  @override
  void dispose() {
    manualController.dispose();
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081621),
      appBar: AppBar(
        title: const Text('Scan Drone QR'),
        backgroundColor: const Color(0xFF0F2633),
        actions: [
          ValueListenableBuilder(
            valueListenable: scannerController,
            builder: (context, state, child) {
              return IconButton(
                icon: Icon(
                  state.torchState == TorchState.on
                      ? Icons.flash_on
                      : Icons.flash_off,
                ),
                onPressed: () => scannerController.toggleTorch(),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.switch_camera),
            onPressed: () => scannerController.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: MobileScanner(
              controller: scannerController,
              onDetect: _onDetect,
            ),
          ),
          Expanded(
            flex: 4,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF0F2633),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan a drone QR code or enter the drone ID manually.',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: manualController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter drone ID e.g. DRONE-001',
                      hintStyle: const TextStyle(color: Colors.white30),
                      filled: true,
                      fillColor: Colors.white10,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      final text = manualController.text.trim();
                      if (text.isNotEmpty) {
                        _openDroneDetail(text);
                      }
                    },
                    icon: const Icon(Icons.arrow_forward_ios),
                    label: const Text('View Drone'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: Colors.greenAccent.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
