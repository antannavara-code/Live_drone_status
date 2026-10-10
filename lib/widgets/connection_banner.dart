import 'dart:async';
import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

enum DroneConnectionState { live, reconnecting, disconnected }

class ConnectionBanner extends StatefulWidget {
  final double lastUpdated;
  final bool armed;
  const ConnectionBanner({super.key, required this.lastUpdated, required this.armed});

  @override
  State<ConnectionBanner> createState() => _ConnectionBannerState();
}

class _ConnectionBannerState extends State<ConnectionBanner> {
  Timer? _timer;
  late String _ago;

  @override
  void initState() {
    super.initState();
    _updateAgo();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateAgo());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _updateAgo() {
    final diff = DateTime.now().millisecondsSinceEpoch / 1000 - widget.lastUpdated;
    if (diff < 0) {
      _ago = 'just now';
    } else if (diff < 5) {
      _ago = 'just now';
    } else if (diff < 60) {
      _ago = '${diff.toInt()}s ago';
    } else if (diff < 3600) {
      _ago = '${(diff / 60).toInt()}m ago';
    } else {
      _ago = '${(diff / 3600).toInt()}h ago';
    }
    if (mounted) setState(() {});
  }

  DroneConnectionState _state() {
    final diff = DateTime.now().millisecondsSinceEpoch / 1000 - widget.lastUpdated;
    if (diff < 10) return DroneConnectionState.live;
    if (diff < 30) return DroneConnectionState.reconnecting;
    return DroneConnectionState.disconnected;
  }

  @override
  Widget build(BuildContext context) {
    final state = _state();
    final (Color bg, Color dot, String label, String sub) = switch (state) {
      DroneConnectionState.live => (
        const Color(0xFF0D2B1D),
        AppColors.primary,
        'LIVE',
        widget.armed ? 'Armed $_ago' : 'Connected $_ago',
      ),
      DroneConnectionState.reconnecting => (
        const Color(0xFF2B240D),
        AppColors.warning,
        'RECONNECTING',
        'Last update $_ago',
      ),
      DroneConnectionState.disconnected => (
        const Color(0xFF2B0D0D),
        AppColors.danger,
        'DISCONNECTED',
        'Last update $_ago',
      ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      color: bg,
      child: Row(
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: dot, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(width: 8),
          Text(sub, style: TextStyle(color: AppColors.textMuted, fontSize: 9)),
        ],
      ),
    );
  }
}
