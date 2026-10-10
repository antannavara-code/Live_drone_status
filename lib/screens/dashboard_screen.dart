import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/drone_status.dart';
import '../models/flight_record.dart';
import '../services/api_service.dart';
import '../services/telemetry_service.dart';
import '../services/theme_provider.dart';
import '../widgets/status_tile.dart';
import 'drone_detail_screen.dart';
import 'qr_generate_screen.dart';
import 'qr_scan_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late Stream<List<DroneStatus>> dronesStream;
  Future<List<FlightRecord>>? recentFlightsFuture;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  DroneStatus? selectedDrone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    dronesStream = TelemetryService.fleetStream();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _selectDrone(DroneStatus drone, {bool openDetails = false}) {
    setState(() {
      selectedDrone = drone;
      recentFlightsFuture = ApiService.fetchRecentFlights(drone.droneId);
    });
    if (openDetails) {
      _openDroneDetails(drone.droneId);
    }
  }

  void _openDroneDetails(String droneId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DroneDetailScreen(droneId: droneId)),
    );
  }

  void _goToManualDrone() {
    final id = _searchController.text.trim().toUpperCase();
    if (id.isEmpty) return;
    _openDroneDetails(id);
  }

  Future<void> _refreshFleet() async {
    // With streams, manual refresh just requires a delay or could reset the stream.
    // For now we just delay to satisfy the RefreshIndicator.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      body: SafeArea(
        child: StreamBuilder<List<DroneStatus>>(
          stream: dronesStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: AppColors.primaryBright),
              );
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final drones = snapshot.data ?? [];
            if (drones.isEmpty) {
              return _buildEmptyState();
            }
            if (selectedDrone == null) {
              selectedDrone = drones.first;
            } else {
              selectedDrone = drones.firstWhere(
                (d) => d.droneId == selectedDrone!.droneId,
                orElse: () => drones.first,
              );
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1060;
                return Row(
                  children: [
                    if (wide) _buildSidebar(drones),
                    Expanded(
                      child: RefreshIndicator(
                        color: AppColors.primaryBright,
                        onRefresh: _refreshFleet,
                        child: _buildDashboard(drones, constraints.maxWidth),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: _panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: AppColors.warningBright,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                'Unable to reach fleet service',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              Text(
                'Backend URL: ${ApiService.baseUrl}',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textFaint, fontSize: 12),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () async {
                  try {
                    await _refreshFleet();
                  } catch (_) {}
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: _panel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_rounded, color: AppColors.primaryBright, size: 42),
            SizedBox(height: 14),
            Text(
              'No drones found',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar(List<DroneStatus> drones) {
    return Container(
      width: 292,
      color: AppColors.sidebar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBright.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primaryBright),
                  ),
                  child: Icon(
                    Icons.flight_takeoff_rounded,
                    color: AppColors.primaryBright,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AeroPulse',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Fleet operations',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _navItem('Dashboard', Icons.dashboard_rounded, active: true),
          _navItem('Fleet', Icons.air_rounded),
          _navItem('Missions', Icons.route_rounded),
          _navItem(
            'Alerts',
            Icons.notifications_active_rounded,
            trailing: _countBadge(3),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 10),
            child: Text(
              'ACTIVE DRONES',
              style: TextStyle(
                color: AppColors.textFaint,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: drones.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final drone = drones[index];
                final active = selectedDrone?.droneId == drone.droneId;
                return _droneListTile(drone, active);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem(
    String label,
    IconData icon, {
    bool active = false,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: ListTile(
        dense: true,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: active ? AppColors.surface : null,
        leading: Icon(
          icon,
          color: active ? AppColors.primaryBright : AppColors.textMuted,
          size: 21,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.textPrimary : AppColors.textSecondary,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
          ),
        ),
        trailing: trailing,
      ),
    );
  }

  Widget _countBadge(int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.dangerBright,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _droneListTile(DroneStatus drone, bool active) {
    final statusColor = _statusColor(drone.status);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _selectDrone(drone),
      onDoubleTap: () => _selectDrone(drone, openDetails: true),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: active ? AppColors.surface : AppColors.tileInactive,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? AppColors.primaryBright : AppColors.borderSubtle,
          ),
        ),
        child: Row(
          children: [
            _statusDot(statusColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    drone.droneId,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    drone.modeDisplay,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              drone.batteryDisplay,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(List<DroneStatus> drones, double width) {
    final drone = selectedDrone ?? drones.first;
    final compact = width < 720;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.all(compact ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(drone, drones, compact),
          const SizedBox(height: 20),
          _buildMetricGrid(drone, compact),
          const SizedBox(height: 20),
          _buildOperationalTabs(drone),
          const SizedBox(height: 20),
          _buildMainArea(drone, width),
          const SizedBox(height: 20),
          _buildTelemetrySummary(drone),
        ],
      ),
    );
  }

  Widget _buildHeader(
    DroneStatus drone,
    List<DroneStatus> drones,
    bool compact,
  ) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DASHBOARD',
          style: TextStyle(
            color: AppColors.primaryBright,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 8,
          children: [
            Text(
              drone.droneId,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            _statusPill(drone.modeDisplay),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${drones.length} drones monitored | ${ApiService.baseUrl}',
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
        ),
      ],
    );

    return _panel(
      padding: const EdgeInsets.all(22),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: _buildSearch()),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 18),
                SizedBox(width: 330, child: _buildSearch()),
              ],
            ),
    );
  }

  Widget _buildSearch() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textCapitalization: TextCapitalization.characters,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: _inputDecoration('Open drone ID', Icons.search_rounded),
            onSubmitted: (_) => _goToManualDrone(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QrGenerateScreen()),
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.qr_code_rounded),
          tooltip: 'Generate QR code',
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const QrScanScreen()),
          ),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.surface,
            foregroundColor: AppColors.textPrimary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.qr_code_scanner_rounded),
          tooltip: 'Scan QR code',
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _goToManualDrone,
          style: IconButton.styleFrom(
            backgroundColor: AppColors.primaryBright,
            foregroundColor: AppColors.textOnAccent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          icon: const Icon(Icons.arrow_forward_rounded),
          tooltip: 'Open drone',
        ),
      ],
    );
  }

  Widget _buildMetricGrid(DroneStatus drone, bool compact) {
    final cards = [
      _metricCard(
        'Battery',
        drone.batteryDisplay,
        drone.batteryPercentDisplay,
        Icons.battery_charging_full_rounded,
        AppColors.primaryBright,
      ),
      _metricCard(
        'GPS',
        drone.gpsDisplay,
        'Navigation lock',
        Icons.satellite_alt_rounded,
        AppColors.blue,
      ),
      _metricCard(
        'Telemetry',
        drone.speedDisplay,
        'Ground link',
        Icons.cell_tower_rounded,
        AppColors.warningBright,
      ),
      _metricCard(
        'Mode',
        drone.modeDisplay,
        'Flight state',
        Icons.auto_mode_rounded,
        AppColors.purple,
      ),
    ];

    if (compact) {
      return GridView.count(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        children: cards,
      );
    }

    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          Expanded(child: cards[i]),
          if (i != cards.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _metricCard(
    String title,
    String value,
    String note,
    IconData icon,
    Color color,
  ) {
    return _panel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
              _statusDot(color),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            note,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color.withValues(alpha: 0.82),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalTabs(DroneStatus drone) {
    return _panel(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.tab,
            indicatorColor: AppColors.primaryBright,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textMuted,
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Systems'),
              Tab(text: 'Flights'),
            ],
          ),
          SizedBox(
            height: 230,
            child: TabBarView(
              controller: _tabController,
              children: [
                _overviewTab(drone),
                _systemsTab(drone),
                _flightsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _overviewTab(DroneStatus drone) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _detailChip('Altitude', drone.altitudeDisplay),
          _detailChip('Heading', drone.headingDisplay),
          _detailChip('Speed', drone.speedDisplay),
          _detailChip('Battery Voltage', drone.batteryDisplay),
          _detailChip('Armed', drone.armDisplay),
          _detailChip('Flight Mode', drone.modeDisplay),
        ],
      ),
    );
  }

  Widget _systemsTab(DroneStatus drone) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          StatusTile(
            title: 'Heading',
            value: drone.headingDisplay,
            color: AppColors.warningBright,
            icon: Icons.explore_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Altitude',
            value: drone.altitudeDisplay,
            color: AppColors.primaryBright,
            icon: Icons.height_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Speed',
            value: drone.speedDisplay,
            color: AppColors.blue,
            icon: Icons.speed_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Satellites',
            value: drone.satellitesDisplay,
            color: AppColors.primaryBright,
            icon: Icons.satellite_alt_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Armed',
            value: drone.armDisplay,
            color: (drone.isConnected && drone.armed) ? Colors.redAccent : Colors.grey,
            icon: Icons.shield_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Flight Mode',
            value: drone.modeDisplay,
            color: AppColors.warningBright,
            icon: Icons.auto_mode_rounded,
          ),
        ],
      ),
    );
  }

  Widget _flightsTab() {
    return FutureBuilder<List<FlightRecord>>(
      future: recentFlightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primaryBright),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Unable to load flights',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
            ),
          );
        }
        final flights = snapshot.data ?? [];
        if (flights.isEmpty) {
          return Center(
            child: Text(
              'No recent flights',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: flights.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final flight = flights[index];
            return _recentFlightTile(flight);
          },
        );
      },
    );
  }

  Widget _buildMainArea(DroneStatus drone, double width) {
    final sideBySide = width >= 1100;
    final feed = _buildLiveFeed(drone);
    final rightColumn = Column(
      children: [
        _buildSystemHealth(drone),
        const SizedBox(height: 20),
        _buildMapCard(drone),
      ],
    );

    if (!sideBySide) {
      return Column(children: [feed, const SizedBox(height: 20), rightColumn]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: feed),
        const SizedBox(width: 20),
        Expanded(flex: 3, child: rightColumn),
      ],
    );
  }

  Widget _buildLiveFeed(DroneStatus drone) {
    return _panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Live Camera Feed', Icons.videocam_rounded),
          const SizedBox(height: 14),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                color: AppColors.videoBg,
                child: Stack(
                  children: [
                    CustomPaint(painter: GridPainter(), size: Size.infinite),
                    Center(
                      child: Icon(
                        Icons.flight_rounded,
                        color: AppColors.primaryBright,
                        size: 64,
                      ),
                    ),
                    Positioned(
                      left: 14,
                      top: 14,
                      child: _overlayLabel('RTSP standby'),
                    ),
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: _overlayLabel(drone.modeDisplay),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemHealth(DroneStatus drone) {
    return _panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle('System Health', Icons.health_and_safety_rounded),
          const SizedBox(height: 14),
          StatusTile(
            title: 'Satellites',
            value: drone.satellitesDisplay,
            color: AppColors.primaryBright,
            icon: Icons.satellite_alt_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'GPS',
            value: drone.gpsLat == 0 && drone.gpsLng == 0
                ? 'No GPS fix'
                : drone.gpsDisplay,
            color: AppColors.blue,
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Heading',
            value: drone.headingDisplay,
            color: AppColors.warningBright,
            icon: Icons.explore_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Flight Mode',
            value: drone.modeDisplay,
            color: AppColors.warningBright,
            icon: Icons.auto_mode_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Altitude',
            value: drone.altitudeDisplay,
            color: AppColors.primaryBright,
            icon: Icons.height_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(DroneStatus drone) {
    final hasGps = drone.isConnected && (drone.gpsLat != 0 || drone.gpsLng != 0);
    final fbLat = hasGps ? drone.gpsLat : (TelemetryService.fallbackLat != 0.0 ? TelemetryService.fallbackLat : 20.0);
    final fbLng = hasGps ? drone.gpsLng : (TelemetryService.fallbackLng != 0.0 ? TelemetryService.fallbackLng : 78.0);
    final center = LatLng(fbLat, fbLng);
    return _panel(
      padding: const EdgeInsets.all(18),
      child: AnimatedOpacity(
        opacity: drone.isStale ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 500),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Location Tracking', Icons.map_rounded),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 190,
              child: FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.fynex.app',
                    ),
                    if (hasGps)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(drone.gpsLat, drone.gpsLng),
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.flight,
                              color: AppColors.dangerBright,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
            ),
          ),
          const SizedBox(height: 14),
          _keyValue(
            'Coordinates',
            hasGps ? drone.gpsDisplay : 'No GPS fix',
          ),
          const SizedBox(height: 8),
          _keyValue('Altitude', drone.altitudeDisplay),
        ],
      ),
    ),
  );
}

  Widget _buildTelemetrySummary(DroneStatus drone) {
    return _panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Telemetry Summary', Icons.insights_rounded),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 680;
              final rows = [
                _keyValue('Drone', drone.droneId),
                _keyValue('Battery', drone.batteryDisplay),
                _keyValue('Heading', drone.headingDisplay),
                _keyValue('GPS', drone.gpsDisplay),
                _keyValue('Speed', drone.speedDisplay),
                _keyValue('Altitude', drone.altitudeDisplay),
                _keyValue('Armed', drone.armDisplay),
                _keyValue('Flight Mode', drone.modeDisplay),
              ];
              if (narrow) {
                return Column(
                  children: rows
                      .map(
                        (row) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: row,
                        ),
                      )
                      .toList(),
                );
              }
              return Wrap(
                spacing: 28,
                runSpacing: 12,
                children: rows
                    .map(
                      (row) => SizedBox(
                        width: constraints.maxWidth / 2 - 20,
                        child: row,
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _panel({required Widget child, EdgeInsetsGeometry? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryBright, size: 19),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _detailChip(String label, String value) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentFlightTile(FlightRecord flight) {
    final complete = flight.status.toLowerCase() == 'completed';
    final color = complete ? AppColors.primaryBright : AppColors.warningBright;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Icon(
            complete ? Icons.check_circle_rounded : Icons.warning_rounded,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  flight.missionName,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  flight.flownAt,
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                flight.status,
                style: TextStyle(color: color, fontWeight: FontWeight.w800),
              ),
              Text(
                flight.distance,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _keyValue(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
          style: TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _statusDot(color),
          const SizedBox(width: 7),
          Text(
            status,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _overlayLabel(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 6),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.textFaint),
      prefixIcon: Icon(icon, color: AppColors.textFaint),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
    );
  }

  Color _statusColor(String mode) {
    final normalized = mode.toUpperCase();
    if (normalized.contains('AUTO') || normalized.contains('GUIDED') || normalized.contains('LOITER') || normalized.contains('RTL')) {
      return AppColors.primaryBright;
    }
    if (normalized.contains('STABILIZE') || normalized.contains('ALT_HOLD') || normalized.contains('POSHOLD') || normalized.contains('LAND')) {
      return AppColors.warningBright;
    }
    return AppColors.dangerBright;
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += 38) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += 38) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final target = Paint()
      ..color = AppColors.primaryBright.withValues(alpha: 0.55)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, 48, target);
    canvas.drawCircle(center, 86, target);
    canvas.drawLine(
      Offset(center.dx - 90, center.dy),
      Offset(center.dx + 90, center.dy),
      target,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 70),
      Offset(center.dx, center.dy + 70),
      target,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.blue.withValues(alpha: 0.16)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    for (double radius = 28; radius < size.shortestSide; radius += 34) {
      canvas.drawCircle(center, radius, paint);
    }
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      paint,
    );
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
