import 'dart:math';

import 'ball_bag.dart';
import 'ballot.dart';
import 'bingo_card.dart';
import 'game_mode.dart';

/// Error de regla de negocio (se le muestra tal cual al usuario).
class GameException implements Exception {
  GameException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Jugador registrado: su nombre y el cartón que se le asignó (generado
/// al registrarse, pero retenido hasta que el juego inicie).
class Player {
  Player(this.name, this.card);

  final String name;
  BingoCard card;

  int get tableId => card.id;
}

class SingResult {
  const SingResult({required this.valid, required this.message, this.winnerTableId});

  final bool valid;
  final String message;
  final int? winnerTableId;
}

/// Una partida (port de `Server/Game.java`). No sabe nada de red: el
/// Broker la envuelve en una sala y difunde su estado a los sockets.
///
/// Regla de negocio clave: al registrarse, el jugador YA tiene cartón
/// (para poder validar duplicados), pero no se le entrega hasta que el
/// anfitrión inicia la ronda (ver [cardFor]).
class Game {
  Game({Random? random}) : _random = random ?? Random() {
    _bag = BallBag(_random);
  }

  final Random _random;
  late BallBag _bag;

  final List<Player> players = [];
  bool started = false;
  final List<Ballot> called = [];
  final Set<int> _calledNumbers = {};

  GameMode mode = GameMode.complete;
  Pattern? _customPattern;

  /// Cambia cada vez que [end] prepara la ronda siguiente: es la señal que
  /// usan los jugadores para limpiar su cartón.
  int roundId = 0;

  // Se guardan aparte del estado de la ronda (que sí se limpia en end)
  // para que todos puedan enterarse de quién ganó.
  int lastWinnerTableId = -1;
  int lastWinnerRoundId = -1;

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

  /// El cartón solo se entrega con la ronda en curso.
  BingoCard? cardFor(int tableId) => started ? playerById(tableId)?.card : null;

  Player register(String name) {
    if (started) {
      throw GameException('La partida ya inició, no puedes registrarte ahora.');
    }
    int id;
    do {
      id = 100 + _random.nextInt(900); // ID aleatorio entre 100 y 999
    } while (playerById(id) != null);

    final player = Player(name, _newUniqueCard(id));
    players.add(player);
    return player;
  }

  void removePlayer(int tableId) {
    players.removeWhere((p) => p.tableId == tableId);
  }

  void setGameMode(GameMode newMode, Pattern? pattern) {
    if (started) {
      throw GameException('No se puede cambiar el modo de juego con la partida en curso.');
    }
    if (newMode == GameMode.personalized) {
      if (!isValidPattern(pattern)) {
        throw GameException('El patrón personalizado debe tener al menos una casilla.');
      }
      _customPattern = copyPattern(pattern);
    }
    mode = newMode;
  }

  void start() {
    if (started) throw GameException('El juego ya había iniciado.');
    if (players.isEmpty) {
      throw GameException('No hay jugadores registrados, no se puede iniciar.');
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
      return const SingResult(valid: false, message: 'No se encontró tu cartón en esta partida.');
    }
    if (!started) {
      return const SingResult(valid: false, message: 'La ronda no está en curso.');
    }

    final pattern = winPattern;
    if (!singer.card.isWinner(_calledNumbers, pattern)) {
      return const SingResult(valid: false, message: 'Tu BINGO es incorrecto. El juego continúa.');
    }

    // Ganadores simultáneos: gana el ID de cartón más bajo.
    final winners = players.where((p) => p.card.isWinner(_calledNumbers, pattern)).toList()
      ..sort((a, b) => a.tableId.compareTo(b.tableId));
    final winner = winners.first;

    lastWinnerTableId = winner.tableId;
    lastWinnerRoundId = roundId;
    final message = winner.tableId == tableId
        ? '¡Ganaste! Cartón #${winner.tableId}'
        : 'Ganó el cartón #${winner.tableId}';

    // Un BINGO válido también cierra la ronda.
    end();
    return SingResult(valid: true, message: message, winnerTableId: winner.tableId);
  }

  /// Cierra la ronda y deja todo listo para la siguiente: bolsa nueva,
  /// cartones nuevos (mismo ID, retenidos hasta el próximo start) y
  /// `roundId++`.
  void end() {
    started = false;
    called.clear();
    _calledNumbers.clear();
    _bag = BallBag(_random);
    roundId++;
    for (final player in players) {
      player.card = _newUniqueCard(player.tableId);
    }
  }

  BingoCard _newUniqueCard(int id) {
    final existing = players.map((p) => p.card).toList();
    BingoCard card;
    do {
      card = BingoCard.random(id, _random);
    } while (card.isDuplicateIn(existing));
    return card;
  }
}
