import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

class ArcGauge extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final String unit;
  final String label;
  final Color? valueColor;
  final double size;
  final int decimals;

  const ArcGauge({
    super.key,
    required this.value,
    this.min = 0,
    required this.max,
    required this.unit,
    required this.label,
    this.valueColor,
    this.size = 80,
    this.decimals = 0,
  });

  @override
  State<ArcGauge> createState() => _ArcGaugeState();
}

class _ArcGaugeState extends State<ArcGauge> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  double _fromValue = 0;
  double _dispValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..addListener(_onTick);
    _dispValue = widget.value;
  }

  void _onTick() {
    final t = _ctrl.value;
    if (t >= 1) {
      _dispValue = widget.value;
    } else {
      final ease = 1 - math.pow(1 - t, 3);
      _dispValue = _fromValue + (widget.value - _fromValue) * ease;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(ArcGauge old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _fromValue = _dispValue;
      _ctrl.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ctrl.isAnimating) {
      _dispValue = widget.value;
    }

    final pct = ((_dispValue - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    final color = widget.valueColor ?? _colorForPct(pct);
    final valueStr = widget.decimals > 0
        ? _dispValue.toStringAsFixed(widget.decimals)
        : _dispValue.toInt().toString();

    return SizedBox(
      width: widget.size,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: widget.size,
            height: widget.size * 0.8,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(widget.size, widget.size * 0.8),
                  painter: _GaugeArcPainter(fraction: pct, color: color),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      valueStr,
                      style: TextStyle(color: color, fontSize: widget.size * 0.22, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                    Text(
                      widget.unit,
                      style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: widget.size * 0.11, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: widget.size * 0.04),
          Text(
            widget.label,
            style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.w500, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Color _colorForPct(double pct) {
    if (pct < 0.2) return AppColors.danger;
    if (pct < 0.5) return AppColors.warning;
    return AppColors.primary;
  }
}

class _GaugeArcPainter extends CustomPainter {
  final double fraction;
  final Color color;

  _GaugeArcPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.75;
    final radius = math.min(size.width, size.height) * 0.42;
    final thickness = radius * 0.20;
    final rect = Rect.fromCircle(center: Offset(cx, cy), radius: radius);

    final bg = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, math.pi, math.pi, false, bg);

    if (fraction > 0.005) {
      final fg = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, fg);
    }
  }

  @override
  bool shouldRepaint(_GaugeArcPainter old) => old.fraction != fraction || old.color != color;
}
