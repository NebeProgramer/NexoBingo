import 'package:bingo_core/bingo_core.dart';

import 'export_stub.dart' if (dart.library.io) 'export_io.dart' as impl;

/// Historial de rondas como CSV para abrir en Excel (función premium).
///
/// Usa `;` como separador y BOM UTF-8: es lo que espera Excel en español
/// para separar columnas y mostrar bien las tildes.
String historyToCsv(String code, List<RoundRecord> history) {
  final rows = <List<String>>[
    ['Sala', 'Ronda', 'Modo', 'Ganador', 'Cartón', 'Balotas cantadas', 'Terminó'],
    for (final r in history)
      [
        code,
        '${r.round}',
        r.mode.displayName,
        r.winnerName ?? 'Sin ganador',
        r.winnerCardId == null ? '' : '#${r.winnerCardId}',
        '${r.ballotsCalled}',
        formatDateTime(r.endedAt),
      ],
  ];
  return '﻿${rows.map((row) => row.map(_escape).join(';')).join('\r\n')}\r\n';
}

String _escape(String field) {
  if (field.contains(RegExp(r'[;"\r\n]'))) return '"${field.replaceAll('"', '""')}"';
  return field;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "2026-10-27 20:15" en hora local.
String formatDateTime(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

/// Guarda el CSV en la carpeta Descargas y devuelve la ruta (o null si no
/// se pudo, por ejemplo en web).
Future<String?> saveHistoryCsv(String code, List<RoundRecord> history) {
  final now = DateTime.now();
  final stamp = '${now.year}${_two(now.month)}${_two(now.day)}_${_two(now.hour)}${_two(now.minute)}';
  return impl.saveTextFile('NexoBingo_sala_${code}_$stamp.csv', historyToCsv(code, history));
}
