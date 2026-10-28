import 'dart:math';

import 'ball_bag.dart';
import 'ballot.dart';
import 'bingo_card.dart';
import 'game_mode.dart';
import 'round_record.dart';

/// Jugadores por sala en el plan gratuito.
const int maxPlayersFree = 10;

/// Jugadores por sala con premium.
const int maxPlayersPremium = 200;

/// Cartones por jugador con premium (en el plan gratuito siempre es 1).
const int maxCardsPerPlayer = 4;

/// Rondas que se conservan en el historial de una sala.
const int maxHistory = 200;

/// Error de regla de negocio (se le muestra tal cual al usuario).
class GameException implements Exception {
  GameException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Jugador registrado: su nombre, su ID y los cartones que se le
/// asignaron (generados al registrarse, pero retenidos hasta que el juego
/// inicie). [id] es también el ID de su primer cartón.
class Player {
  Player(this.name, this.id, this.cards);

  final String name;
  final int id;
  List<BingoCard> cards;

  /// Rondas ganadas en esta sala (para los trofeos).
  int wins = 0;

  int get tableId => id;
  BingoCard get card => cards.first;
}

class SingResult {
  const SingResult({
    required this.valid,
    required this.message,
    this.winnerTableId,
    this.winnerCardId,
  });

  final bool valid;
  final String message;
  final int? winnerTableId;
  final int? winnerCardId;
}

/// Una partida (port de `Server/Game.java`). No sabe nada de red: el
/// Broker la envuelve en una sala y difunde su estado a los sockets.
///
/// Regla de negocio clave: al registrarse, el jugador YA tiene cartones
/// (para poder validar duplicados), pero no se le entregan hasta que el
/// anfitrión inicia la ronda (ver [cardsFor]).
class Game {
  Game({Random? random, this.premium = false})
    : _random = random ?? Random() {
    _bag = BallBag(_random);
  }

  final Random _random;
  late BallBag _bag;

  /// Si la sala tiene las funciones premium habilitadas.
  final bool premium;

  final List<Player> players = [];
  bool started = false;
  final List<Ballot> called = [];
  final Set<int> _calledNumbers = {};

  GameMode mode = GameMode.complete;
  Pattern? _customPattern;

  /// Cartones por jugador (1 en el plan gratuito).
  int cardsPerPlayer = 1;

  /// Si los jugadores pueden activar el marcado automático.
  bool allowAutoMark = true;

  /// Rondas terminadas, de la más vieja a la más nueva.
  final List<RoundRecord> history = [];

  /// Cambia cada vez que [end] prepara la ronda siguiente: es la señal que
  /// usan los jugadores para limpiar su cartón.
  int roundId = 0;

  // Se guardan aparte del estado de la ronda (que sí se limpia en end)
  // para que todos puedan enterarse de quién ganó.
  int lastWinnerTableId = -1;
  int lastWinnerCardId = -1;
  int lastWinnerRoundId = -1;

  int get maxPlayers => premium ? maxPlayersPremium : maxPlayersFree;

  Set<int> get calledNumbers => Set.unmodifiable(_calledNumbers);

  /// Casillas exigidas para ganar con el modo actual.
  Pattern get winPattern => mode == GameMode.personalized
      ? copyPattern(_customPattern)
      : mode.fixedPattern();

  Player? playerById(int tableId) {
    for (final p in players) {
      if (p.tableId == tableId) return p;
    }
    return null;
  }

  /// Los cartones solo se entregan con la ronda en curso.
  List<BingoCard>? cardsFor(int tableId) =>
      started ? playerById(tableId)?.cards : null;

  /// Primer cartón del jugador (compatibilidad con clientes de un cartón).
  BingoCard? cardFor(int tableId) => cardsFor(tableId)?.first;

  Player register(String name) {
    if (started) {
      throw GameException(
        'La partida ya inició, no puedes registrarte ahora.',
      );
    }
    if (players.length >= maxPlayers) {
      throw GameException(
        'La sala está llena (máximo $maxPlayers jugadores).',
      );
    }
    final used = _usedIds();
    final id = _newId(used);
    final player = Player(name, id, _dealCards(id, used, _allCards()));
    players.add(player);
    return player;
  }

  void removePlayer(int tableId) {
    players.removeWhere((p) => p.tableId == tableId);
  }

  void setGameMode(GameMode newMode, Pattern? pattern) {
    if (started) {
      throw GameException(
        'No se puede cambiar el modo de juego con la partida en curso.',
      );
    }
    if (newMode == GameMode.personalized) {
      if (!isValidPattern(pattern)) {
        throw GameException(
          'El patrón personalizado debe tener al menos una casilla.',
        );
      }
      _customPattern = copyPattern(pattern);
    }
    mode = newMode;
  }

  /// Cambia cuántos cartones recibe cada jugador y los reparte de nuevo.
  /// Solo entre rondas; más de 1 es función premium.
  void setCardsPerPlayer(int count) {
    if (count == cardsPerPlayer) return;
    if (started) {
      throw GameException(
        'No se puede cambiar la cantidad de cartones con la partida en curso.',
      );
    }
    if (count < 1 || count > maxCardsPerPlayer) {
      throw GameException(
        'Cada jugador puede tener entre 1 y $maxCardsPerPlayer cartones.',
      );
    }
    if (count > 1 && !premium) {
      throw GameException(
        'Varios cartones por jugador es una función premium.',
      );
    }
    cardsPerPlayer = count;
    _redealAll();
  }

  void setAllowAutoMark(bool allow) => allowAutoMark = allow;

  void start() {
    if (started) throw GameException('El juego ya había iniciado.');
    if (players.isEmpty) {
      throw GameException(
        'No hay jugadores registrados, no se puede iniciar.',
      );
    }
    started = true;
  }

  Ballot? draw() {
    if (!started) throw GameException('El juego no ha iniciado.');
    final ballot = _bag.drawRandomUnused();
    if (ballot == null) return null;
    called.add(ballot);
    _calledNumbers.add(ballot.number);
    return ballot;
  }

  SingResult sing(int tableId) {
    final singer = playerById(tableId);
    if (singer == null) {
      return const SingResult(
        valid: false,
        message: 'No se encontró tu cartón en esta partida.',
      );
    }
    if (!started) {
      return const SingResult(
        valid: false,
        message: 'La ronda no está en curso.',
      );
    }

    final pattern = winPattern;
    if (!singer.cards.any((c) => c.isWinner(_calledNumbers, pattern))) {
      return const SingResult(
        valid: false,
        message: 'Tu BINGO es incorrecto. El juego continúa.',
      );
    }

    // Ganadores simultáneos: gana el cartón con el ID más bajo.
    final winners = [
      for (final p in players)
        for (final c in p.cards)
          if (c.isWinner(_calledNumbers, pattern)) (player: p, card: c),
    ]..sort((a, b) => a.card.id.compareTo(b.card.id));
    final winner = winners.first;

    winner.player.wins++;
    lastWinnerTableId = winner.player.tableId;
    lastWinnerCardId = winner.card.id;
    lastWinnerRoundId = roundId;
    _record(winnerName: winner.player.name, winnerCardId: winner.card.id);

    final message = identical(winner.player, singer)
        ? '¡Ganaste! Cartón #${winner.card.id}'
        : 'Ganó ${winner.player.name} (cartón #${winner.card.id})';

    // Un BINGO válido también cierra la ronda.
    _closeRound();
    return SingResult(
      valid: true,
      message: message,
      winnerTableId: winner.player.tableId,
      winnerCardId: winner.card.id,
    );
  }

  /// Cierra la ronda a mano (botón "Finalizar partida"). Si la ronda
  /// estaba en curso queda en el historial como "sin ganador".
  void end() {
    if (started) _record();
    _closeRound();
  }

  /// Deja todo listo para la siguiente ronda: bolsa nueva, cartones nuevos
  /// (mismos IDs de jugador, retenidos hasta el próximo start) y
  /// `roundId++`.
  void _closeRound() {
    started = false;
    called.clear();
    _calledNumbers.clear();
    _bag = BallBag(_random);
    roundId++;
    _redealAll();
  }

  void _record({String? winnerName, int? winnerCardId}) {
    history.add(
      RoundRecord(
        round: roundId + 1,
        mode: mode,
        ballotsCalled: called.length,
        winnerName: winnerName,
        winnerCardId: winnerCardId,
        endedAt: DateTime.now(),
      ),
    );
    if (history.length > maxHistory) history.removeAt(0);
  }

  /// Reparte cartones nuevos a todos, conservando el ID de cada jugador.
  void _redealAll() {
    final used = {for (final p in players) p.id};
    final dealt = <BingoCard>[];
    for (final player in players) {
      player.cards = _dealCards(player.id, used, dealt);
      dealt.addAll(player.cards);
    }
  }

  /// Cartones para un jugador: el primero lleva su [firstId] y los demás
  /// IDs nuevos. Ningún cartón repite números con [existing].
  List<BingoCard> _dealCards(
    int firstId,
    Set<int> used,
    List<BingoCard> existing,
  ) {
    final cards = <BingoCard>[];
    for (var i = 0; i < cardsPerPlayer; i++) {
      final id = i == 0 ? firstId : _newId(used);
      BingoCard card;
      do {
        card = BingoCard.random(id, _random);
      } while (card.isDuplicateIn([...existing, ...cards]));
      cards.add(card);
    }
    return cards;
  }

  List<BingoCard> _allCards() => [for (final p in players) ...p.cards];

  Set<int> _usedIds() => {
    for (final p in players) ...[p.id, for (final c in p.cards) c.id],
  };

  /// ID aleatorio entre 100 y 999 que no esté en [used] (y lo reserva).
  int _newId(Set<int> used) {
    int id;
    do {
      id = 100 + _random.nextInt(900);
    } while (used.contains(id));
    used.add(id);
    return id;
  }
}
