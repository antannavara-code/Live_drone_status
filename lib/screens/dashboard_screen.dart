import 'package:flutter/material.dart';

import '../models/drone_status.dart';
import '../models/flight_record.dart';
import '../services/api_service.dart';
import '../services/firestore_service.dart';
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
  late Future<List<DroneStatus>> dronesFuture;
  Future<List<FlightRecord>>? recentFlightsFuture;
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  DroneStatus? selectedDrone;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    dronesFuture = _loadFleetWithRetry();
    dronesFuture.then((drones) {
      if (!mounted || drones.isEmpty) return;
      _selectDrone(drones.first, openDetails: false);
    }).catchError((_) {});
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

  Future<List<DroneStatus>> _loadFleetWithRetry() async {
    Object? lastError;
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        return await FirestoreService.fetchFleet();
      } catch (error) {
        lastError = error;
        if (attempt < 3) {
          await Future<void>.delayed(Duration(seconds: attempt));
        }
      }
    }
    throw Exception(
      'Unable to reach fleet service after 3 attempts: $lastError',
    );
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
    final nextFuture = _loadFleetWithRetry();
    setState(() {
      dronesFuture = nextFuture;
    });
    final drones = await nextFuture;
    if (!mounted || drones.isEmpty) return;
    final active = drones.firstWhere(
      (drone) => drone.droneId == selectedDrone?.droneId,
      orElse: () => drones.first,
    );
    _selectDrone(active, openDetails: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071018),
      body: SafeArea(
        child: FutureBuilder<List<DroneStatus>>(
          future: dronesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF4CE0B3)),
              );
            }
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            final drones = snapshot.data ?? [];
            if (drones.isEmpty) {
              return _buildEmptyState();
            }
            selectedDrone ??= drones.first;

            return LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1060;
                return Row(
                  children: [
                    if (wide) _buildSidebar(drones),
                    Expanded(
                      child: RefreshIndicator(
                        color: const Color(0xFF4CE0B3),
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
              const Icon(
                Icons.cloud_off_rounded,
                color: Color(0xFFFFB84D),
                size: 42,
              ),
              const SizedBox(height: 16),
              const Text(
                'Unable to reach fleet service',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
              const SizedBox(height: 10),
              Text(
                'Backend URL: ${ApiService.baseUrl}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
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
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.radar_rounded, color: Color(0xFF4CE0B3), size: 42),
            SizedBox(height: 14),
            Text(
              'No drones found',
              style: TextStyle(
                color: Colors.white,
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
      color: const Color(0xFF0B1520),
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
                    color: const Color(0xFF4CE0B3).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF4CE0B3)),
                  ),
                  child: const Icon(
                    Icons.flight_takeoff_rounded,
                    color: Color(0xFF4CE0B3),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AeroPulse',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'Fleet operations',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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
          const Padding(
            padding: EdgeInsets.fromLTRB(22, 24, 22, 10),
            child: Text(
              'ACTIVE DRONES',
              style: TextStyle(
                color: Colors.white38,
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
        tileColor: active ? const Color(0xFF132638) : null,
        leading: Icon(
          icon,
          color: active ? const Color(0xFF4CE0B3) : Colors.white54,
          size: 21,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : Colors.white70,
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
        color: const Color(0xFFFF5A6B),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value',
        style: const TextStyle(
          color: Colors.white,
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
          color: active ? const Color(0xFF132638) : const Color(0xFF0F1D2A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF4CE0B3) : Colors.white10,
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
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    drone.mode,
                    style: TextStyle(color: statusColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              drone.batteryDisplay,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
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
        const Text(
          'DASHBOARD',
          style: TextStyle(
            color: Color(0xFF4CE0B3),
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            _statusPill(drone.mode),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${drones.length} drones monitored | ${ApiService.baseUrl}',
          style: const TextStyle(color: Colors.white54, fontSize: 13),
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
            style: const TextStyle(color: Colors.white),
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
            backgroundColor: const Color(0xFF132638),
            foregroundColor: Colors.white,
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
            backgroundColor: const Color(0xFF132638),
            foregroundColor: Colors.white,
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
            backgroundColor: const Color(0xFF4CE0B3),
            foregroundColor: const Color(0xFF061018),
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
        const Color(0xFF4CE0B3),
      ),
      _metricCard(
        'GPS',
        drone.gpsDisplay,
        'Navigation lock',
        Icons.satellite_alt_rounded,
        const Color(0xFF6EA8FE),
      ),
      _metricCard(
        'Telemetry',
        drone.speedDisplay,
        'Ground link',
        Icons.cell_tower_rounded,
        const Color(0xFFFFB84D),
      ),
      _metricCard(
        'Mode',
        drone.mode,
        'Flight state',
        Icons.auto_mode_rounded,
        const Color(0xFFC084FC),
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
            style: const TextStyle(
              color: Colors.white54,
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
              style: const TextStyle(
                color: Colors.white,
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
            indicatorColor: const Color(0xFF4CE0B3),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white54,
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
          _detailChip('Battery Voltage', drone.batteryDisplay),
          _detailChip('Armed', drone.armDisplay),
          _detailChip('Flight Mode', drone.mode),
          _detailChip('Telemetry', drone.speedDisplay),
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
            title: 'Satellites',
            value: drone.satellitesDisplay,
            color: const Color(0xFF4CE0B3),
            icon: Icons.satellite_alt_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Armed',
            value: drone.armDisplay,
            color: drone.armed ? Colors.redAccent : Colors.grey,
            icon: Icons.shield_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Flight Mode',
            value: drone.mode,
            color: const Color(0xFFFFB84D),
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
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF4CE0B3)),
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
          return const Center(
            child: Text(
              'No recent flights',
              style: TextStyle(color: Colors.white54),
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
                color: const Color(0xFF101C28),
                child: Stack(
                  children: [
                    CustomPaint(painter: GridPainter(), size: Size.infinite),
                    const Center(
                      child: Icon(
                        Icons.flight_rounded,
                        color: Color(0xFF4CE0B3),
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
                      child: _overlayLabel(drone.mode),
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
            color: const Color(0xFF4CE0B3),
            icon: Icons.satellite_alt_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'GPS',
            value: drone.gpsDisplay,
            color: const Color(0xFF6EA8FE),
            icon: Icons.location_on_rounded,
          ),
          const SizedBox(height: 10),
          StatusTile(
            title: 'Flight Mode',
            value: drone.mode,
            color: const Color(0xFFFFB84D),
            icon: Icons.auto_mode_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildMapCard(DroneStatus drone) {
    return _panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Location Tracking', Icons.map_rounded),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 190,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF10202C)),
                  CustomPaint(painter: MapGridPainter()),
                  const Center(
                    child: Icon(
                      Icons.my_location_rounded,
                      color: Color(0xFFFF5A6B),
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _keyValue('Coordinates', '18.5204 N, 73.8567 E'),
          const SizedBox(height: 8),
          _keyValue('Altitude', drone.altitudeDisplay),
        ],
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
                _keyValue('Battery Voltage', drone.batteryDisplay),
                _keyValue('GPS', drone.gpsDisplay),
                _keyValue('Telemetry', drone.speedDisplay),
                _keyValue('Armed', drone.armDisplay),
                _keyValue('Flight Mode', drone.mode),
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
        color: const Color(0xFF0F1B27),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
        Icon(icon, color: const Color(0xFF4CE0B3), size: 19),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
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
        color: const Color(0xFF132638),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
    final color = complete ? const Color(0xFF4CE0B3) : const Color(0xFFFFB84D);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF132638),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  flight.flownAt,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                style: const TextStyle(color: Colors.white54, fontSize: 12),
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
            style: const TextStyle(color: Colors.white54, fontSize: 13),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
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
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
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
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIcon: Icon(icon, color: Colors.white38),
      filled: true,
      fillColor: const Color(0xFF132638),
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
      return const Color(0xFF4CE0B3);
    }
    if (normalized.contains('STABILIZE') || normalized.contains('ALT_HOLD') || normalized.contains('POSHOLD') || normalized.contains('LAND')) {
      return const Color(0xFFFFB84D);
    }
    return const Color(0xFFFF5A6B);
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
      ..color = const Color(0xFF4CE0B3).withValues(alpha: 0.55)
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
      ..color = const Color(0xFF6EA8FE).withValues(alpha: 0.16)
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
