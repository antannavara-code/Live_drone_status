import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/drone_status.dart';
import '../../services/telemetry_service.dart';
import '../../services/theme_provider.dart';
import '../../widgets/shimmer_loading.dart';

class DashboardTab extends StatefulWidget {
  final String droneId;
  const DashboardTab({super.key, required this.droneId});

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

enum MapLayer { street, satellite, hybrid }

class _DashboardTabState extends State<DashboardTab> with SingleTickerProviderStateMixin {
  final List<LatLng> _flightPath = [];
  final MapController _mapController = MapController();
  bool _initialized = false;
  MapLayer _mapLayer = MapLayer.street;
  DroneStatus? _drone;
  StreamSubscription<DroneStatus>? _sub;

  // GPS + heading smooth animation state
  late AnimationController _gpsCtrl;
  double _dispLat = 0, _dispLng = 0;
  double _fromLat = 0, _fromLng = 0;
  double _tgtLat = 0, _tgtLng = 0;
  double _dispHeading = 0, _fromHeading = 0, _tgtHeading = 0;

  @override
  void initState() {
    super.initState();
    _gpsCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400))
      ..addListener(_onGpsAnim);
    _sub = TelemetryService.droneStream(widget.droneId).listen(_onDroneUpdate);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _gpsCtrl.dispose();
    super.dispose();
  }

  void _onDroneUpdate(DroneStatus drone) {
    if (!mounted) return;
    final hasGps = drone.isConnected && drone.gpsLat != 0.0 && drone.gpsLng != 0.0;
    if (hasGps) {
      if (_dispLat == 0 && _dispLng == 0) {
        _dispLat = drone.gpsLat;
        _dispLng = drone.gpsLng;
      }
      if (_dispHeading == 0 && _tgtHeading == 0) {
        _dispHeading = drone.heading;
        _tgtHeading = drone.heading;
      }

      final pos = LatLng(drone.gpsLat, drone.gpsLng);

      // GPS position deadband (~1m ≈ 0.00001°) — ignore sub-meter jitter
      final dist = math.sqrt(
        math.pow(_tgtLat - drone.gpsLat, 2) + math.pow(_tgtLng - drone.gpsLng, 2),
      );
      if (dist > 0.00001) {
        if (_flightPath.isEmpty || _flightPath.last != pos) {
          _flightPath.add(pos);
          _startGpsAnim(drone.gpsLat, drone.gpsLng, drone.heading);
          if (_initialized) {
            if (dist > 0.0001) {
              _mapController.move(pos, _mapController.camera.zoom);
            }
          }
        }
      }

      // Heading deadband (3°) — ignore compass noise
      final hdgDelta = ((drone.heading - _tgtHeading + 540) % 360) - 180;
      if (hdgDelta.abs() > 3) {
        _tgtHeading = drone.heading;
        _startGpsAnim(drone.gpsLat, drone.gpsLng, drone.heading);
      }
    }
    setState(() => _drone = drone);
  }

  void _onGpsAnim() {
    final t = _gpsCtrl.value;
    final ease = 1 - math.pow(1 - t, 3);
    _dispLat = _fromLat + (_tgtLat - _fromLat) * ease;
    _dispLng = _fromLng + (_tgtLng - _fromLng) * ease;
    final hdgDelta = ((_tgtHeading - _fromHeading + 540) % 360) - 180;
    _dispHeading = (_fromHeading + hdgDelta * ease + 360) % 360;
    setState(() {});
  }

  void _startGpsAnim(double lat, double lng, double heading) {
    _fromLat = _dispLat;
    _fromLng = _dispLng;
    _tgtLat = lat;
    _tgtLng = lng;
    _fromHeading = _dispHeading;
    _tgtHeading = heading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _gpsCtrl.forward(from: 0.0);
    });
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

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildBatteryCard(drone)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGpsCard(drone)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _buildFlightModeCard(drone)),
                      const SizedBox(width: 12),
                      Expanded(child: _buildStatusCard(drone)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 7,
          child: RepaintBoundary(
            child: _MapSection(
              gpsLat: _dispLat,
              gpsLng: _dispLng,
              heading: _dispHeading,
              isConnected: drone.isConnected,
              flightPath: _flightPath,
              mapLayer: _mapLayer,
              onLayerChanged: (layer) => setState(() => _mapLayer = layer),
              mapController: _mapController,
              onMapReady: () {
                _initialized = true;
                if (_dispLat != 0 && _dispLng != 0) {
                  _mapController.move(LatLng(_dispLat, _dispLng), _mapController.camera.zoom);
                }
              },
              windSpeed: drone.windSpeed,
              windDirection: drone.windDirection,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBatteryCard(DroneStatus drone) {
    final batColor = !drone.isConnected
        ? AppColors.textMuted
        : drone.batteryVoltage >= 12.0
            ? AppColors.primary
            : drone.batteryVoltage >= 10.5
                ? AppColors.warningBright
                : AppColors.dangerBright;
    return _staleCard(drone,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bolt, color: Colors.yellow, size: 14),
                const SizedBox(width: 4),
                Text('BATTERY', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.battery_std, color: batColor, size: 32),
                  const SizedBox(width: 8),
                  Text(
                    drone.batteryDisplay,
                    style: TextStyle(
                      color: batColor,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGpsCard(DroneStatus drone) {
    return _staleCard(drone,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.satellite_alt, color: Colors.lightBlueAccent, size: 14),
                const SizedBox(width: 4),
                const Text('GPS STATUS', style: TextStyle(color: Colors.lightBlueAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      drone.isConnected ? '${drone.satellites}' : '--',
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text('SAT COUNT', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlightModeCard(DroneStatus drone) {
    return _staleCard(drone,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.flight, color: Colors.orange, size: 14),
                const SizedBox(width: 4),
                const Text('FLIGHT MODE', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.danger),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(drone.modeDisplay.toUpperCase(), style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 5, height: 5, decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(drone.armDisplay, style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(DroneStatus drone) {
    return _staleCard(drone,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.panelAlt,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed, color: AppColors.warning, size: 14),
                const SizedBox(width: 4),
                Text('STATUS', style: TextStyle(color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
              ],
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(drone.headingDisplay, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('HEADING', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8)),
                    const SizedBox(height: 2),
                    Text(drone.altitudeDisplay, style: TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('ALT', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8)),
                    const SizedBox(height: 2),
                    Text(drone.speedDisplay, style: TextStyle(color: AppColors.info, fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('SPEED', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 8)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

Widget _staleCard(DroneStatus drone, {required Widget child}) {
  return AnimatedOpacity(
    opacity: drone.isStale ? 0.5 : 1.0,
    duration: const Duration(milliseconds: 500),
    child: child,
  );
}

class _MapSection extends StatelessWidget {
  final double gpsLat;
  final double gpsLng;
  final double heading;
  final bool isConnected;
  final List<LatLng> flightPath;
  final MapLayer mapLayer;
  final ValueChanged<MapLayer> onLayerChanged;
  final MapController mapController;
  final VoidCallback onMapReady;
  final double windSpeed;
  final double windDirection;

  const _MapSection({
    required this.gpsLat,
    required this.gpsLng,
    required this.heading,
    this.isConnected = false,
    required this.flightPath,
    required this.mapLayer,
    required this.onLayerChanged,
    required this.mapController,
    required this.onMapReady,
    this.windSpeed = 0.0,
    this.windDirection = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasGps = isConnected && gpsLat != 0.0 && gpsLng != 0.0;
    final fbLat = hasGps ? gpsLat : (TelemetryService.fallbackLat != 0.0 ? TelemetryService.fallbackLat : 20.0);
    final fbLng = hasGps ? gpsLng : (TelemetryService.fallbackLng != 0.0 ? TelemetryService.fallbackLng : 78.0);
    final center = LatLng(fbLat, fbLng);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.push_pin, color: Colors.redAccent, size: 14),
                const SizedBox(width: 4),
                Text('CURRENT LOCATION', style: TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const Spacer(),
                _layerButton(MapLayer.street, 'Street'),
                const SizedBox(width: 4),
                _layerButton(MapLayer.satellite, 'Satellite'),
                const SizedBox(width: 4),
                _layerButton(MapLayer.hybrid, 'Hybrid'),
                const SizedBox(width: 12),
                Text(
                  hasGps
                      ? '${gpsLat.toStringAsFixed(4)}\u00B0N · ${gpsLng.toStringAsFixed(4)}\u00B0E'
                      : 'No GPS fix',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: BoxDecoration(
                color: AppColors.scaffoldAlt,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 16.0,
                    onMapReady: onMapReady,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _tileUrls[mapLayer]!,
                      userAgentPackageName: 'com.example.flutter_app',
                    ),
                    if (mapLayer == MapLayer.hybrid)
                      TileLayer(
                        urlTemplate: _labelsUrl,
                        userAgentPackageName: 'com.example.flutter_app',
                      ),
                    if (flightPath.length >= 2)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: flightPath,
                            color: AppColors.primary,
                            strokeWidth: 3.0,
                          ),
                        ],
                      ),
                    if (hasGps)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: center,
                            width: 40.0,
                            height: 40.0,
                            child: Transform.rotate(
                              angle: heading * 3.14159 / 180.0,
                              child: SvgPicture.asset(
                                'assets/vehicleArrowOutline.svg',
                                width: 32,
                                height: 32,
                                colorFilter: ColorFilter.mode(AppColors.danger, BlendMode.srcIn),
                              ),
                            ),
                          ),
                          if (windSpeed > 0.5)
                            Marker(
                              point: center,
                              width: 80.0,
                              height: 50.0,
                              child: Transform.rotate(
                                angle: windDirection * 3.14159 / 180.0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.arrow_downward, color: Colors.cyanAccent.withValues(alpha: 0.9), size: 20),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: Colors.black54,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        windSpeed.toStringAsFixed(1),
                                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 8, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
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

  static const _tileUrls = {
    MapLayer.street: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    MapLayer.satellite: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    MapLayer.hybrid: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
  };
  static const _labelsUrl = 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}';

  Widget _layerButton(MapLayer layer, String label) {
    final active = mapLayer == layer;
    return GestureDetector(
      onTap: () => onLayerChanged(layer),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.border,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? AppColors.textPrimary : AppColors.textMuted,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
