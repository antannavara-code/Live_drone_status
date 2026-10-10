import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/theme_provider.dart';
import '../widgets/route_transitions.dart';
import 'drone_detail_screen.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController scannerController = MobileScannerController();
  bool _processing = false;
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  void _openDroneDetail(String droneId) {
    Navigator.of(context).push(
      FlipRoute(page: DroneDetailScreen(droneId: droneId)),
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
    _glowController.dispose();
    scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: scannerController,
            onDetect: _onDetect,
          ),
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  title: const Text('Scan Drone QR'),
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  actions: [
                    ValueListenableBuilder(
                      valueListenable: scannerController,
                      builder: (context, state, child) {
                        return IconButton(
                          icon: Icon(
                            state.torchState == TorchState.on
                                ? Icons.flash_on
                                : Icons.flash_off,
                            color: Colors.white,
                          ),
                          onPressed: () => scannerController.toggleTorch(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.switch_camera, color: Colors.white),
                      onPressed: () => scannerController.switchCamera(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildBrandedHeader(),
                const Spacer(),
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, _) {
                    return CustomPaint(
                      size: Size(
                        MediaQuery.of(context).size.width,
                        MediaQuery.of(context).size.height * 0.42,
                      ),
                      painter: _ScanOverlayPainter(
                        glowProgress: _glowController.value,
                      ),
                    );
                  },
                ),
                const Spacer(),
                _buildBottomInfoCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandedHeader() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipOval(
            child: SizedBox(
              width: 36,
              height: 36,
              child: Image.asset('assets/fwd_logo.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'FWD FYNEX',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Drone Telemetry',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomInfoCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.surfaceAlt.withValues(alpha: 0.9),
            AppColors.videoBg.withValues(alpha: 0.95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Scan QR to Connect',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Point camera at drone QR code',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanOverlayPainter extends CustomPainter {
  final double glowProgress;
  _ScanOverlayPainter({required this.glowProgress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final frameSize = w * 0.65;
    final left = (w - frameSize) / 2;
    final top = (h - frameSize) / 2;
    final cornerRadius = 20.0;
    final borderWidth = 3.0;
    final right = left + frameSize;
    final bottom = top + frameSize;

    // dark overlay with cutout
    final overlayPaint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, frameSize, frameSize),
      Radius.circular(cornerRadius),
    );
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, w, h));
    final holePath = Path()..addRRect(frameRect);
    final overlayPath = Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(overlayPath, overlayPaint);

    // ── tech pattern inside scan frame ──
    _drawTechPattern(canvas, left, top, frameSize, frameRect);

    // pulsing glow
    final glowAlpha = 0.12 + (glowProgress * 0.25);
    final glowWidth = 8.0 + (glowProgress * 10.0);
    final glowPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: glowAlpha)
      ..strokeWidth = glowWidth
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 + glowProgress * 6);
    canvas.drawRRect(frameRect, glowPaint);

    // frame border
    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.5 + glowProgress * 0.3)
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(frameRect, borderPaint);

    // corner accents
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..strokeWidth = borderWidth + 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final len = frameSize * 0.18;
    final r = cornerRadius;

    // top-left
    canvas.drawLine(Offset(left, top + r + len), Offset(left, top + r), cornerPaint);
    canvas.drawLine(Offset(left + r, top), Offset(left + r + len, top), cornerPaint);
    // top-right
    canvas.drawLine(Offset(right - r - len, top), Offset(right - r, top), cornerPaint);
    canvas.drawLine(Offset(right, top + r), Offset(right, top + r + len), cornerPaint);
    // bottom-left
    canvas.drawLine(Offset(left, bottom - r - len), Offset(left, bottom - r), cornerPaint);
    canvas.drawLine(Offset(left + r, bottom), Offset(left + r + len, bottom), cornerPaint);
    // bottom-right
    canvas.drawLine(Offset(right - r - len, bottom), Offset(right - r, bottom), cornerPaint);
    canvas.drawLine(Offset(right, bottom - r - len), Offset(right, bottom - r), cornerPaint);

    // animated scan line
    final scanY = top + (frameSize * 0.15) + math.sin(glowProgress * math.pi) * (frameSize * 0.7);
    final scanLinePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withValues(alpha: 0.0),
          AppColors.primary.withValues(alpha: 0.6),
          AppColors.primary.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(left + 10, scanY, frameSize - 20, 2))
      ..strokeWidth = 1.5;
    canvas.drawLine(
      Offset(left + 15, scanY),
      Offset(right - 15, scanY),
      scanLinePaint,
    );
  }

  void _drawTechPattern(Canvas canvas, double left, double top, double frameSize, RRect frameRect) {
    final green = AppColors.primary;
    final clipPath = Path()..addRRect(frameRect);
    canvas.save();
    canvas.clipPath(clipPath);

    final dotPaint = Paint()
      ..color = green.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final hexPaint = Paint()
      ..color = green.withValues(alpha: 0.06)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    // hexagonal grid
    final hexR = frameSize * 0.08;
    final hexH = hexR * math.sqrt(3);
    final cols = (frameSize / (hexR * 1.5)).ceil() + 2;
    final rows = (frameSize / hexH).ceil() + 2;

    for (int row = -1; row <= rows; row++) {
      for (int col = -1; col <= cols; col++) {
        final cx = left + col * hexR * 1.5;
        final cy = top + row * hexH + (col.isOdd ? hexH / 2 : 0);
        final path = Path();
        for (int i = 0; i < 6; i++) {
          final angle = math.pi / 3 * i - math.pi / 6;
          final px = cx + hexR * math.cos(angle);
          final py = cy + hexR * math.sin(angle);
          if (i == 0) {
            path.moveTo(px, py);
          } else {
            path.lineTo(px, py);
          }
        }
        path.close();
        canvas.drawPath(path, hexPaint);

        // dot at center of each hex
        canvas.drawCircle(Offset(cx, cy), 1.0, dotPaint);
      }
    }

    // circuit trace lines (horizontal + vertical)
    final tracePaint = Paint()
      ..color = green.withValues(alpha: 0.07)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final step = frameSize / 10;
    for (int i = 1; i < 10; i++) {
      final hY = top + i * step;
      canvas.drawLine(Offset(left, hY), Offset(left + frameSize, hY), tracePaint);
      final vX = left + i * step;
      canvas.drawLine(Offset(vX, top), Offset(vX, top + frameSize), tracePaint);
    }

    // node dots at some grid intersections
    final nodePaint = Paint()
      ..color = green.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;

    for (int i = 1; i < 10; i += 2) {
      for (int j = 1; j < 10; j += 2) {
        final nx = left + i * step;
        final ny = top + j * step;
        canvas.drawCircle(Offset(nx, ny), 1.8, nodePaint);
        canvas.drawCircle(Offset(nx, ny), 4.0, Paint()
          ..color = green.withValues(alpha: 0.04)
          ..style = PaintingStyle.fill);
      }
    }

    // small cross markers at scattered positions
    final crossPaint = Paint()
      ..color = green.withValues(alpha: 0.12)
      ..strokeWidth = 0.7
      ..strokeCap = StrokeCap.round;
    final crossSize = 4.0;
    for (int i = 0; i < 8; i++) {
      final cx = left + frameSize * (0.1 + (i * 0.11));
      final cy = top + frameSize * (0.2 + ((i * 37) % 60) / 100.0);
      canvas.drawLine(Offset(cx - crossSize, cy), Offset(cx + crossSize, cy), crossPaint);
      canvas.drawLine(Offset(cx, cy - crossSize), Offset(cx, cy + crossSize), crossPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ScanOverlayPainter old) =>
      old.glowProgress != glowProgress;
}
