/// Protocolo JSON que viaja por el WebSocket entre la app y el Broker.
///
/// Cada mensaje es un objeto con un campo `type` y sus datos al mismo
/// nivel. El cliente SIEMPRE abre la conexión (funciona detrás de
/// cualquier router) y el servidor empuja los cambios por ella: ya no
/// hace falta el polling de la versión Java.
///
/// Los campos agregados después de la 2.0.0 son opcionales al leer, para
/// que una app vieja y un servidor nuevo (o al revés) sigan entendiéndose.
library;

import 'dart:convert';

import 'bingo_card.dart';
import 'game_mode.dart';
import 'round_record.dart';

/// Tipos de mensaje.
abstract final class Msg {
  // Cliente -> servidor
  static const createRoom = 'create_room'; // {platform}
  static const joinRoom = 'join_room'; // {code, name}
  static const resume = 'resume'; // {code, token}
  static const leave = 'leave'; // {}
  static const setMode = 'set_mode'; // anfitrión: {mode, pattern}
  static const setOptions = 'set_options'; // anfitrión: {allowAutoMark?, cardsPerPlayer?}
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

/// Un jugador de la sala. [wins] alimenta los trofeos.
class PlayerInfo {
  const PlayerInfo({
    required this.name,
    required this.tableId,
    required this.connected,
    this.wins = 0,
  });

  final String name;
  final int tableId;
  final bool connected;
  final int wins;

  Map<String, dynamic> toJson() => {
    'name': name,
    'tableId': tableId,
    'connected': connected,
    'wins': wins,
  };

  factory PlayerInfo.fromJson(Map<String, dynamic> j) => PlayerInfo(
    name: j['name'] as String,
    tableId: j['tableId'] as int,
    connected: j['connected'] as bool? ?? true,
    wins: j['wins'] as int? ?? 0,
  );
}

List<PlayerInfo> _players(Object? raw) => [
  for (final p in raw as List? ?? const [])
    PlayerInfo.fromJson(p as Map<String, dynamic>),
];

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
    this.premium = false,
    this.maxPlayers = 10,
    this.allowAutoMark = true,
    this.cardsPerPlayer = 1,
    this.history = const [],
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

  /// Si la sala tiene las funciones premium habilitadas.
  final bool premium;
  final int maxPlayers;
  final bool allowAutoMark;
  final int cardsPerPlayer;

  /// Rondas terminadas (solo llega con premium).
  final List<RoundRecord> history;

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
    'premium': premium,
    'maxPlayers': maxPlayers,
    'allowAutoMark': allowAutoMark,
    'cardsPerPlayer': cardsPerPlayer,
    'history': [for (final r in history) r.toJson()],
  };

  factory HostState.fromJson(Map<String, dynamic> j) => HostState(
    code: j['code'] as String,
    players: _players(j['players']),
    started: j['started'] as bool,
    called: [for (final n in j['called'] as List) n as int],
    mode: GameMode.fromName(j['mode'] as String?),
    pattern: decodePattern(j['pattern'] as String?) ?? emptyPattern(),
    roundId: j['roundId'] as int,
    winnerTableId: j['winnerTableId'] as int,
    winnerRoundId: j['winnerRoundId'] as int,
    premium: j['premium'] as bool? ?? false,
    maxPlayers: j['maxPlayers'] as int? ?? 10,
    allowAutoMark: j['allowAutoMark'] as bool? ?? true,
    cardsPerPlayer: j['cardsPerPlayer'] as int? ?? 1,
    history: [
      for (final r in j['history'] as List? ?? const [])
        RoundRecord.fromJson(r as Map<String, dynamic>),
    ],
  );
}

/// Estado de la partida relevante para UN jugador (sucesor de
/// `ClientState.java`). [cards] está vacío hasta que la ronda inicia.
class PlayerState {
  const PlayerState({
    required this.code,
    required this.tableId,
    required this.roundId,
    required this.started,
    required this.cards,
    required this.called,
    required this.mode,
    required this.pattern,
    required this.winnerTableId,
    required this.winnerRoundId,
    this.winnerCardId = -1,
    this.allowAutoMark = true,
    this.winners = const [],
  });

  final String code;
  final int tableId;
  final int roundId;
  final bool started;
  final List<BingoCard> cards;
  final List<int> called;
  final GameMode mode;
  final Pattern pattern;
  final int winnerTableId; // -1 si nadie ha ganado
  final int winnerRoundId; // ronda en la que ocurrió ese triunfo
  final int winnerCardId;

  /// Si el anfitrión permite el marcado automático.
  final bool allowAutoMark;

  /// Jugadores con al menos una ronda ganada en la sala.
  final List<PlayerInfo> winners;

  /// Primer cartón (null hasta que la ronda inicia).
  BingoCard? get card => cards.isEmpty ? null : cards.first;

  Map<String, dynamic> toJson() => {
    'code': code,
    'tableId': tableId,
    'roundId': roundId,
    'started': started,
    // 'card' se mantiene para las apps 2.0.0, que solo conocen un cartón.
    'card': card?.toJson(),
    'cards': [for (final c in cards) c.toJson()],
    'called': called,
    'mode': mode.name,
    'pattern': encodePattern(pattern),
    'winnerTableId': winnerTableId,
    'winnerRoundId': winnerRoundId,
    'winnerCardId': winnerCardId,
    'allowAutoMark': allowAutoMark,
    'winners': [for (final w in winners) w.toJson()],
  };

  factory PlayerState.fromJson(Map<String, dynamic> j) {
    final cards = [
      for (final c in j['cards'] as List? ?? const [])
        BingoCard.fromJson(c as Map<String, dynamic>),
    ];
    if (cards.isEmpty && j['card'] != null) {
      cards.add(BingoCard.fromJson(j['card'] as Map<String, dynamic>));
    }
    return PlayerState(
      code: j['code'] as String,
      tableId: j['tableId'] as int,
      roundId: j['roundId'] as int,
      started: j['started'] as bool,
      cards: cards,
      called: [for (final n in j['called'] as List) n as int],
      mode: GameMode.fromName(j['mode'] as String?),
      pattern: decodePattern(j['pattern'] as String?) ?? emptyPattern(),
      winnerTableId: j['winnerTableId'] as int,
      winnerRoundId: j['winnerRoundId'] as int,
      winnerCardId: j['winnerCardId'] as int? ?? -1,
      allowAutoMark: j['allowAutoMark'] as bool? ?? true,
      winners: _players(j['winners']),
    );
  }
}
