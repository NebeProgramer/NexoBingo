import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/material.dart';

import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/pattern_grid.dart';

/// Diálogo donde el anfitrión dibuja el patrón del modo Personalizado
/// (port de `PatternEditorDialog.java`). Devuelve el patrón guardado, o
/// null si canceló.
Future<Pattern?> showPatternEditor(BuildContext context, Pattern? initial) {
  return showDialog<Pattern>(
    context: context,
    builder: (_) => _PatternEditor(initial: copyPattern(initial)),
  );
}

class _PatternEditor extends StatefulWidget {
  const _PatternEditor({required this.initial});

  final Pattern initial;

  @override
  State<_PatternEditor> createState() => _PatternEditorState();
}

class _PatternEditorState extends State<_PatternEditor> {
  late Pattern _pattern = widget.initial;

  @override
  Widget build(BuildContext context) {
    final count = countCells(_pattern);
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Patrón personalizado',
                  style: TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              const Text(
                'Toca o arrastra sobre las casillas que deben estar cubiertas para ganar. '
                'La casilla central es el ID del cartón.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
              const SizedBox(height: 14),
              AspectRatio(
                aspectRatio: 5 / 6,
                child: PatternGrid(
                  pattern: _pattern,
                  showLetters: true,
                  onChanged: (p) => setState(() => _pattern = p),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                count == 0 ? 'Selecciona al menos una casilla.' : '$count casilla(s) para ganar.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(
                    child: AppButton(
                        label: 'Limpiar',
                        color: AppColors.blue,
                        height: 42,
                        onPressed: () => setState(() => _pattern = emptyPattern()))),
                const SizedBox(width: 10),
                Expanded(
                    child: AppButton(
                        label: 'Cancelar', color: AppColors.red, height: 42, onPressed: () => Navigator.pop(context))),
                const SizedBox(width: 10),
                Expanded(
                    child: AppButton(
                        label: 'Guardar',
                        color: AppColors.green,
                        height: 42,
                        onPressed: count == 0 ? null : () => Navigator.pop(context, _pattern))),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
