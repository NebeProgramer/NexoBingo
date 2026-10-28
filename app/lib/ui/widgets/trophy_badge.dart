import 'package:flutter/material.dart';

import '../theme.dart';

/// Trofeo dorado con el número de rondas ganadas en el centro de la copa.
/// Solo se dibuja si [wins] >= 1: quien no ha ganado no lleva trofeo.
class TrophyBadge extends StatelessWidget {
  const TrophyBadge({super.key, required this.wins, this.size = 26});

  final int wins;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (wins < 1) return const SizedBox.shrink();
    return Tooltip(
      message: wins == 1 ? '1 ronda ganada' : '$wins rondas ganadas',
      child: SizedBox(
        width: size,
        height: size,
        // El pintor no hereda la fuente del tema: se le pasa explícita.
        child: CustomPaint(painter: _TrophyPainter(wins, DefaultTextStyle.of(context).style.fontFamily)),
      ),
    );
  }
}

class _TrophyPainter extends CustomPainter {
  _TrophyPainter(this.wins, this.fontFamily);

  final int wins;
  final String? fontFamily;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final gold = Paint()..color = AppColors.gold;
    final dark = Paint()..color = AppColors.goldDark;

    // Asas a los lados de la copa.
    final handle = Paint()
      ..color = AppColors.goldDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08;
    canvas.drawArc(Rect.fromLTWH(w * 0.04, h * 0.12, w * 0.32, h * 0.34), 1.6, 3.0, false, handle);
    canvas.drawArc(Rect.fromLTWH(w * 0.64, h * 0.12, w * 0.32, h * 0.34), -1.4, 3.0, false, handle);

    // Copa: borde superior recto y fondo redondeado.
    final cup = Path()
      ..moveTo(w * 0.2, h * 0.06)
      ..lineTo(w * 0.8, h * 0.06)
      ..lineTo(w * 0.8, h * 0.3)
      ..quadraticBezierTo(w * 0.8, h * 0.66, w * 0.5, h * 0.66)
      ..quadraticBezierTo(w * 0.2, h * 0.66, w * 0.2, h * 0.3)
      ..close();
    canvas.drawPath(cup, gold);

    // Tallo y base.
    canvas.drawRect(Rect.fromLTWH(w * 0.44, h * 0.64, w * 0.12, h * 0.14), dark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.24, h * 0.78, w * 0.52, h * 0.14), Radius.circular(w * 0.04)),
      gold,
    );

    // Número de victorias en el centro de la copa.
    final label = wins > 99 ? '99+' : '$wins';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: AppColors.bgDark,
          fontFamily: fontFamily,
          fontWeight: FontWeight.w900,
          fontSize: h * (label.length > 2 ? 0.26 : 0.36),
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, h * 0.34 - tp.height / 2));
  }

  @override
  bool shouldRepaint(_TrophyPainter old) => old.wins != wins || old.fontFamily != fontFamily;
}
