import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/material.dart';

import '../theme.dart';

/// Rejilla 5x5 que pinta un patrón de victoria (casillas exigidas en
/// verde). Port de `UI/PatternGrid.java`; se usa en tres lugares con el
/// mismo dibujo:
///  - editor del patrón personalizado del anfitrión ([onChanged] != null),
///  - mini-vista junto al selector de modo del anfitrión,
///  - mini-vista en la esquina de la pantalla del jugador.
///
/// La casilla central es el ID del cartón: nunca se puede marcar.
class PatternGrid extends StatefulWidget {
  const PatternGrid({super.key, required this.pattern, this.onChanged, this.showLetters = false});

  final Pattern pattern;

  /// Si no es null, la rejilla es editable (tocar o arrastrar).
  final ValueChanged<Pattern>? onChanged;
  final bool showLetters;

  @override
  State<PatternGrid> createState() => _PatternGridState();
}

class _PatternGridState extends State<PatternGrid> {
  // Al arrastrar se "pinta" con el valor contrario al de la primera
  // casilla tocada (marca o borra varias de una vez).
  bool _dragValue = true;

  // Copia de trabajo: varios eventos de arrastre pueden llegar antes de
  // que el padre reconstruya con el patrón nuevo.
  late Pattern _current = copyPattern(widget.pattern);

  @override
  void didUpdateWidget(PatternGrid old) {
    super.didUpdateWidget(old);
    _current = copyPattern(widget.pattern);
  }

  void _apply(Offset pos, Size size, {required bool start}) {
    final cell = _Geometry(size, widget.showLetters).cellAt(pos);
    if (cell == null) return;
    final (col, row) = cell;
    if (isCenter(col, row)) return;
    if (start) _dragValue = !_current[col][row];
    if (_current[col][row] == _dragValue) return;
    _current = copyPattern(_current)..[col][row] = _dragValue;
    widget.onChanged!(_current);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = constraints.biggest;
      final paint = CustomPaint(
        size: size,
        painter: _PatternPainter(widget.pattern, widget.showLetters),
      );
      if (widget.onChanged == null) return paint;
      return MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => _apply(d.localPosition, size, start: true),
          onPanStart: (d) => _apply(d.localPosition, size, start: true),
          onPanUpdate: (d) => _apply(d.localPosition, size, start: false),
          child: paint,
        ),
      );
    });
  }
}

class _Geometry {
  _Geometry(Size size, this.showLetters) {
    final rows = showLetters ? gridSize + 1 : gridSize;
    final rough = (size.width / gridSize).clamp(0, size.height / rows).toDouble();
    gap = (rough / 10).clamp(1.0, 8.0);
    cell = ((size.width - 2 * gap) / gridSize).clamp(1.0, (size.height - 2 * gap) / rows).toDouble();
    origin = Offset(
      (size.width - cell * gridSize) / 2,
      (size.height - cell * rows) / 2 + (showLetters ? cell : 0),
    );
  }

  final bool showLetters;
  late final double gap;
  late final double cell;
  late final Offset origin;

  (int, int)? cellAt(Offset p) {
    final col = ((p.dx - origin.dx) / cell).floor();
    final row = ((p.dy - origin.dy) / cell).floor();
    if (col < 0 || col >= gridSize || row < 0 || row >= gridSize) return null;
    return (col, row);
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter(this.pattern, this.showLetters);

  final Pattern pattern;
  final bool showLetters;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _Geometry(size, showLetters);
    final cell = g.cell;
    final gap = g.gap;
    final radius = Radius.circular((cell / 4).clamp(2, 14));
    final large = cell >= 28;

    if (showLetters) {
      for (var col = 0; col < gridSize; col++) {
        final letter = Ballot.letters[col];
        _text(canvas, letter, Offset(g.origin.dx + col * cell + cell / 2, g.origin.dy - cell / 2),
            TextStyle(color: AppColors.letter(letter), fontWeight: FontWeight.bold, fontSize: cell * 0.45));
      }
    }

    // Fondo de la rejilla, para que la mini-vista se lea como "imagen".
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(g.origin.dx - gap, g.origin.dy - gap, cell * gridSize + gap * 2, cell * gridSize + gap * 2),
        radius + Radius.circular(gap),
      ),
      Paint()..color = AppColors.bgDark,
    );

    for (var col = 0; col < gridSize; col++) {
      for (var row = 0; row < gridSize; row++) {
        final rect = Rect.fromLTWH(
            g.origin.dx + col * cell + gap / 2, g.origin.dy + row * cell + gap / 2, cell - gap, cell - gap);
        final color = isCenter(col, row)
            ? AppColors.border
            : (pattern[col][row] ? AppColors.green : AppColors.bgCard);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), Paint()..color = color);
        if (large) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect.deflate(0.6), radius),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2
              ..color = Colors.white.withValues(alpha: 0.12),
          );
          if (isCenter(col, row)) {
            _text(canvas, 'ID', rect.center,
                TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontSize: cell * 0.3));
          }
        }
      }
    }
  }

  void _text(Canvas canvas, String text, Offset center, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_PatternPainter old) =>
      old.showLetters != showLetters || !patternsEqual(old.pattern, pattern);
}

/// Mini-vista + nombre del modo, para la esquina de la pantalla.
class ModeBadge extends StatelessWidget {
  const ModeBadge({super.key, required this.mode, required this.pattern, this.size = 58});

  final GameMode mode;
  final Pattern pattern;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Para ganar cubre las casillas en verde (${mode.displayName})',
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox.square(dimension: size, child: PatternGrid(pattern: pattern)),
        const SizedBox(height: 4),
        Text(mode.displayName,
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 12)),
      ]),
    );
  }
}
