import 'dart:math';

import 'package:flutter/material.dart';

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

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    const dashCount = 40;
    const radius = 33.0;
    const dotRadius = 1.2;

    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < dashCount; i++) {
      final angle = (i * 2 * 3.141592653589793) / dashCount;

      final position = Offset(
        center.dx + radius * cos(angle),
        center.dy + radius * sin(angle),
      );

      canvas.drawCircle(position, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
