import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/drone_status.dart';
import '../../services/telemetry_service.dart';
import '../../services/theme_provider.dart';
import '../../widgets/telemetry_chart.dart';

class FlightLogsTab extends StatefulWidget {
  final String droneId;
  const FlightLogsTab({super.key, required this.droneId});

  @override
  State<FlightLogsTab> createState() => _FlightLogsTabState();
}

class _FlightLogsTabState extends State<FlightLogsTab> {
  StreamSubscription<DroneStatus>? _sub;
  DroneStatus? _drone;

  final RollingBuffer _voltBuffer = RollingBuffer();
  final RollingBuffer _ampBuffer = RollingBuffer();
  final RollingBuffer _altBuffer = RollingBuffer();
  final RollingBuffer _spdBuffer = RollingBuffer();
  final RollingBuffer _windBuffer = RollingBuffer();

  @override
  void initState() {
    super.initState();
    _sub = TelemetryService.droneStream(widget.droneId).listen(_onUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onUpdate(DroneStatus drone) {
    if (!mounted) return;
    _voltBuffer.add(drone.batteryVoltage);
    _ampBuffer.add(drone.batteryCurrent);
    _altBuffer.add(drone.altitude);
    _spdBuffer.add(drone.speed);
    _windBuffer.add(drone.windSpeed);
    setState(() => _drone = drone);
  }

  @override
  Widget build(BuildContext context) {
    final drone = _drone;
    if (drone == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, color: Colors.white.withValues(alpha: 0.15), size: 64),
            const SizedBox(height: 16),
            Text('Waiting for telemetry...', style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 14)),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      children: [
        Row(
          children: [
            Icon(Icons.battery_std, color: AppColors.warning, size: 16),
            const SizedBox(width: 8),
            Text('BATTERY', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 180,
            child: TelemetryChart(
              data: _voltBuffer.points,
              label: 'Voltage',
              color: AppColors.warning,
              unit: 'V',
              maxY: 25,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 180,
            child: TelemetryChart(
              data: _ampBuffer.points,
              label: 'Current',
              color: AppColors.danger,
              unit: 'A',
              maxY: 100,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.speed, color: AppColors.infoBright, size: 16),
            const SizedBox(width: 8),
            Text('FLIGHT', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 180,
            child: TelemetryChart(
              data: _altBuffer.points,
              label: 'Altitude',
              color: AppColors.infoBright,
              unit: 'm',
              maxY: 600,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 180,
            child: TelemetryChart(
              data: _spdBuffer.points,
              label: 'Speed',
              color: AppColors.textSecondary,
              unit: 'm/s',
              maxY: 300,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(Icons.air, color: AppColors.info, size: 16),
            const SizedBox(width: 8),
            Text('WIND', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: SizedBox(
            height: 180,
            child: TelemetryChart(
              data: _windBuffer.points,
              label: 'Wind Speed',
              color: AppColors.info,
              unit: 'm/s',
              maxY: 15,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
