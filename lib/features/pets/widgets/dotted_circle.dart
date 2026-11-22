import 'dart:math';

import 'package:flutter/material.dart';

/// Cercle en pointillés, avec un [child] centré dedans.
/// Le rayon et le nombre de points s'adaptent à [size].
class DottedCircle extends StatelessWidget {
  final double size;
  final Color color;
  final Widget child;

  const DottedCircle({
    super.key,
    required this.child,
    this.size = 40,
    this.color = const Color(0xFFB58A62),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DottedCirclePainter(color: color),
        child: Center(child: child),
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;

  _DottedCirclePainter({required this.color});

  static const _dotRadius = 1.6;

  /// Espace approximatif entre deux points (en px).
  static const _spacing = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final radius = min(size.width, size.height) / 2 - _dotRadius;
    final dashCount = max(12, (2 * pi * radius / _spacing).round());
    final center = Offset(size.width / 2, size.height / 2);

    for (var i = 0; i < dashCount; i++) {
      final angle = i * 2 * pi / dashCount;
      final position = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );
      canvas.drawCircle(position, _dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
