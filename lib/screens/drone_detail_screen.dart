import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/drone_status.dart';

class DroneDetailScreen extends StatelessWidget {
  final String droneId;
  const DroneDetailScreen({super.key, required this.droneId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0d1117),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drones')
              .doc(droneId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Color(0xFF00e676)));
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.flight_rounded, color: Color(0xFF00e676), size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'Drone not found.\nMake sure the Jetson script is running.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final drone = DroneStatus.fromJson(data);

            return _DashboardLayout(drone: drone);
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAIN DASHBOARD LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardLayout extends StatelessWidget {
  final DroneStatus drone;
  const _DashboardLayout({required this.drone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopBar(drone: drone),
        Expanded(
          child:           LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 720;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: narrow ? _buildNarrow() : _buildWide(),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNarrow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusRow(drone: drone),
        const SizedBox(height: 12),
        _SystemHealthPanel(drone: drone),
        const SizedBox(height: 12),
        _ComponentPanel(drone: drone),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: _MapPanel(drone: drone),
        ),
      ],
    );
  }

  Widget _buildWide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusRow(drone: drone),
        const SizedBox(height: 12),
        _SystemHealthPanel(drone: drone),
        const SizedBox(height: 12),
        _ComponentPanel(drone: drone),
        const SizedBox(height: 12),
        SizedBox(
          height: 250,
          child: _MapPanel(drone: drone),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final DroneStatus drone;
  const _TopBar({required this.drone});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF161b22),
        border: Border(bottom: BorderSide(color: Color(0xFF21262d))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white70, size: 18),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const Text('Drone ID: ', style: TextStyle(color: Color(0xFF8b949e), fontSize: 13)),
                  Text(drone.droneId, style: const TextStyle(color: Color(0xFF00e676), fontSize: 14, fontWeight: FontWeight.w700)),
                ],
              ),
              Text('Last Updated: just now', style: TextStyle(color: Color(0xFF8b949e).withValues(alpha: 0.7), fontSize: 10)),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF00e676).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF00e676)),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('ONLINE', style: TextStyle(color: Color(0xFF00e676), fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          // ── Battery ──────────────────────────────────────────────
          _TopBarStat(
            icon: Icons.battery_full_rounded,
            iconColor: const Color(0xFF00e676),
            value: '${drone.batteryPercent}%',
            label: 'Battery Health',
          ),
          const SizedBox(width: 20),
          // ── GPS ──────────────────────────────────────────────────
          _TopBarStat(
            icon: Icons.satellite_alt_rounded,
            iconColor: const Color(0xFF40c4ff),
            value: 'GPS',
            label: '${drone.satellites} Satellites',
          ),
          const SizedBox(width: 20),
          // ── Signal ───────────────────────────────────────────────
          _TopBarStat(
            icon: Icons.signal_cellular_alt_rounded,
            iconColor: const Color(0xFF69f0ae),
            value: 'Signal',
            label: 'Strong',
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

}

// ── Reusable top-bar stat (icon + bold value + coloured sub-label) ────────────
class _TopBarStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _TopBarStat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF00e676),
                fontSize: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATUS ROW — 5 cards
// ─────────────────────────────────────────────────────────────────────────────
class _StatusRow extends StatelessWidget {
  final DroneStatus drone;
  const _StatusRow({required this.drone});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          _BatteryCard(drone: drone),
          _StatusCard(
            label: 'GPS STATUS',
            icon: '📡',
            value: '${drone.satellites}',
            sub: 'Satellites Locked',
            color: const Color(0xFF2979ff),
            child: _GpsBars(count: drone.satellites),
          ),
          _StatusCard(
            label: 'JETSON STATUS',
            icon: '💻',
            value: drone.isConnected ? 'Connected' : 'Disconnected',
            sub: 'Orin NX',
            color: drone.isConnected ? const Color(0xFF00e676) : const Color(0xFFf44336),
            child: _FlatSparkline(color: drone.isConnected ? const Color(0xFF00e676) : const Color(0xFFf44336)),
          ),
          _StatusCard(
            label: 'FLIGHT MODE',
            icon: '✈️',
            value: drone.mode,
            sub: drone.armed ? 'Armed' : 'Disarmed',
            color: const Color(0xFF2979ff),
            child: _FlatSparkline(color: const Color(0xFF2979ff)),
          ),
        ];

        if (constraints.maxWidth < 600) {
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 16) / 2 - 4, child: c)).toList(),
          );
        }
        return Row(
          children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 8), child: c))).toList(),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String label;
  final String icon;
  final String value;
  final String sub;
  final Color color;
  final Widget child;
  const _StatusCard({required this.label, required this.icon, required this.value, required this.sub, required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2230),
        border: Border.all(color: const Color(0xFF21262d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF8b949e), fontSize: 9, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(sub, style: TextStyle(color: color, fontSize: 10)),
          const SizedBox(height: 4),
          SizedBox(height: 24, child: child),
        ],
      ),
    );
  }

}

class _BatteryCard extends StatelessWidget {
  final DroneStatus drone;
  const _BatteryCard({required this.drone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1c2230),
        border: Border.all(color: const Color(0xFF21262d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BATTERY', style: const TextStyle(color: Color(0xFF8b949e), fontSize: 9, letterSpacing: 1)),
              const SizedBox(height: 4),
              Text('🔋', style: const TextStyle(fontSize: 18)),
              const SizedBox(height: 2),
              Text('${drone.batteryPercent}%', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              SizedBox(height: 24, width: 80, child: _BatterySparkline(pct: drone.batteryPercent / 100)),
            ],
          ),
          const Spacer(),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${drone.batteryDisplay}  ${drone.batteryCurrent > 0 ? drone.batteryCurrentDisplay : "--"}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('${drone.batteryTemperature > 0 ? drone.batteryTemperatureDisplay : "--"}  ${drone.cellCount > 0 ? drone.cellDisplay : "--"}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BatterySparkline extends StatelessWidget {
  final double pct;
  const _BatterySparkline({required this.pct});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(double.infinity, 24), painter: _SparkPainter(pct, const Color(0xFF00e676)));
  }
}

class _FlatSparkline extends StatelessWidget {
  final Color color;
  const _FlatSparkline({required this.color});
  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: const Size(double.infinity, 24), painter: _FlatSparkPainter(color));
  }
}

class _GpsBars extends StatelessWidget {
  final int count;
  const _GpsBars({required this.count});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(12, (i) {
        final h = i < count ? (0.3 + (i / 12) * 0.7) : 0.1;
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            height: 24 * h,
            decoration: BoxDecoration(
              color: i < count ? const Color(0xFF2979ff) : const Color(0xFF21262d),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            ),
          ),
        );
      }),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final double pct;
  final Color color;
  _SparkPainter(this.pct, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    final pts = <double>[0.2, 0.6, 0.4, 0.5, 0.6, 0.4, 0.8, 0.5, 1.0, 0.3];
    path.moveTo(0, size.height * pts[1]);
    for (int i = 1; i < pts.length ~/ 2; i++) {
      path.lineTo(size.width * pts[i * 2], size.height * pts[i * 2 + 1]);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.pct != pct;
}

class _FlatSparkPainter extends CustomPainter {
  final Color color;
  _FlatSparkPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(0, size.height * 0.5);
    for (int i = 1; i < 20; i++) {
      path.lineTo(size.width * i / 19, size.height * (0.3 + 0.4 * math.sin(i * 0.5)));
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FlatSparkPainter old) => false;
}



// ─────────────────────────────────────────────────────────────────────────────
// SYSTEM HEALTH PANEL — 3x3 sensor grid + CPU + status
// ─────────────────────────────────────────────────────────────────────────────
class _SystemHealthPanel extends StatelessWidget {
  final DroneStatus drone;
  const _SystemHealthPanel({required this.drone});

  @override
  Widget build(BuildContext context) {
    final score = drone.systemHealthScore;
    final scorePct = (score * 100).toInt();
    final sysStatus = drone.systemStatusString;

    Color statusColor;
    String statusEmoji;
    if (sysStatus == 'ACTIVE' || sysStatus == 'STANDBY') {
      statusColor = const Color(0xFF00e676);
      statusEmoji = '🟢';
    } else if (sysStatus == 'CRITICAL') {
      statusColor = const Color(0xFFf39c12);
      statusEmoji = '🟡';
    } else if (sysStatus == 'EMERGENCY' || sysStatus == 'FLIGHT_TERM') {
      statusColor = const Color(0xFFf44336);
      statusEmoji = '🔴';
    } else {
      statusColor = const Color(0xFF8b949e);
      statusEmoji = '⚪';
    }

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1c2230),
        border: Border.all(color: const Color(0xFF21262d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF21262d))),
            ),
            child: Row(
              children: [
                const Text('🛡️ SYSTEM HEALTH', style: TextStyle(color: Color(0xFF8b949e), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('$scorePct%', style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          // 3x3 sensor grid
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              childAspectRatio: 1.6,
              children: drone.gridSensors.map((s) {
                final healthy = s.isHealthy(drone.sensorHealthMask);
                final present = s.isPresent(drone.sensorPresentMask);
                final okColor = present ? (healthy ? const Color(0xFF00e676) : const Color(0xFFf44336)) : const Color(0xFF8b949e);
                return Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF161b22),
                    border: Border.all(color: okColor.withValues(alpha: 0.4)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(s.emoji, style: const TextStyle(fontSize: 14)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(s.label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      _sensorValue(s, drone, present, healthy),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          // CPU load bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Text('🧠 CPU', style: const TextStyle(color: Color(0xFF8b949e), fontSize: 9)),
                    const Spacer(),
                    Text(drone.cpuLoadDisplay, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 2),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: drone.cpuLoad / 100.0,
                    backgroundColor: const Color(0xFF21262d),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      drone.cpuLoad < 50 ? const Color(0xFF00e676) : (drone.cpuLoad < 80 ? const Color(0xFFf39c12) : const Color(0xFFf44336)),
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ),
          // Status badge
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Row(
              children: [
                Text(statusEmoji, style: const TextStyle(fontSize: 10)),
                const SizedBox(width: 4),
                Text(sysStatus, style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('⬇ ${drone.dropRateDisplay}', style: const TextStyle(color: Color(0xFF8b949e), fontSize: 8)),
                const SizedBox(width: 8),
                Text(drone.errorsCommDisplay, style: const TextStyle(color: Color(0xFF8b949e), fontSize: 8)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sensorValue(SensorDef s, DroneStatus drone, bool present, bool healthy) {
    if (!present) {
      return Text('N/A', style: TextStyle(color: Colors.grey, fontSize: 8));
    }
    switch (s.label) {
      case 'Gyro':
        return Text(drone.gyroDisplay, style: TextStyle(color: Colors.white70, fontSize: 7, fontFamily: 'monospace'));
      case 'Accel':
        return Text(drone.accelDisplay, style: TextStyle(color: Colors.white70, fontSize: 7, fontFamily: 'monospace'));
      case 'Compass':
        return Text(drone.headingDisplay, style: TextStyle(color: Colors.white70, fontSize: 8, fontFamily: 'monospace'));
      case 'Baro':
        return Text(drone.altitudeDisplay, style: TextStyle(color: Colors.white70, fontSize: 8, fontFamily: 'monospace'));
      case 'GPS':
        return Text('${drone.satellites} sats', style: TextStyle(color: Colors.white70, fontSize: 8, fontFamily: 'monospace'));
      case 'Motor':
        return Text('${drone.throttle}%', style: TextStyle(color: Colors.white70, fontSize: 8, fontFamily: 'monospace'));
      default:
        return Text(healthy ? 'OK' : 'FAIL', style: TextStyle(color: healthy ? const Color(0xFF00e676) : const Color(0xFFf44336), fontSize: 8));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// MAP PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _MapPanel extends StatelessWidget {
  final DroneStatus drone;
  const _MapPanel({required this.drone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1c2230),
        border: Border.all(color: const Color(0xFF21262d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF21262d))),
            ),
            child: const Text('CURRENT LOCATION', style: TextStyle(color: Color(0xFF8b949e), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Stack(
              children: [
                CustomPaint(size: const Size(double.infinity, double.infinity), painter: _MapPainter()),
                Positioned(
                  left: 6, bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      'Lat: ${drone.gpsLat.toStringAsFixed(4)}° N  Lng: ${drone.gpsLng.toStringAsFixed(4)}° E\nAlt: ${drone.altitudeDisplay}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                Positioned(
                  right: 6, top: 60,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1c2230),
                          border: Border.all(color: const Color(0xFF21262d)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(child: Text('+', style: TextStyle(color: Colors.white, fontSize: 14))),
                      ),
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1c2230),
                          border: Border.all(color: const Color(0xFF21262d)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Center(child: Text('−', style: TextStyle(color: Colors.white, fontSize: 14))),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = const Color(0xFF2a3a20));

    final w = size.width / 4;
    final h = size.height / 3;
    final colors = [const Color(0xFF263318), const Color(0xFF324220), const Color(0xFF2a3c1c)];
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < 4; c++) {
        canvas.drawRect(Rect.fromLTWH(c * w, r * h, w, h), Paint()..color = colors[(r + c) % colors.length]);
      }
    }

    final river = Paint()..color = const Color(0xFF4a7a9b).withValues(alpha: 0.5)..style = PaintingStyle.stroke..strokeWidth = 4;
    final rp = Path();
    rp.moveTo(size.width * 0.1, size.height * 0.2);
    rp.quadraticBezierTo(size.width * 0.3, size.height * 0.4, size.width * 0.5, size.height * 0.5);
    rp.quadraticBezierTo(size.width * 0.7, size.height * 0.6, size.width * 0.9, size.height * 0.45);
    canvas.drawPath(rp, river);

    final flightPath = Paint()..color = const Color(0xFF00e676).withValues(alpha: 0.7)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    final fp = Path();
    fp.moveTo(size.width * 0.85, size.height * 0.8);
    fp.lineTo(size.width * 0.7, size.height * 0.65);
    fp.lineTo(size.width * 0.55, size.height * 0.5);
    fp.lineTo(size.width * 0.4, size.height * 0.38);
    fp.lineTo(size.width * 0.25, size.height * 0.3);
    canvas.drawPath(fp, flightPath);

    final markerBlue = Paint()..color = const Color(0xFF2979ff);
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.5), 8, Paint()..color = const Color(0xFF2979ff).withValues(alpha: 0.3));
    canvas.drawCircle(Offset(size.width * 0.55, size.height * 0.5), 4, markerBlue);

    canvas.drawCircle(Offset(size.width * 0.85, size.height * 0.8), 4, Paint()..color = const Color(0xFF00e676));
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.3), 4, Paint()..color = const Color(0xFF00e676));
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT STATUS PANEL
// ─────────────────────────────────────────────────────────────────────────────
class _ComponentPanel extends StatelessWidget {
  final DroneStatus drone;
  const _ComponentPanel({required this.drone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1c2230),
        border: Border.all(color: const Color(0xFF21262d)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF21262d))),
            ),
            child: const Text('COMPONENT STATUS', style: TextStyle(color: Color(0xFF8b949e), fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700)),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _compRow('Camera', 'Connected', '1080p 30fps', true),
                const Divider(color: Color(0xFF21262d), height: 1),
                _compRow('GPS Module', drone.gpsHealthy ? 'Connected' : 'Fault', '${drone.satellites} sats', drone.gpsHealthy),
                const Divider(color: Color(0xFF21262d), height: 1),
                _compRow('Telemetry Radio', drone.dropRate < 5 ? 'Good' : 'Degraded', '${drone.errorsComm} errors', drone.dropRate < 5),
                const Divider(color: Color(0xFF21262d), height: 1),
                _compRow('Jetson Orin NX', 'Online', drone.cpuLoadDisplay, true),
                const Divider(color: Color(0xFF21262d), height: 1),
                _compRow('Storage', 'Healthy', '120 GB Free', true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compRow(String comp, String status, String detail, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: ok ? const Color(0xFF00e676) : const Color(0xFFffc107), shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(comp, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(status, style: const TextStyle(color: Color(0xFF00e676), fontSize: 10)),
          const SizedBox(width: 8),
          Text(detail, style: const TextStyle(color: Color(0xFF8b949e), fontSize: 9)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
