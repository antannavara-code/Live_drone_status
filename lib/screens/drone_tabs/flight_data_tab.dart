import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/drone_status.dart';
import '../../services/telemetry_service.dart';
import '../../services/theme_provider.dart';
import '../../widgets/attitude_visualizer.dart';
import '../../widgets/arc_gauge.dart';
import '../../widgets/shimmer_loading.dart';

class FlightDataTab extends StatefulWidget {
  final String droneId;
  const FlightDataTab({super.key, required this.droneId});

  @override
  State<FlightDataTab> createState() => _FlightDataTabState();
}

class _FlightDataTabState extends State<FlightDataTab> {
  DateTime? _armStartTime;
  Duration _flightDuration = Duration.zero;
  Timer? _timer;
  DroneStatus? _drone;
  StreamSubscription<DroneStatus>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = TelemetryService.droneStream(widget.droneId).listen(_onDroneUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  void _onDroneUpdate(DroneStatus drone) {
    if (!mounted) return;
    _updateFlightTime(drone);
    setState(() => _drone = drone);
  }

  String get _flightTimeDisplay {
    if (_drone != null && !_drone!.isConnected) return '--:--:--';
    if (_flightDuration == Duration.zero) return '--:--:--';
    final h = _flightDuration.inHours.toString().padLeft(2, '0');
    final m = (_flightDuration.inMinutes % 60).toString().padLeft(2, '0');
    final s = (_flightDuration.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  void _updateFlightTime(DroneStatus drone) {
    if (drone.armed) {
      if (_armStartTime == null) {
        _armStartTime = DateTime.now();
        _timer?.cancel();
        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (_armStartTime != null) {
            _flightDuration = DateTime.now().difference(_armStartTime!);
            if (mounted) setState(() {});
          }
        });
      }
    } else {
      if (_armStartTime != null) {
        _armStartTime = null;
        _timer?.cancel();
        _flightDuration = Duration.zero;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final drone = _drone;
    if (drone == null) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: ShimmerGrid(count: 4, height: 100),
      );
    }

    return _FlightDataContent(
      drone: drone,
      flightTimeDisplay: _flightTimeDisplay,
    );
  }
}

class _FlightDataContent extends StatelessWidget {
  final DroneStatus drone;
  final String flightTimeDisplay;

  const _FlightDataContent({
    required this.drone,
    required this.flightTimeDisplay,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        _buildModeTopBar(),
        const SizedBox(height: 20),
        _buildSectionTitle('ATTITUDE & SENSORS'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
          child: _buildAttitudeGrid(),
        ),
        const SizedBox(height: 20),
        _buildSectionTitle('3D ATTITUDE VISUALIZER'),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 16),
            child: SizedBox(
              height: 446,
              child: AttitudeVisualizer(
                roll: drone.isConnected ? drone.roll : 0,
                pitch: drone.isConnected ? drone.pitch : 0,
                yaw: drone.isConnected ? drone.heading : 0,
                heading: drone.isConnected ? drone.heading : 0,
                altitude: drone.isConnected ? drone.altitude : 0,
                groundSpeed: drone.isConnected ? drone.speed : 0,
                batteryPercent: drone.isConnected ? drone.batteryPercent.toDouble() : 0,
                flightMode: drone.isConnected ? drone.mode : '---',
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildModeTopBar() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.danger),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  drone.modeDisplay.toUpperCase(),
                  style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.primary),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(drone.armDisplay, style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ArcGauge(value: drone.isConnected ? drone.altitude : 0, max: 500, unit: 'm', label: 'Altitude', size: 82, decimals: 1, valueColor: AppColors.infoBright),
              ArcGauge(value: drone.isConnected ? drone.speed : 0, max: 50, unit: 'm/s', label: 'Speed', size: 82, decimals: 1, valueColor: AppColors.textSecondary),
              ArcGauge(value: drone.isConnected ? drone.heading : 0, max: 360, unit: '\u00B0', label: 'Heading', size: 82, decimals: 0, valueColor: const Color(0xFF64B5F6)),
              _batteryWidget(drone),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Text(
        title,
        style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildAttitudeGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      children: [
        _buildGridItem(Icons.timer, 'Flight Time', AppColors.info, drone.flightTimeDisplay),
        _buildGridItem(Icons.straighten, 'Dist to Home', const Color(0xFFCE93D8), drone.distanceToHomeDisplay),
        _buildGridItem(Icons.swap_horiz, 'Roll', Colors.orange, drone.rollDisplay),
        _buildGridItem(Icons.swap_vert, 'Pitch', Colors.orange, drone.pitchDisplay),
        _buildGridItem(Icons.explore, 'Compass', Colors.redAccent, drone.headingDisplay),
        _buildGridItem(Icons.bar_chart, 'Baro', Colors.tealAccent, drone.altitudeDisplay),
        _buildGridItem(Icons.air, 'Wind', AppColors.info, drone.windSpeedDisplay),
        _buildGridItem(Icons.navigation, 'Wind Dir', AppColors.info, drone.windDirectionDisplay),
      ],
    );
  }

  Widget _buildGridItem(IconData icon, String title, Color titleColor, String value) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: titleColor, size: 14),
              const SizedBox(width: 6),
              Text(title, style: TextStyle(color: titleColor, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _batteryWidget(DroneStatus drone) {
    final batColor = !drone.isConnected
        ? AppColors.textMuted
        : drone.batteryVoltage >= 12.0
            ? AppColors.primary
            : drone.batteryVoltage >= 10.5
                ? AppColors.warningBright
                : AppColors.dangerBright;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.battery_std, color: batColor, size: 28),
        const SizedBox(height: 4),
        Text(
          drone.batteryDisplay,
          style: TextStyle(
            color: batColor,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'Battery',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9),
        ),
      ],
    );
  }
}
