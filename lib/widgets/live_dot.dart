import 'package:flutter/material.dart';
import '../services/theme_provider.dart';

class LiveDot extends StatefulWidget {
  final bool live;
  final double size;
  const LiveDot({super.key, required this.live, this.size = 8});

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _anim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.live) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(LiveDot old) {
    super.didUpdateWidget(old);
    if (widget.live != old.live) {
      if (widget.live) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
        _ctrl.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final scale = widget.live ? 1.0 + _anim.value * 0.4 : 1.0;
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.live ? AppColors.primary : AppColors.textMuted,
            boxShadow: widget.live
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5 * (1.0 - _anim.value * 0.6)),
                      blurRadius: 4 * scale,
                      spreadRadius: 1 * scale,
                    ),
                  ]
                : null,
          ),
          transform: Matrix4.identity()..scaleByDouble(scale, scale, 1.0, 1.0),
          alignment: Alignment.center,
        );
      },
    );
  }
}
