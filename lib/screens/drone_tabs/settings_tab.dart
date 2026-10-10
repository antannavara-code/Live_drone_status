import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/telemetry_service.dart';
import '../../services/tcp_telemetry_service.dart';
import '../../services/theme_provider.dart';

class SettingsTab extends StatefulWidget {
  final String droneId;
  const SettingsTab({super.key, required this.droneId});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  final _hostController = TextEditingController();
  final _portController = TextEditingController();
  bool _saving = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    _load();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _hostController.text = prefs.getString('tcp_host') ?? '192.168.50.120';
    int? portInt;
    try {
      portInt = prefs.getInt('tcp_port');
    } catch (_) {
    }
    _portController.text = portInt?.toString() ??
        prefs.getString('tcp_port') ??
        '9001';
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 9001;

    if (host.isEmpty) {
      _showError('Enter an IP address');
      return;
    }

    setState(() => _saving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tcp_host', host);
    await prefs.setInt('tcp_port', port);

    TelemetryService.connect(host: host, port: port);

    setState(() {
      _saving = false;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.settings, color: AppColors.textMuted, size: 56),
              const SizedBox(height: 12),
              Text(
                'Settings',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 24),
              _tcpStatusBadge(),
              const SizedBox(height: 24),
              TextField(
                controller: _hostController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Transmitter IP',
                  hintText: '192.168.50.120',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: Icon(Icons.computer, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _portController,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'JSON Telemetry Port',
                  hintText: '9001',
                  labelStyle: TextStyle(color: AppColors.textMuted),
                  hintStyle: const TextStyle(color: Colors.white24),
                  prefixIcon: Icon(Icons.settings_ethernet, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(_saving ? 'Saving...' : 'Save & Connect'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
          ],
        ),
      ),
    ));
  }

  Widget _tcpStatusBadge() {
    final state = TelemetryService.tcpState;
    final err = TelemetryService.tcpLastError;
    final connected = state == TcpState.connected;
    final connecting = state == TcpState.connecting;
    final circuitOpen = TelemetryService.tcp.circuitOpen;
    Color color;
    String label;
    if (circuitOpen) {
      color = AppColors.textMuted;
      label = 'Cooldown (5 min)';
    } else if (connected) {
      color = AppColors.primary;
      label = 'Connected';
    } else if (connecting) {
      color = AppColors.warningBright;
      label = 'Connecting...';
    } else {
      color = AppColors.dangerBright;
      label = 'Not connected';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Drone Stream',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (err != null) ...[
            const SizedBox(height: 6),
            Text(
              err,
              style: TextStyle(color: AppColors.dangerBright, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}
