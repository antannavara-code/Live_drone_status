import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/theme_provider.dart';

class QrGenerateScreen extends StatefulWidget {
  const QrGenerateScreen({super.key});

  @override
  State<QrGenerateScreen> createState() => _QrGenerateScreenState();
}

class _QrGenerateScreenState extends State<QrGenerateScreen> {
  final TextEditingController _controller = TextEditingController();
  String? _droneId;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081621),
      appBar: AppBar(
        title: const Text('Generate QR Code'),
        backgroundColor: AppColors.surfaceAlt,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter drone ID e.g. DRONE-001',
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: AppColors.borderSubtle,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                final id = _controller.text.trim().toUpperCase();
                if (id.isNotEmpty) {
                  setState(() => _droneId = id);
                }
              },
              icon: const Icon(Icons.qr_code),
              label: const Text('Generate'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: Colors.greenAccent.shade700,
              ),
            ),
            if (_droneId != null) ...[
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    QrImageView(
                      data: _droneId!,
                      version: QrVersions.auto,
                      size: 240,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _droneId!,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Screenshot this QR code, print it, and stick it on the drone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
