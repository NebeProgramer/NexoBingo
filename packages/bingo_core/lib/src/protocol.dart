/// Protocolo JSON que viaja por el WebSocket entre la app y el Broker.
///
/// Cada mensaje es un objeto con un campo `type` y sus datos al mismo
/// nivel. El cliente SIEMPRE abre la conexión (funciona detrás de
/// cualquier router) y el servidor empuja los cambios por ella: ya no
/// hace falta el polling de la versión Java.
library;

import 'dart:convert';

import 'bingo_card.dart';
import 'game_mode.dart';

/// Tipos de mensaje.
abstract final class Msg {
  // Cliente -> servidor
  static const createRoom = 'create_room'; // {platform}
  static const joinRoom = 'join_room'; // {code, name}
  static const resume = 'resume'; // {code, token}
  static const leave = 'leave'; // {}
  static const setMode = 'set_mode'; // anfitrión: {mode, pattern}
  static const start = 'start'; // anfitrión
  static const draw = 'draw'; // anfitrión
  static const end = 'end'; // anfitrión
  static const sing = 'sing'; // jugador

  // Servidor -> cliente
  static const roomCreated = 'room_created'; // {code, token}
  static const joined = 'joined'; // {code, token, tableId}
  static const hostState = 'host_state'; // HostState
  static const playerState = 'player_state'; // PlayerState
  static const ballot = 'ballot'; // {number}
  static const singResult = 'sing_result'; // {valid, message}
  static const roomClosed = 'room_closed'; // {message}
  static const error = 'error'; // {message, fatal}
}

/// Plataformas desde las que se permite crear (y controlar) una sala.
const hostPlatforms = {'windows', 'linux', 'macos'};

String encodeMessage(String type, [Map<String, dynamic> data = const {}]) =>
    jsonEncode({'type': type, ...data});

/// Devuelve null si el texto no es un mensaje válido.
Map<String, dynamic>? decodeMessage(Object? raw) {
  if (raw is! String) return null;
  try {
    final json = jsonDecode(raw);
    if (json is Map<String, dynamic> && json['type'] is String) return json;
  } on FormatException {
    // ignorado: mensaje mal formado
  }
  return null;
}

class PlayerInfo {
  const PlayerInfo({required this.name, required this.tableId, required this.connected});

  final String name;
  final int tableId;
  final bool connected;

  Map<String, dynamic> toJson() => {'name': name, 'tableId': tableId, 'connected': connected};

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
        name: j['name'] as String,
        tableId: j['tableId'] as int,
        connected: j['connected'] as bool? ?? true,
      );
}

/// Lo que necesita el panel del anfitrión para pintarse.
class HostState {
  const HostState({
    required this.code,
    required this.players,
    required this.started,
    required this.called,
    required this.mode,
    required this.pattern,
    required this.roundId,
    required this.winnerTableId,
    required this.winnerRoundId,
  });

  final String code;
  final List<PlayerInfo> players;
  final bool started;
  final List<int> called; // números cantados, en orden
  final GameMode mode;
  final Pattern pattern;
  final int roundId;
  final int winnerTableId;
  final int winnerRoundId;

  Map<String, dynamic> toJson() => {
        'code': code,
        'players': [for (final p in players) p.toJson()],
        'started': started,
        'called': called,
        'mode': mode.name,
        'pattern': encodePattern(pattern),
        'roundId': roundId,
        'winnerTableId': winnerTableId,
        'winnerRoundId': winnerRoundId,
      };

  factory HostState.fromJson(Map<String, dynamic> j) => HostState(
        code: j['code'] as String,
        players: [for (final p in j['players'] as List) PlayerInfo.fromJson(p as Map<String, dynamic>)],
        started: j['started'] as bool,
        called: [for (final n in j['called'] as List) n as int],
        mode: GameMode.fromName(j['mode'] as String?),
        pattern: decodePattern(j['pattern'] as String?) ?? emptyPattern(),
        roundId: j['roundId'] as int,
        winnerTableId: j['winnerTableId'] as int,
        winnerRoundId: j['winnerRoundId'] as int,
      );
}

/// Estado de la partida relevante para UN jugador (sucesor de
/// `ClientState.java`). [card] es null hasta que la ronda inicia.
class PlayerState {
  const PlayerState({
    required this.code,
    required this.tableId,
    required this.roundId,
    required this.started,
    required this.card,
    required this.called,
    required this.mode,
    required this.pattern,
    required this.winnerTableId,
    required this.winnerRoundId,
  });

  final String code;
  final int tableId;
  final int roundId;
  final bool started;
  final BingoCard? card;
  final List<int> called;
  final GameMode mode;
  final Pattern pattern;
  final int winnerTableId; // -1 si nadie ha ganado
  final int winnerRoundId; // ronda en la que ocurrió ese triunfo

  Map<String, dynamic> toJson() => {
        'code': code,
        'tableId': tableId,
        'roundId': roundId,
        'started': started,
        'card': card?.toJson(),
        'called': called,
        'mode': mode.name,
        'pattern': encodePattern(pattern),
        'winnerTableId': winnerTableId,
        'winnerRoundId': winnerRoundId,
      };

  factory PlayerState.fromJson(Map<String, dynamic> j) => PlayerState(
        code: j['code'] as String,
        tableId: j['tableId'] as int,
        roundId: j['roundId'] as int,
        started: j['started'] as bool,
        card: j['card'] == null ? null : BingoCard.fromJson(j['card'] as Map<String, dynamic>),
        called: [for (final n in j['called'] as List) n as int],
        mode: GameMode.fromName(j['mode'] as String?),
        pattern: decodePattern(j['pattern'] as String?) ?? emptyPattern(),
        winnerTableId: j['winnerTableId'] as int,
        winnerRoundId: j['winnerRoundId'] as int,
      );
}
