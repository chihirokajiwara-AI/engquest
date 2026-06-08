// lib/features/exam_practice/pass/pass_gauge.dart
// A 270° arc gauge (gap at the bottom) filling from 0% (bottom-left) toward the
// ごうかく goal at 100% (bottom-right), with the percentage centred and a gold
// goal marker at the 100% end. Shared so the 合格率 reads as ONE designed meter
// everywhere — the full PassMeter (size 180) and the compact home readiness card
// (size ~72). #68.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:engquest/core/ui/app_fonts.dart';

class PassGauge extends StatelessWidget {
  final double pct; // 0..100
  final Color color;
  final double size; // box width; height = size * 168/180
  final double stroke;
  final double fontSize;

  const PassGauge({
    super.key,
    required this.pct,
    required this.color,
    this.size = 180,
    this.stroke = 16,
    this.fontSize = 52,
  });

  @override
  Widget build(BuildContext context) {
    final p = pct.clamp(0.0, 100.0);
    return SizedBox(
      width: size,
      height: size * (168 / 180),
      child: CustomPaint(
        painter: _PassGaugePainter(pct: p, color: color, stroke: stroke),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: stroke * 0.4),
            child: Text(
              '${p.toStringAsFixed(0)}%',
              style: notoSerifJp(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                shadows: const [
                  Shadow(
                      color: Colors.black, blurRadius: 8, offset: Offset(0, 3)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PassGaugePainter extends CustomPainter {
  final double pct; // 0..100
  final Color color;
  final double stroke;
  _PassGaugePainter({
    required this.pct,
    required this.color,
    required this.stroke,
  });

  static const double _startDeg = 135.0; // bottom-left
  static const double _sweepDeg = 270.0; // up over the top to bottom-right

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: side - stroke,
      height: side - stroke,
    );
    final start = _startDeg * math.pi / 180;
    final sweep = _sweepDeg * math.pi / 180;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF1A2244);
    canvas.drawArc(rect, start, sweep, false, track);

    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, start, sweep * (pct / 100.0), false, fill);

    // Goal marker at the 100% end — a gold ringed dot.
    final endAngle = start + sweep;
    final r = rect.width / 2;
    final goal = Offset(
      rect.center.dx + r * math.cos(endAngle),
      rect.center.dy + r * math.sin(endAngle),
    );
    canvas.drawCircle(
        goal, stroke * 0.55, Paint()..color = const Color(0xFFF0D080));
    canvas.drawCircle(
      goal,
      stroke * 0.55,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF6E5320),
    );
  }

  @override
  bool shouldRepaint(_PassGaugePainter old) =>
      old.pct != pct || old.color != color || old.stroke != stroke;
}
