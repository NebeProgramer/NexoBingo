import 'dart:convert';
import 'dart:math';

import 'package:bingo_core/bingo_core.dart';
import 'package:test/test.dart';

/// Canta balotas hasta que [player] tenga BINGO con el patrón actual.
void playUntilWin(Game game, Player player) {
  while (!player.cards.any(
    (c) => c.isWinner(game.calledNumbers, game.winPattern),
  )) {
    game.draw();
  }
}

void main() {
  group('Límite de jugadores', () {
    test('gratis: máximo 10', () {
      final game = Game(random: Random(1));
      for (var i = 0; i < maxPlayersFree; i++) {
        game.register('J$i');
      }
      expect(
        () => game.register('Once'),
        throwsA(
          isA<GameException>().having((e) => e.message, 'message', contains('llena')),
        ),
      );
    });

    test('premium: más de 10', () {
      final game = Game(random: Random(2), premium: true);
      for (var i = 0; i < 25; i++) {
        game.register('J$i');
      }
      expect(game.players, hasLength(25));
      expect(game.maxPlayers, maxPlayersPremium);
    });
  });

  group('Varios cartones (premium)', () {
    test('bloqueado sin premium', () {
      final game = Game()..register('Ana');
      expect(() => game.setCardsPerPlayer(2), throwsA(isA<GameException>()));
      expect(game.cardsPerPlayer, 1);
    });

    test('con premium reparte N cartones con IDs y números únicos', () {
      final game = Game(random: Random(3), premium: true);
      for (var i = 0; i < 6; i++) {
        game.register('J$i');
      }
      game.setCardsPerPlayer(4);
      final cards = [for (final p in game.players) ...p.cards];
      expect(cards, hasLength(24));
      expect(cards.map((c) => c.id).toSet(), hasLength(24));
      for (final p in game.players) {
        expect(p.cards.first.id, p.id); // el primer cartón lleva el ID del jugador
      }
      for (final c in cards) {
        expect(c.isDuplicateIn(cards), isFalse);
      }
      // Los nuevos jugadores también reciben 4.
      expect(game.register('Nuevo').cards, hasLength(4));
    });

    test('no se cambia con la ronda en curso', () {
      final game = Game(premium: true)..register('Ana');
      game.start();
      expect(() => game.setCardsPerPlayer(3), throwsA(isA<GameException>()));
    });

    test('gana con cualquiera de sus cartones', () {
      final game = Game(random: Random(4), premium: true);
      final ana = game.register('Ana');
      game.setCardsPerPlayer(3);
      game.setGameMode(GameMode.personalized, emptyPattern()..[0][0] = true);
      game.start();
      // Esperar a que salga la esquina del TERCER cartón.
      final target = ana.cards[2].numberAt(0, 0);
      while (!game.calledNumbers.contains(target)) {
        game.draw();
      }
      expect(game.sing(ana.id).valid, isTrue);
    });
  });

  group('Trofeos', () {
    test('cuenta las rondas ganadas por jugador', () {
      final game = Game(random: Random(5));
      final ana = game.register('Ana');
      game.setGameMode(GameMode.personalized, emptyPattern()..[2][0] = true);
      for (var round = 0; round < 2; round++) {
        game.start();
        playUntilWin(game, ana);
        final result = game.sing(ana.id);
        expect(result.valid, isTrue);
      }
      expect(ana.wins, 2);
    });

    test('un BINGO falso no suma', () {
      final game = Game()..register('Ana');
      game.start();
      game.sing(game.players.first.id);
      expect(game.players.first.wins, 0);
    });
  });

  group('Historial de rondas', () {
    test('registra ganador y rondas finalizadas sin ganador', () {
      final game = Game(random: Random(6));
      final ana = game.register('Ana');
      game.setGameMode(GameMode.ex, null);
      game.start();
      game.draw();
      game.draw();
      game.end(); // a mano, sin ganador

      game.setGameMode(GameMode.personalized, emptyPattern()..[4][4] = true);
      game.start();
      playUntilWin(game, ana);
      game.sing(ana.id);

      expect(game.history, hasLength(2));
      final first = game.history[0];
      expect(first.round, 1);
      expect(first.mode, GameMode.ex);
      expect(first.ballotsCalled, 2);
      expect(first.winnerName, isNull);
      final second = game.history[1];
      expect(second.round, 2);
      expect(second.winnerName, 'Ana');
      expect(second.winnerCardId, isNotNull);
    });

    test('finalizar sin haber iniciado no agrega ronda', () {
      final game = Game()..register('Ana');
      game.end();
      expect(game.history, isEmpty);
    });

    test('json ida y vuelta', () {
      final record = RoundRecord(
        round: 3,
        mode: GameMode.ti,
        ballotsCalled: 41,
        endedAt: DateTime(2026, 10, 27, 20, 15),
        winnerName: 'Ana',
        winnerCardId: 512,
      );
      final back = RoundRecord.fromJson(
        jsonDecode(jsonEncode(record.toJson())) as Map<String, dynamic>,
      );
      expect(back.round, 3);
      expect(back.mode, GameMode.ti);
      expect(back.winnerName, 'Ana');
      expect(back.endedAt, record.endedAt);
    });
  });

  group('Compatibilidad del protocolo', () {
    test('un estado de jugador de la 2.0.0 (solo "card") se sigue leyendo', () {
      final card = BingoCard.random(321, Random(7));
      final old = {
        'code': '123456',
        'tableId': 321,
        'roundId': 0,
        'started': true,
        'card': card.toJson(),
        'called': [1, 2],
        'mode': 'complete',
        'pattern': encodePattern(GameMode.complete.fixedPattern()),
        'winnerTableId': -1,
        'winnerRoundId': -1,
      };
      final state = PlayerState.fromJson(old);
      expect(state.cards, hasLength(1));
      expect(state.allowAutoMark, isTrue);
      expect(state.winners, isEmpty);
    });

    test('el estado nuevo sigue mandando "card" para las apps viejas', () {
      final cards = [BingoCard.random(1, Random(8)), BingoCard.random(2, Random(9))];
      final json = PlayerState(
        code: '1',
        tableId: 1,
        roundId: 0,
        started: true,
        cards: cards,
        called: const [],
        mode: GameMode.complete,
        pattern: GameMode.complete.fixedPattern(),
        winnerTableId: -1,
        winnerRoundId: -1,
      ).toJson();
      expect((json['card'] as Map)['id'], 1);
      expect(json['cards'], hasLength(2));
    });
  });
}
