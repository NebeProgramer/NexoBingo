import 'dart:math';

import 'package:bingo_core/bingo_core.dart';
import 'package:test/test.dart';

String draw(Pattern p) => [
      for (var row = 0; row < gridSize; row++)
        [for (var col = 0; col < gridSize; col++) isCenter(col, row) ? '*' : (p[col][row] ? '#' : '.')].join(),
    ].join('\n');

void main() {
  group('GameMode', () {
    test('patrones fijos', () {
      expect(draw(GameMode.complete.fixedPattern()), '#####\n#####\n##*##\n#####\n#####');
      expect(draw(GameMode.ex.fixedPattern()), '#...#\n.#.#.\n..*..\n.#.#.\n#...#');
      expect(draw(GameMode.el.fixedPattern()), '#....\n#....\n#.*..\n#....\n#####');
      expect(draw(GameMode.ti.fixedPattern()), '#####\n..#..\n..*..\n..#..\n..#..');
      expect(countCells(GameMode.personalized.fixedPattern()), 0);
    });

    test('encode/decode', () {
      final p = emptyPattern()
        ..[0][0] = true
        ..[4][3] = true;
      expect(patternsEqual(decodePattern(encodePattern(p)), p), isTrue);
      expect(decodePattern('abc'), isNull);
      expect(isValidPattern(emptyPattern()), isFalse);
      expect(isValidPattern(p), isTrue);
    });
  });

  group('BingoCard', () {
    test('rangos por columna y centro vacío', () {
      final card = BingoCard.random(123, Random(1));
      for (var col = 0; col < 5; col++) {
        for (var row = 0; row < 5; row++) {
          final n = card.numberAt(col, row);
          if (isCenter(col, row)) {
            expect(n, 0);
          } else {
            expect(n, inInclusiveRange(col * 15 + 1, col * 15 + 15));
          }
        }
      }
    });

    test('victoria según patrón', () {
      final card = BingoCard.random(1, Random(2));
      final p = emptyPattern()
        ..[0][0] = true
        ..[4][4] = true;
      final called = {card.numberAt(0, 0)};
      expect(card.isWinner(called, p), isFalse);
      called.add(card.numberAt(4, 4));
      expect(card.isWinner(called, p), isTrue);
      expect(card.isWinner(called, GameMode.complete.fixedPattern()), isFalse);
    });

    test('json ida y vuelta', () {
      final card = BingoCard.random(555, Random(3));
      expect(BingoCard.fromJson(card.toJson()).isIdenticalTo(card), isTrue);
    });
  });

  group('Game', () {
    test('cartón retenido hasta iniciar; no se registra con ronda en curso', () {
      final game = Game(random: Random(4));
      final a = game.register('Ana');
      expect(game.cardFor(a.tableId), isNull);
      game.start();
      expect(game.cardFor(a.tableId), isNotNull);
      expect(() => game.register('Tarde'), throwsA(isA<GameException>()));
    });

    test('no inicia sin jugadores', () {
      expect(() => Game().start(), throwsA(isA<GameException>()));
    });

    test('BINGO falso sigue, válido cierra la ronda', () {
      final game = Game(random: Random(5));
      final a = game.register('Ana');
      game.register('Beto');
      game.setGameMode(GameMode.personalized, emptyPattern()..[0][0] = true);
      game.start();

      expect(game.sing(a.tableId).valid, isFalse);
      final target = a.card.numberAt(0, 0);
      while (!game.calledNumbers.contains(target)) {
        game.draw();
      }
      final result = game.sing(a.tableId);
      expect(result.valid, isTrue);
      expect(game.started, isFalse);
      expect(game.roundId, 1);
      expect(game.lastWinnerRoundId, 0);
      expect(game.called, isEmpty);
      // Gana el ID más bajo entre los que tengan el patrón completo.
      expect(result.winnerTableId, lessThanOrEqualTo(a.tableId));
    });

    test('modo solo entre rondas y personalizado no vacío', () {
      final game = Game()..register('Ana');
      expect(() => game.setGameMode(GameMode.personalized, emptyPattern()), throwsA(isA<GameException>()));
      game.start();
      expect(() => game.setGameMode(GameMode.ex, null), throwsA(isA<GameException>()));
    });

    test('75 balotas sin repetir', () {
      final game = Game()..register('Ana');
      game.start();
      final seen = <int>{};
      for (var i = 0; i < 75; i++) {
        seen.add(game.draw()!.number);
      }
      expect(seen.length, 75);
      expect(game.draw(), isNull);
    });
  });

  test('protocolo', () {
    final game = Game(random: Random(6));
    final p = game.register('Ana');
    game.start();
    final state = PlayerState(
      code: '123456',
      tableId: p.tableId,
      roundId: 0,
      started: true,
      cards: game.cardsFor(p.tableId)!,
      called: const [5, 70],
      mode: GameMode.ti,
      pattern: GameMode.ti.fixedPattern(),
      winnerTableId: -1,
      winnerRoundId: -1,
    );
    final raw = encodeMessage(Msg.playerState, state.toJson());
    final back = PlayerState.fromJson(decodeMessage(raw)!);
    expect(back.card!.isIdenticalTo(p.card), isTrue);
    expect(back.mode, GameMode.ti);
    expect(decodeMessage('nope'), isNull);
  });
}
