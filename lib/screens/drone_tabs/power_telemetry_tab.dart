import 'package:flutter/material.dart';
import '../../models/drone_status.dart';
import '../../services/theme_provider.dart';

class PowerTelemetryTab extends StatelessWidget {
  final DroneStatus drone;
  const PowerTelemetryTab({super.key, required this.drone});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      children: [
        _buildCard(
          icon: Icons.bolt,
          iconColor: Colors.yellow,
          title: 'Battery Level',
          subtitle: '${drone.cellDisplay} · ${drone.batteryTemperatureDisplay} · Healthy',
          value: drone.batteryPercentDisplay,
          valueColor: AppColors.primary,
          subValue: drone.batteryDisplay,
          progress: drone.isConnected ? (drone.batteryPercent / 100.0) : 0,
          progressColor: AppColors.primary,
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.flash_on,
          iconColor: Colors.yellow,
          title: 'Current Draw',
          subtitle: 'Average draw · Stable',
          value: drone.batteryCurrentDisplay,
          valueColor: AppColors.textPrimary,
          subValue: 'Amps',
          progress: drone.isConnected ? (drone.batteryCurrent / 50.0).clamp(0.0, 1.0) : 0,
          progressColor: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.thermostat,
          iconColor: Colors.orange,
          title: 'Temperature',
          subtitle: 'Battery pack · Within range',
          value: drone.batteryTemperatureDisplay,
          valueColor: AppColors.textPrimary,
          subValue: '°C',
          progress: drone.isConnected ? (drone.batteryTemperature / 80.0).clamp(0.0, 1.0) : 0,
          progressColor: Colors.orange,
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.satellite_alt,
          iconColor: Colors.lightBlueAccent,
          title: 'GPS Signal',
          subtitle: '${drone.satellitesDisplay} · ${drone.isConnected ? '3D lock' : 'No fix'}',
          value: drone.isConnected ? (drone.satellites > 10 ? 'Strong' : 'Weak') : '---',
          valueColor: const Color(0xFF8B5CF6),
          subValue: drone.satellitesDisplay,
          progress: drone.isConnected ? (drone.satellites / 20.0).clamp(0.0, 1.0) : 0,
          progressColor: const Color(0xFF8B5CF6),
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.radio,
          iconColor: Colors.amber,
          title: 'Telemetry Signal',
          subtitle: 'Radio link · ${drone.errorsCommDisplay}',
          value: drone.isConnected ? (drone.dropRate < 5 ? 'Good' : 'Poor') : '---',
          valueColor: AppColors.primary,
          subValue: drone.cpuLoadDisplay,
          progress: drone.isConnected ? 1.0 - (drone.dropRate / 100.0).clamp(0.0, 1.0) : 0,
          progressColor: AppColors.primary,
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.push_pin,
          iconColor: Colors.redAccent,
          title: 'Altitude',
          subtitle: 'Barometric · Relative',
          value: drone.altitudeDisplay,
          valueColor: AppColors.textPrimary,
          subValue: 'metres',
          progress: drone.isConnected ? (drone.altitude / 1000.0).clamp(0.0, 1.0) : 0,
          progressColor: const Color(0xFF3B82F6),
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.speed,
          iconColor: Colors.lightBlueAccent,
          title: 'Ground Speed',
          subtitle: 'Horizontal velocity',
          value: drone.speedDisplay,
          valueColor: AppColors.textPrimary,
          subValue: 'm/s',
          progress: drone.isConnected ? (drone.speed / 20.0).clamp(0.0, 1.0) : 0,
          progressColor: AppColors.primary,
        ),
        const SizedBox(height: 12),
        _buildCard(
          icon: Icons.air,
          iconColor: AppColors.info,
          title: 'Wind Speed',
          subtitle: 'Estimated from hover · ${drone.windDirectionDisplay}',
          value: drone.windSpeedDisplay,
          valueColor: AppColors.info,
          subValue: 'm/s',
          progress: drone.isConnected ? (drone.windSpeed / 15.0).clamp(0.0, 1.0) : 0,
          progressColor: AppColors.info,
        ),
      ],
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String value,
    required Color valueColor,
    required String subValue,
    required double progress,
    required Color progressColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                subValue,
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
