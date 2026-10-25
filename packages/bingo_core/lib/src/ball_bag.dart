import 'dart:math';

import 'ballot.dart';

/// Bolsa con las 75 balotas (port de `Board.java`): se sacan al azar y
/// sin repetir.
class BallBag {
  BallBag([Random? random]) : _random = random ?? Random();

  final Random _random;
  final List<int> _remaining = List.generate(75, (i) => i + 1);

  int get remaining => _remaining.length;

  /// Saca una balota que todavía no haya salido, o null si ya no quedan.
  Ballot? drawRandomUnused() {
    if (_remaining.isEmpty) return null;
    final number = _remaining.removeAt(_random.nextInt(_remaining.length));
    return Ballot.fromNumber(number);
  }
}
