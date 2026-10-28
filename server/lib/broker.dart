/// Broker de NexoBingo (sucesor de `BrokerServer.java`): reparte códigos
/// de sala, aloja cada partida y difunde su estado por WebSocket.
///
/// Igual que antes, la partida vive AQUÍ y no en la máquina del
/// anfitrión: anfitrión y jugadores solo abren conexiones salientes, así
/// que el único que necesita ser alcanzable es este proceso.
library;

import 'dart:async';
import 'dart:math';

import 'package:bingo_core/bingo_core.dart';

/// Un extremo de conexión. En producción es un WebSocket; en las pruebas
/// puede ser cualquier cosa que envíe texto.
abstract class Peer {
  void send(String message);
  void close();
}

class Seat {
  Seat(this.tableId);
  final int tableId;
  Peer? peer;
}

class Room {
  Room(this.code, this.hostToken, this.game);

  final String code;
  final String hostToken;
  final Game game;
  Peer? host;
  final Map<String, Seat> seats = {}; // token del jugador -> asiento
  Timer? closeTimer;
}

enum _Role { none, host, player }

class Broker {
  Broker({
    this.hostGrace = const Duration(seconds: 60),
    this.premium = false,
    Random? random,
  }) : _random = random ?? Random.secure();

  /// Tiempo que se espera a que el anfitrión se reconecte antes de cerrar
  /// la sala y liberar su código.
  final Duration hostGrace;

  /// Interruptor global de las funciones premium (varios cartones,
  /// historial exportable, salas de más de 10 jugadores). Mientras sea
  /// false, el servidor las rechaza aunque una app las pida.
  final bool premium;
  final Random _random;
  final Map<String, Room> rooms = {};

  /// Registra una conexión nueva; devuelve el objeto al que hay que
  /// pasarle cada mensaje recibido y avisarle cuando se cierre.
  Connection connect(Peer peer) => Connection._(this, peer);

  void log(String message) => print('[Broker] $message');

  String _newCode() {
    String code;
    do {
      code = _random.nextInt(1000000).toString().padLeft(6, '0');
    } while (rooms.containsKey(code));
    return code;
  }

  String _newToken() => List.generate(
    16,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  /// Empuja el estado actual a todos los conectados de la sala.
  void broadcast(Room room) {
    room.host?.send(encodeMessage(Msg.hostState, hostStateOf(room).toJson()));
    for (final seat in room.seats.values) {
      seat.peer?.send(
        encodeMessage(
          Msg.playerState,
          playerStateOf(room, seat.tableId).toJson(),
        ),
      );
    }
  }

  HostState hostStateOf(Room room) {
    final game = room.game;
    final connected = {
      for (final s in room.seats.values)
        if (s.peer != null) s.tableId,
    };
    return HostState(
      code: room.code,
      players: [
        for (final p in game.players)
          PlayerInfo(
            name: p.name,
            tableId: p.tableId,
            connected: connected.contains(p.tableId),
            wins: p.wins,
          ),
      ],
      started: game.started,
      called: [for (final b in game.called) b.number],
      mode: game.mode,
      pattern: game.winPattern,
      roundId: game.roundId,
      winnerTableId: game.lastWinnerTableId,
      winnerRoundId: game.lastWinnerRoundId,
      premium: game.premium,
      maxPlayers: game.maxPlayers,
      allowAutoMark: game.allowAutoMark,
      cardsPerPlayer: game.cardsPerPlayer,
      // El historial es premium: sin premium ni siquiera viaja.
      history: game.premium ? List.of(game.history) : const [],
    );
  }

  PlayerState playerStateOf(Room room, int tableId) {
    final game = room.game;
    return PlayerState(
      code: room.code,
      tableId: tableId,
      roundId: game.roundId,
      started: game.started,
      cards: game.cardsFor(tableId) ?? const [],
      called: [for (final b in game.called) b.number],
      mode: game.mode,
      pattern: game.winPattern,
      winnerTableId: game.lastWinnerTableId,
      winnerRoundId: game.lastWinnerRoundId,
      winnerCardId: game.lastWinnerCardId,
      allowAutoMark: game.allowAutoMark,
      winners: [
        for (final p in game.players)
          if (p.wins > 0)
            PlayerInfo(
              name: p.name,
              tableId: p.tableId,
              connected: true,
              wins: p.wins,
            ),
      ],
    );
  }

  void closeRoom(Room room, String reason) {
    room.closeTimer?.cancel();
    rooms.remove(room.code);
    for (final seat in room.seats.values) {
      seat.peer?.send(encodeMessage(Msg.roomClosed, {'message': reason}));
    }
    log('Sala ${room.code} cerrada ($reason).');
  }
}

/// Estado de UNA conexión: si es anfitrión o jugador, y de qué sala.
class Connection {
  Connection._(this._broker, this._peer);

  final Broker _broker;
  final Peer _peer;
  _Role _role = _Role.none;
  Room? _room;
  Seat? _seat;

  void _send(String type, [Map<String, dynamic> data = const {}]) =>
      _peer.send(encodeMessage(type, data));

  void _error(String message, {bool fatal = false}) =>
      _send(Msg.error, {'message': message, 'fatal': fatal});

  void onMessage(Object? raw) {
    final msg = decodeMessage(raw);
    if (msg == null) {
      _error('Mensaje no válido.');
      return;
    }
    try {
      _handle(msg);
    } on GameException catch (e) {
      _error(e.message);
    } on TypeError {
      _error('Mensaje con datos incorrectos.');
    }
  }

  void onDone() {
    final room = _room;
    if (room == null) return;
    if (_role == _Role.host && identical(room.host, _peer)) {
      room.host = null;
      room.closeTimer?.cancel();
      room.closeTimer = Timer(
        _broker.hostGrace,
        () => _broker.closeRoom(room, 'El anfitrión cerró la sala.'),
      );
      _broker.log(
        'Anfitrión de ${room.code} desconectado; esperando ${_broker.hostGrace.inSeconds}s.',
      );
    } else if (_role == _Role.player && identical(_seat?.peer, _peer)) {
      _seat!.peer = null;
      _broker.broadcast(room);
    }
  }

  void _handle(Map<String, dynamic> msg) {
    final type = msg['type'] as String;
    switch (type) {
      case Msg.createRoom:
        _createRoom(msg['platform'] as String?);
      case Msg.joinRoom:
        _joinRoom(msg['code'] as String? ?? '', msg['name'] as String? ?? '');
      case Msg.resume:
        _resume(msg['code'] as String? ?? '', msg['token'] as String? ?? '');
      case Msg.leave:
        _leave();
      case Msg.setMode || Msg.setOptions || Msg.start || Msg.draw || Msg.end:
        _hostCommand(type, msg);
      case Msg.sing:
        _sing();
      default:
        _error('Tipo de mensaje desconocido: $type');
    }
  }

  void _createRoom(String? platform) {
    // La app solo ofrece "Crear partida" en escritorio; esto es una
    // segunda barrera por si alguien arma el mensaje a mano.
    if (!hostPlatforms.contains(platform)) {
      _error('Solo se puede ser anfitrión desde una computadora.', fatal: true);
      return;
    }
    if (_role != _Role.none) {
      _error('Esta conexión ya pertenece a una sala.');
      return;
    }
    final room = Room(
      _broker._newCode(),
      _broker._newToken(),
      Game(premium: _broker.premium),
    );
    _broker.rooms[room.code] = room;
    room.host = _peer;
    _role = _Role.host;
    _room = room;
    _broker.log('Sala creada -> código ${room.code}.');
    _send(Msg.roomCreated, {'code': room.code, 'token': room.hostToken});
    _broker.broadcast(room);
  }

  void _joinRoom(String code, String name) {
    name = name.trim();
    if (_role != _Role.none) {
      _error('Esta conexión ya pertenece a una sala.');
      return;
    }
    if (name.isEmpty || name.length > 30) {
      _error('Escribe un nombre de 1 a 30 caracteres.');
      return;
    }
    final room = _broker.rooms[code];
    if (room == null) {
      _error('Ese código no corresponde a ninguna sala abierta.');
      return;
    }
    // El tope de jugadores (10 gratis, 200 premium) lo aplica Game.register.
    if (room.game.started) {
      _error('Esa partida ya está en juego. Espera a que termine la ronda.');
      return;
    }
    final player = room.game.register(name);
    final token = _broker._newToken();
    final seat = Seat(player.tableId)..peer = _peer;
    room.seats[token] = seat;
    _role = _Role.player;
    _room = room;
    _seat = seat;
    _broker.log('$name se unió a ${room.code} (cartón #${player.tableId}).');
    _send(Msg.joined, {
      'code': room.code,
      'token': token,
      'tableId': player.tableId,
      'name': name,
    });
    _broker.broadcast(room);
  }

  /// Reconexión con el token recibido al crear/unirse: el móvil corta la
  /// conexión cuando la app pasa a segundo plano.
  void _resume(String code, String token) {
    final room = _broker.rooms[code];
    if (room == null) {
      _error('La sala ya no existe.', fatal: true);
      return;
    }
    if (token == room.hostToken) {
      if (room.host != null && !identical(room.host, _peer)) room.host!.close();
      room.closeTimer?.cancel();
      room.closeTimer = null;
      room.host = _peer;
      _role = _Role.host;
      _room = room;
      _send(Msg.roomCreated, {'code': room.code, 'token': room.hostToken});
    } else if (room.seats[token] case final seat?) {
      if (seat.peer != null && !identical(seat.peer, _peer)) seat.peer!.close();
      seat.peer = _peer;
      _role = _Role.player;
      _room = room;
      _seat = seat;
      final name = room.game.playerById(seat.tableId)?.name ?? '';
      _send(Msg.joined, {
        'code': room.code,
        'token': token,
        'tableId': seat.tableId,
        'name': name,
      });
    } else {
      _error('Tu sesión en esta sala expiró.', fatal: true);
      return;
    }
    _broker.broadcast(room);
  }

  void _leave() {
    final room = _room;
    if (room == null) return;
    if (_role == _Role.host) {
      _broker.closeRoom(room, 'El anfitrión cerró la sala.');
    } else if (_seat case final seat?) {
      room.seats.removeWhere((_, s) => identical(s, seat));
      room.game.removePlayer(seat.tableId);
      _broker.broadcast(room);
    }
    _role = _Role.none;
    _room = null;
    _seat = null;
  }

  void _hostCommand(String type, Map<String, dynamic> msg) {
    final room = _room;
    if (_role != _Role.host || room == null || !identical(room.host, _peer)) {
      _error('Solo el anfitrión puede hacer eso.');
      return;
    }
    final game = room.game;
    switch (type) {
      case Msg.setMode:
        game.setGameMode(
          GameMode.fromName(msg['mode'] as String?),
          decodePattern(msg['pattern'] as String?),
        );
      case Msg.setOptions:
        // Cada opción es independiente y opcional.
        if (msg['allowAutoMark'] case final bool allow) {
          game.setAllowAutoMark(allow);
        }
        if (msg['cardsPerPlayer'] case final int count) {
          game.setCardsPerPlayer(count);
        }
      case Msg.start:
        game.start();
      case Msg.draw:
        final ballot = game.draw();
        if (ballot == null) {
          _error('No quedan más balotas por cantar.');
          return;
        }
        // El anfitrión se entera primero (para cantarla), luego todos.
        _send(Msg.ballot, {'number': ballot.number});
      case Msg.end:
        game.end();
    }
    _broker.broadcast(room);
  }

  void _sing() {
    final room = _room;
    final seat = _seat;
    if (_role != _Role.player || room == null || seat == null) {
      _error('Solo un jugador puede cantar BINGO.');
      return;
    }
    final result = room.game.sing(seat.tableId);
    _broker.log(
      'Cartón #${seat.tableId} canta BINGO en ${room.code}: ${result.valid ? 'VÁLIDO' : 'falso'}.',
    );
    _send(Msg.singResult, {'valid': result.valid, 'message': result.message});
    if (result.valid) _broker.broadcast(room);
  }
}
