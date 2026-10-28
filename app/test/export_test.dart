import 'package:bingo_core/bingo_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexobingo/services/export.dart';

void main() {
  test('CSV del historial listo para Excel en español', () {
    final csv = historyToCsv('482913', [
      RoundRecord(
        round: 1,
        mode: GameMode.ex,
        ballotsCalled: 30,
        endedAt: DateTime(2026, 10, 27, 20, 5),
        winnerName: 'Ana; "la reina"',
        winnerCardId: 512,
      ),
      RoundRecord(round: 2, mode: GameMode.complete, ballotsCalled: 12, endedAt: DateTime(2026, 10, 27, 21, 0)),
    ]);
    expect(csv.startsWith('\uFEFF'), isTrue); // BOM: Excel muestra bien las tildes
    final lines = csv.substring(1).trim().split('\r\n');
    expect(lines[0], 'Sala;Ronda;Modo;Ganador;Cartón;Balotas cantadas;Terminó');
    expect(lines[1], '482913;1;Forma X;"Ana; ""la reina""";#512;30;2026-10-27 20:05');
    expect(lines[2], '482913;2;Cartón lleno;Sin ganador;;12;2026-10-27 21:00');
  });
}
