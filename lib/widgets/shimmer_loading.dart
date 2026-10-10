import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

class ShimmerLoading extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    this.height = 20,
    this.borderRadius = 8,
  });

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 + _ctrl.value * 2, 0),
              end: Alignment(1 + _ctrl.value * 2, 0),
              colors: [
                AppColors.border,
                Color(0xFF2A3A4A),
                AppColors.border,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

class ShimmerCard extends StatelessWidget {
  final double height;
  final int lines;

  const ShimmerCard({super.key, this.height = 140, this.lines = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: height),
      decoration: BoxDecoration(
        color: AppColors.panelAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerLoading(width: 80, height: 12, borderRadius: 4),
          const SizedBox(height: 10),
          if (lines > 0)
            ...List.generate(lines, (i) => Padding(
              padding: EdgeInsets.only(bottom: i < lines - 1 ? 6 : 0),
              child: ShimmerLoading(width: 120 + (i * 40).toDouble(), height: 12, borderRadius: 4),
            )),
          if (lines == 0) ...[
            const ShimmerLoading(height: 12, borderRadius: 4),
            const SizedBox(height: 6),
            const ShimmerLoading(width: 200, height: 12, borderRadius: 4),
            const SizedBox(height: 6),
            const ShimmerLoading(width: 140, height: 12, borderRadius: 4),
          ],
        ],
      ),
    );
  }
}

class ShimmerGrid extends StatelessWidget {
  final int count;
  final double height;
  const ShimmerGrid({super.key, this.count = 4, this.height = 100});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: ShimmerCard(height: height, lines: 2)),
            const SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: height, lines: 2)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: ShimmerCard(height: height, lines: 2)),
            const SizedBox(width: 12),
            Expanded(child: ShimmerCard(height: height, lines: 2)),
          ],
        ),
      ],
    );
  }
}
