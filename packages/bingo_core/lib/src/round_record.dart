import 'game_mode.dart';

/// Una ronda terminada, para el historial de la sala (función premium).
class RoundRecord {
  const RoundRecord({
    required this.round,
    required this.mode,
    required this.ballotsCalled,
    required this.endedAt,
    this.winnerName,
    this.winnerCardId,
  });

  /// Número de ronda dentro de la sala, empezando en 1.
  final int round;
  final GameMode mode;
  final int ballotsCalled;
  final DateTime endedAt;

  /// null si el anfitrión finalizó la ronda sin ganador.
  final String? winnerName;
  final int? winnerCardId;

  Map<String, dynamic> toJson() => {
    'round': round,
    'mode': mode.name,
    'ballotsCalled': ballotsCalled,
    'endedAt': endedAt.toUtc().toIso8601String(),
    'winnerName': winnerName,
    'winnerCardId': winnerCardId,
  };

  factory RoundRecord.fromJson(Map<String, dynamic> j) => RoundRecord(
    round: j['round'] as int,
    mode: GameMode.fromName(j['mode'] as String?),
    ballotsCalled: j['ballotsCalled'] as int? ?? 0,
    endedAt:
        DateTime.tryParse(j['endedAt'] as String? ?? '')?.toLocal() ??
        DateTime.now(),
    winnerName: j['winnerName'] as String?,
    winnerCardId: j['winnerCardId'] as int?,
  );
}
