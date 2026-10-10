import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

class AttitudeVisualizer extends StatefulWidget {
  final double roll;
  final double pitch;
  final double yaw;
  final double heading;
  final double altitude;
  final double groundSpeed;
  final double batteryPercent;
  final String flightMode;

  const AttitudeVisualizer({
    super.key,
    required this.roll,
    required this.pitch,
    required this.yaw,
    this.heading = 0,
    this.altitude = 0,
    this.groundSpeed = 0,
    this.batteryPercent = 0,
    this.flightMode = '---',
  });

  @override
  State<AttitudeVisualizer> createState() => _AttitudeVisualizerState();
}

class _AttitudeVisualizerState extends State<AttitudeVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  // Current displayed (animated) values
  double dispRoll = 0, dispPitch = 0, dispYaw = 0;
  double dispAlt = 0, dispSpd = 0, dispBat = 0;
  String dispMode = '---';

  // Target values (will animate toward these)
  double _tgtRoll = 0, _tgtPitch = 0, _tgtYaw = 0;
  double _tgtAlt = 0, _tgtSpd = 0, _tgtBat = 0;
  String _tgtMode = '---';

  // Snapshot of start values for each animation segment
  double _fromRoll = 0, _fromPitch = 0, _fromYaw = 0;
  double _fromAlt = 0, _fromSpd = 0, _fromBat = 0;


  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..addListener(_onAnim);
    _syncTarget(widget);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _syncTarget(AttitudeVisualizer w) {
    _fromRoll = dispRoll;
    _fromPitch = dispPitch;
    _fromYaw = dispYaw;
    _fromAlt = dispAlt;
    _fromSpd = dispSpd;
    _fromBat = dispBat;
    _tgtRoll = w.roll;
    _tgtPitch = w.pitch;
    _tgtYaw = w.yaw;
    _tgtAlt = w.altitude;
    _tgtSpd = w.groundSpeed;
    _tgtBat = w.batteryPercent;
    _tgtMode = w.flightMode;
    _ctrl.forward(from: 0.0);
  }

  void _onAnim() {
    final t = _ctrl.value;
    final ease = 1 - math.pow(1 - t, 3); // cubic ease-out
    dispRoll = _fromRoll + (_tgtRoll - _fromRoll) * ease;
    dispPitch = _fromPitch + (_tgtPitch - _fromPitch) * ease;
    dispYaw = _fromYaw + (_tgtYaw - _fromYaw) * ease;
    dispAlt = _fromAlt + (_tgtAlt - _fromAlt) * ease;
    dispSpd = _fromSpd + (_tgtSpd - _fromSpd) * ease;
    dispBat = _fromBat + (_tgtBat - _fromBat) * ease;
    if (t >= 1) {
      dispMode = _tgtMode;
    }
    setState(() {});
  }

  bool _valueChanged(AttitudeVisualizer w) {
    return w.roll != _tgtRoll || w.pitch != _tgtPitch || w.yaw != _tgtYaw ||
           w.altitude != _tgtAlt || w.groundSpeed != _tgtSpd ||
           w.batteryPercent != _tgtBat || w.flightMode != _tgtMode;
  }

  @override
  void didUpdateWidget(AttitudeVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_valueChanged(widget)) {
      _syncTarget(widget);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TitleBar(),
        const SizedBox(height: 4),
        SizedBox(
          width: 360,
          height: 260,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: Drone3DPainter(roll: dispRoll, pitch: dispPitch, yaw: dispYaw),
              size: const Size(360, 260),
            ),
          ),
        ),
        const SizedBox(height: 4),
        _HudRow(pitch: dispPitch, roll: dispRoll, yaw: dispYaw, altitude: dispAlt),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 174,
              height: 78,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: PitchLadderPainter(pitch: dispPitch),
                  size: const Size(174, 78),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 174,
              height: 78,
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: RollIndicatorPainter(roll: dispRoll),
                  size: const Size(174, 78),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _TelemetryRow(yaw: dispYaw, spd: dispSpd, bat: dispBat, mode: dispMode),
      ],
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────

class _TitleBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 28,
      child: Center(
        child: Text(
          '3D Attitude Visualizer',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFc8cdd4)),
        ),
      ),
    );
  }
}

class _HudRow extends StatelessWidget {
  final double pitch, roll, yaw, altitude;
  const _HudRow({required this.pitch, required this.roll, required this.yaw, required this.altitude});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _box('Pitch', '${pitch.toStringAsFixed(1)}\u00B0', const Color(0xFFe8a838)),
        const SizedBox(width: 6),
        _box('Roll', '${roll.toStringAsFixed(1)}\u00B0', AppColors.blueBright),
        const SizedBox(width: 6),
        _box('Yaw', '${((yaw + 360) % 360).toStringAsFixed(1)}\u00B0', const Color(0xFFc8cdd4)),
        const SizedBox(width: 6),
        _box('Alt', '${altitude.toStringAsFixed(2)} m', const Color(0xFF5db85d)),
      ],
    );
  }

  Widget _box(String label, String value, Color color) {
    return Container(
      width: 84,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.scaffoldAlt,
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        children: [
          const SizedBox(height: 3),
          Text(label.toUpperCase(), style: const TextStyle(fontSize: 8, color: Color(0xFF555555))),
          const SizedBox(height: 1),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class _TelemetryRow extends StatelessWidget {
  final double yaw, spd, bat;
  final String mode;
  const _TelemetryRow({required this.yaw, required this.spd, required this.bat, required this.mode});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.scaffoldAlt,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _item('HDG:', '${((yaw + 360) % 360).toInt()}\u00B0'),
          const SizedBox(width: 12),
          _item('SPD:', '${spd.toStringAsFixed(1)} m/s'),
          const SizedBox(width: 12),
          _item('BAT:', '${bat.toInt()}%'),
          const SizedBox(width: 12),
          _item('MODE:', mode),
        ],
      ),
    );
  }

  Widget _item(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 10, color: Color(0xFF555555)),
        children: [
          TextSpan(text: label),
          TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFc8cdd4))),
        ],
      ),
    );
  }
}

// ─── 3D Drone Canvas ──────────────────────────────────────────────

class Drone3DPainter extends CustomPainter {
  final double roll;
  final double pitch;
  final double yaw;

  Drone3DPainter({required this.roll, required this.pitch, required this.yaw});

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height, CX = W / 2, CY = H / 2;

    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = AppColors.videoBg);

    final pR = -pitch * math.pi / 180;
    final rR = -roll * math.pi / 180;
    final yR = yaw * math.pi / 180;

    Offset project(double x, double y, double z) {
      final cosR = math.cos(rR), sinR = math.sin(rR);
      final cosP = math.cos(pR), sinP = math.sin(pR);
      final cosY = math.cos(yR), sinY = math.sin(yR);
      var x1 = cosR * x - sinR * y, y1 = sinR * x + cosR * y, z1 = z;
      var y2 = cosP * y1 - sinP * z1, z2 = sinP * y1 + cosP * z1, x2 = x1;
      var x3 = cosY * x2 + sinY * z2, z3 = -sinY * x2 + cosY * z2, y3 = y2;
      const fov = 320.0;
      var scale = fov / math.max(z3 + 5, 0.1);
      return Offset(CX + x3 * scale, CY - y3 * scale);
    }

    // Ground grid
    final gridP = Paint()..color = const Color(0x66464853)..strokeWidth = 0.5;
    for (int i = -4; i <= 4; i++) {
      final a = project(-4, 0, i.toDouble()), b = project(4, 0, i.toDouble());
      canvas.drawLine(a, b, gridP);
      final c = project(i.toDouble(), 0, -4), d = project(i.toDouble(), 0, 4);
      canvas.drawLine(c, d, gridP);
    }

    const armLen = 1.5, bodyHalf = 0.22, thick = 0.08, propR = 0.55;

    // Body cube
    List<List<double>> bodyPts = [
      [-bodyHalf, -thick, -bodyHalf], [bodyHalf, -thick, -bodyHalf],
      [bodyHalf, -thick, bodyHalf], [-bodyHalf, -thick, bodyHalf],
      [-bodyHalf, thick, -bodyHalf], [bodyHalf, thick, -bodyHalf],
      [bodyHalf, thick, bodyHalf], [-bodyHalf, thick, bodyHalf],
    ];
    final bp = bodyPts.map((p) => project(p[0], p[1], p[2])).toList();

    List<List<dynamic>> faces = [
      [4, 5, 6, 7, AppColors.videoBg],
      [0, 1, 2, 3, AppColors.videoBg],
      [0, 1, 5, 4, AppColors.videoBg],
      [2, 3, 7, 6, AppColors.videoBg],
      [0, 3, 7, 4, AppColors.videoBg],
      [1, 2, 6, 5, AppColors.videoBg],
    ];
    final bodyStroke = Paint()..color = AppColors.videoBg..strokeWidth = 0.5..style = PaintingStyle.stroke;
    for (final face in faces) {
      final path = Path()
        ..moveTo(bp[face[0] as int].dx, bp[face[0] as int].dy)
        ..lineTo(bp[face[1] as int].dx, bp[face[1] as int].dy)
        ..lineTo(bp[face[2] as int].dx, bp[face[2] as int].dy)
        ..lineTo(bp[face[3] as int].dx, bp[face[3] as int].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = face[4] as Color);
      canvas.drawPath(path, bodyStroke);
    }

    // Arms
    List<List<double>> armEnds = [
      [armLen, 0, armLen], [-armLen, 0, armLen],
      [armLen, 0, -armLen], [-armLen, 0, -armLen],
    ];
    List<Color> armColors = [
      const Color(0xFFe8a838), const Color(0xFFe8a838),
      const Color(0xFF555555), const Color(0xFF555555),
    ];
    final origin = project(0, 0, 0);
    final armP = Paint()..strokeWidth = 4..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    for (int a = 0; a < 4; a++) {
      final ep = project(armEnds[a][0], armEnds[a][1], armEnds[a][2]);
      armP.color = armColors[a];
      canvas.drawLine(origin, ep, armP);
    }

    // Nose marker
    final noseTip = project(0, 0, bodyHalf + 0.4);
    final noseL = project(-0.15, 0, bodyHalf + 0.1);
    final noseR = project(0.15, 0, bodyHalf + 0.1);
    final nosePath = Path()
      ..moveTo(noseTip.dx, noseTip.dy)
      ..lineTo(noseL.dx, noseL.dy)
      ..lineTo(noseR.dx, noseR.dy)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = const Color(0xFFe8a838));
    _drawText(canvas, 'FRONT', noseTip.dx, noseTip.dy - 8, const Color(0xFFe8a838), 9);

    // Props
    for (int p = 0; p < 4; p++) {
      final mt = armEnds[p];
      final mc = project(mt[0], mt[1], mt[2]);
      canvas.drawCircle(mc, 5, Paint()..color = AppColors.videoBg);
      canvas.drawCircle(mc, 5, Paint()..color = armColors[p]..style = PaintingStyle.stroke..strokeWidth = 1.5);
      final pa = (pitch.abs() > 30 || roll.abs() > 30) ? 0.5 : 0.7;
      final dir = p % 2 == 0 ? 1 : -1;
      for (int b = 0; b < 2; b++) {
        final ang = b * math.pi;
        final ex = mt[0] + propR * math.cos(ang) * dir;
        final ez = mt[2] + propR * math.sin(ang);
        final pe = project(ex, mt[1], ez);
        canvas.drawLine(mc, pe, Paint()..color = armColors[p].withValues(alpha: pa)..strokeWidth = 2.5);
      }
    }

    // XYZ axes
    const axLen = 1.8;
    final axOrigin = project(0, 0, 0);
    final axes = [
      [axLen, 0.0, 0.0, const Color(0xFFe05454), 'X'],
      [0.0, axLen, 0.0, const Color(0xFF5db85d), 'Y'],
      [0.0, 0.0, axLen, AppColors.blueBright, 'Z'],
    ];
    for (final ax in axes) {
      final ep = project(ax[0] as double, ax[1] as double, ax[2] as double);
      canvas.drawLine(axOrigin, ep, Paint()..color = ax[3] as Color..strokeWidth = 1.5);
      _drawText(canvas, ax[4] as String, ep.dx, ep.dy - 5, ax[3] as Color, 11);
    }

    // Border
    final isCritical = pitch.abs() > 35 || roll.abs() > 35;
    canvas.drawRect(
      Rect.fromLTWH(2, 2, W - 4, H - 4),
      Paint()..color = AppColors.videoBg..strokeWidth = isCritical ? 2.0 : 1.5..style = PaintingStyle.stroke,
    );
  }

  void _drawText(Canvas canvas, String text, double x, double y, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.bold)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height));
  }

  @override
  bool shouldRepaint(Drone3DPainter old) => old.roll != roll || old.pitch != pitch || old.yaw != yaw;
}

// ─── Pitch Ladder ────────────────────────────────────────────────

class PitchLadderPainter extends CustomPainter {
  final double pitch;
  PitchLadderPainter({required this.pitch});

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height, CX = W / 2, CY = H / 2;

    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = AppColors.videoBg);

    final gridP = Paint()..color = const Color(0x0fffffff)..strokeWidth = 0.5;
    for (double i = 0; i < W; i += 20) canvas.drawLine(Offset(i, 0), Offset(i, H), gridP);

    final skyH = (CY + pitch * 2).clamp(0.0, H);

    canvas.drawRect(Rect.fromLTWH(0, 0, W, skyH), Paint()..color = Colors.lightBlue.shade200);
    canvas.drawRect(Rect.fromLTWH(0, skyH, W, H - skyH), Paint()..color = Colors.green);

    canvas.drawLine(Offset(CX - 40, skyH), Offset(CX + 40, skyH),
      Paint()..color = AppColors.blueBright..strokeWidth = 1.5);

    final tickP = Paint()..color = AppColors.textPrimary..strokeWidth = 0.8;
    for (int deg = -40; deg <= 40; deg += 10) {
      final y = CY + pitch * 2 - deg * 2;
      if (y < 0 || y > H) continue;
      canvas.drawLine(Offset(CX - 20, y), Offset(CX + 20, y), tickP);
      if (deg != 0) {
        final tp = TextPainter(
          text: TextSpan(text: '$deg\u00B0', style: const TextStyle(color: Color(0xFF888888), fontSize: 8)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(CX + 22, y - tp.height / 2));
      }
    }

    canvas.drawLine(Offset(CX - 30, CY), Offset(CX - 10, CY),
      Paint()..color = const Color(0xFFe8a838)..strokeWidth = 2);
    canvas.drawLine(Offset(CX + 10, CY), Offset(CX + 30, CY),
      Paint()..color = const Color(0xFFe8a838)..strokeWidth = 2);

    canvas.drawRect(Rect.fromLTWH(2, H - 16, 50, 14), Paint()..color = const Color(0x80000000));
    final label = TextPainter(
      text: const TextSpan(text: 'PITCH', style: TextStyle(color: Color(0xFF888888), fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(4, H - 16 + (14 - label.height) / 2));
  }

  @override
  bool shouldRepaint(PitchLadderPainter old) => old.pitch != pitch;
}

// ─── Roll Indicator ──────────────────────────────────────────────

class RollIndicatorPainter extends CustomPainter {
  final double roll;
  RollIndicatorPainter({required this.roll});

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width, H = size.height, CX = W / 2, CY = H / 2 + 10;

    canvas.drawRect(Rect.fromLTWH(0, 0, W, H), Paint()..color = AppColors.videoBg);

    canvas.save();
    canvas.translate(CX, CY);
    canvas.rotate(-roll * math.pi / 180);

    canvas.drawCircle(Offset.zero, 30,
      Paint()..color = const Color(0x26ffffff)..strokeWidth = 0.7..style = PaintingStyle.stroke);

    for (final t in [-45, -30, -20, -10, 0, 10, 20, 30, 45]) {
      canvas.save();
      canvas.rotate(t * math.pi / 180);
      canvas.drawLine(Offset(0, -28), Offset(0, -20),
        Paint()..color = t == 0 ? AppColors.blueBright : const Color(0x4dffffff)
               ..strokeWidth = t == 0 ? 1.5 : 0.8);
      canvas.restore();
    }
    canvas.restore();

    final tri = Path()
      ..moveTo(CX - 8, CY + 4)..lineTo(CX, CY - 4)..lineTo(CX + 8, CY + 4)..close();
    canvas.drawPath(tri, Paint()..color = AppColors.blueBright..style = PaintingStyle.stroke..strokeWidth = 2);

    canvas.drawRect(Rect.fromLTWH(2, H - 16, 50, 14), Paint()..color = const Color(0x80000000));
    final label = TextPainter(
      text: const TextSpan(text: 'ROLL', style: TextStyle(color: Color(0xFF888888), fontSize: 9)),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(4, H - 16 + (14 - label.height) / 2));
  }

  @override
  bool shouldRepaint(RollIndicatorPainter old) => old.roll != roll;
}
