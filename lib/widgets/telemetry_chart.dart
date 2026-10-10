import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

class TelemetryPoint {
  final double time;
  final double value;
  TelemetryPoint(this.time, this.value);
}

class RollingBuffer {
  final int maxPoints = 60;
  final List<TelemetryPoint> _points = [];
  double _startTime = 0;

  List<TelemetryPoint> get points => List.unmodifiable(_points);

  void add(double value) {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    if (_points.isEmpty) _startTime = now;
    _points.add(TelemetryPoint(now - _startTime, value));
    if (_points.length > maxPoints) _points.removeAt(0);
  }

  void reset() {
    _points.clear();
    _startTime = 0;
  }
}

class TelemetryChart extends StatelessWidget {
  final List<TelemetryPoint> data;
  final String label;
  final Color color;
  final String unit;
  final double? maxY;

  const TelemetryChart({
    super.key,
    required this.data,
    required this.label,
    required this.color,
    required this.unit,
    this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
              const Spacer(),
              if (data.isNotEmpty)
                Text(
                  '${data.last.value.toStringAsFixed(1)} $unit',
                  style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w600),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Expanded(child: _ChartPainter(data: data, lineColor: color, unit: unit, maxY: maxY)),
        ],
      ),
    );
  }
}

class _ChartPainter extends StatelessWidget {
  final List<TelemetryPoint> data;
  final Color lineColor;
  final String unit;
  final double? maxY;

  const _ChartPainter({required this.data, required this.lineColor, required this.unit, this.maxY});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(data: data, lineColor: lineColor, maxY: maxY, unit: unit),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<TelemetryPoint> data;
  final Color lineColor;
  final double? maxY;
  final String unit;

  _LineChartPainter({required this.data, required this.lineColor, this.maxY, this.unit = ''});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    const leftMargin = 36.0;
    const rightMargin = 8.0;
    final chartWidth = size.width - leftMargin - rightMargin;

    if (chartWidth <= 0) return;

    final minVal = maxY != null ? 0.0 : data.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxVal = maxY ?? data.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final range = (maxVal - minVal).clamp(0.01, double.infinity);
    final timeRange = data.last.time - data.first.time;
    final tRange = timeRange.clamp(0.01, double.infinity);

    // y-axis labels and grid lines
    final labelCount = 4;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..strokeWidth = 0.5;
    for (int i = 0; i <= labelCount; i++) {
      final val = minVal + (maxVal - minVal) * (i / labelCount);
      final y = size.height - ((val - minVal) / range) * size.height;
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: val.toStringAsFixed(val >= 100 ? 0 : 1),
          style: TextStyle(color: AppColors.textFaint, fontSize: 8),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    // line path
    final paint = Paint()
      ..color = lineColor.withValues(alpha: 0.8)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < data.length; i++) {
      final x = leftMargin + ((data[i].time - data.first.time) / tRange) * chartWidth;
      final y = size.height - ((data[i].value - minVal) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // fill area
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withValues(alpha: 0.25), lineColor.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPath = Path.from(path);
    if (data.isNotEmpty) {
      final lastX = leftMargin + ((data.last.time - data.first.time) / tRange) * chartWidth;
      final firstX = leftMargin;
      fillPath.lineTo(lastX, size.height);
      fillPath.lineTo(firstX, size.height);
      fillPath.close();
    }
    canvas.drawPath(fillPath, fillPaint);

    // dot + value label at the latest point
    if (data.isNotEmpty) {
      final last = data.last;
      final lastX = leftMargin + ((last.time - data.first.time) / tRange) * chartWidth;
      final lastY = size.height - ((last.value - minVal) / range) * size.height;

      final dotPaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(lastX, lastY), 3, dotPaint);

      final labelTp = TextPainter(
        text: TextSpan(
          text: '${last.value.toStringAsFixed(1)} $unit',
          style: TextStyle(color: lineColor, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      labelTp.paint(canvas, Offset(lastX + 6, lastY - labelTp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter old) => true;
}
