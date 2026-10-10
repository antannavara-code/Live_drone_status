import 'dart:math' as math;
import 'package:flutter/material.dart';

class FlipRoute extends PageRouteBuilder {
  final Widget page;

  FlipRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return AnimatedBuilder(
              animation: animation,
              builder: (context, child) {
                // 3D flip around Y axis: 90° (edge-on) → 0° (flat)
                final angle = (1.0 - Curves.easeOut.transform(animation.value)) * (math.pi / 2);
                return Transform(
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.001)
                    ..rotateY(angle),
                  alignment: Alignment.center,
                  child: child,
                );
              },
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 500),
          reverseTransitionDuration: const Duration(milliseconds: 500),
        );
}
