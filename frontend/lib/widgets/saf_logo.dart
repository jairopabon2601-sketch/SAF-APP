import 'dart:math' as math;
import 'package:flutter/material.dart';

class SafLogoPainter extends CustomPainter {
  final Color color;
  const SafLogoPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    final r = size.width * 0.38,
        nodeR = size.width * 0.115,
        ringW = size.width * 0.07;
    final gap = 2 * math.asin(nodeR / r) + 0.06;
    final angles = [
      -math.pi * 3 / 4,
      -math.pi / 4,
      math.pi / 4,
      math.pi * 3 / 4
    ];

    final ring = Paint()
      ..color = color
      ..strokeWidth = ringW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.butt;
    for (int i = 0; i < angles.length; i++) {
      final start = angles[i] + gap / 2;
      var sweep = (angles[(i + 1) % angles.length] - gap / 2) - start;
      if (sweep < 0) sweep += math.pi * 2;
      canvas.drawArc(
          Rect.fromCircle(center: Offset(cx, cy), radius: r),
          start, sweep, false, ring);
    }
    final dot = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    for (final a in angles) {
      canvas.drawCircle(
          Offset(cx + r * math.cos(a), cy + r * math.sin(a)), nodeR, dot);
    }
  }

  @override
  bool shouldRepaint(SafLogoPainter old) => old.color != color;
}
