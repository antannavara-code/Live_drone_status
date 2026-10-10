import 'package:flutter/material.dart';
import '../models/drone_status.dart';
import '../services/telemetry_service.dart';
import '../services/theme_provider.dart';
import '../services/flight_recorder.dart';
import '../services/mavlink_log_downloader.dart';
import '../widgets/live_dot.dart';
import 'drone_tabs/dashboard_tab.dart';
import 'drone_tabs/flight_data_tab.dart';
import 'drone_tabs/system_health_tab.dart';
import 'drone_tabs/flight_logs_tab.dart';
import 'drone_tabs/settings_tab.dart';

class DroneDetailScreen extends StatefulWidget {
  final String droneId;
  const DroneDetailScreen({super.key, required this.droneId});

  @override
  State<DroneDetailScreen> createState() => _DroneDetailScreenState();
}

class _DroneDetailScreenState extends State<DroneDetailScreen> {
  int _currentIndex = 0;
  bool _live = false;

  @override
  void initState() {
    super.initState();
    FlightRecorder.init(widget.droneId);
    MavlinkLogDownloader.init(widget.droneId);
  }

  @override
  void dispose() {
    FlightRecorder.dispose();
    MavlinkLogDownloader.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldAlt,
      body: SafeArea(
        child: StreamBuilder<DroneStatus>(
          stream: TelemetryService.droneStream(widget.droneId),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              _live = snapshot.data!.isConnected;
            }
            return Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCurrentTab()),
                _buildBottomNav(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCurrentTab() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            ),
            child: child,
          ),
        );
      },
      child: _tabWidget(),
    );
  }

  Widget _tabWidget() {
    switch (_currentIndex) {
      case 0:
        return DashboardTab(key: const ValueKey('tab_dashboard'), droneId: widget.droneId);
      case 1:
        return FlightDataTab(key: const ValueKey('tab_flight'), droneId: widget.droneId);
      case 2:
        return SystemHealthTab(key: const ValueKey('tab_video'), droneId: widget.droneId);
      case 3:
        return FlightLogsTab(key: const ValueKey('tab_logs'), droneId: widget.droneId);
      case 4:
        return SettingsTab(key: const ValueKey('tab_settings'), droneId: widget.droneId);
      default:
        return DashboardTab(key: const ValueKey('tab_dashboard'), droneId: widget.droneId);
    }
  }

  Widget _buildTopBar() {
    final titles = ['Dashboard', 'Flight Data', 'Video Feed', 'Flight Logs', 'Settings'];
    final subtitles = [
      widget.droneId,
      '${widget.droneId} · Live telemetry',
      '${widget.droneId} · Live RTSP',
      '${widget.droneId} · Auto-uploaded',
      '${widget.droneId} · TCP config',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios, color: AppColors.textPrimary, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titles[_currentIndex],
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    LiveDot(live: _live),
                    const SizedBox(width: 6),
                    Hero(
                      tag: widget.droneId,
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          subtitles[_currentIndex],
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: ThemeModeProvider.instance,
            builder: (context, isDark, _) {
              return IconButton(
                icon: Icon(
                  isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                  color: isDark ? const Color(0xFFFFB84D) : AppColors.primary,
                ),
                tooltip: isDark ? 'Switch to light theme' : 'Switch to dark theme',
                onPressed: () => ThemeModeProvider.instance.toggle(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
        color: AppColors.scaffoldAlt,
      ),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _navItem(0, 'Dashboard', Icons.home_filled),
          _navItem(1, 'Flight', Icons.flight),
          _navItem(2, 'Video', Icons.videocam),
          _navItem(3, 'Graphs', Icons.show_chart_rounded),
          _navItem(4, 'Settings', Icons.settings),
        ],
      ),
    );
  }

  Widget _navItem(int index, String label, IconData icon) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
