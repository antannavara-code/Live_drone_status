import 'package:flutter/material.dart';
import '../widgets/route_transitions.dart';
import 'qr_scan_screen.dart';
import '../services/theme_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF081621),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceAlt,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.greenAccent.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.flight_rounded,
                    color: Colors.greenAccent,
                    size: 64,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'FWD FYNEX',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Drone Telemetry System',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      FlipRoute(page: const QrScanScreen()),
                    ),
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 28),
                    label: const Text(
                      'SCAN QR CODE',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.greenAccent.shade700,
                      foregroundColor: AppColors.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 4,
                    ),
                  ),
                ),
                const Spacer(flex: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
