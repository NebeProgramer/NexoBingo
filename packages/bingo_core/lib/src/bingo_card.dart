import 'dart:math';

import 'game_mode.dart';

/// Cartón de bingo (port de `Tables.java`).
///
/// [numbers] es `[col][row]`: cada columna toma 5 números al azar de su
/// rango (B 1-15, I 16-30, N 31-45, G 46-60, O 61-75). La casilla central
/// no tiene número: ahí va el ID del cartón ([id]); se guarda como 0.
class BingoCard {
  BingoCard._(this.id, this.numbers);

  factory BingoCard.random(int id, [Random? random]) {
    final rng = random ?? Random();
    final numbers = List.generate(gridSize, (col) {
      final range = List.generate(15, (k) => col * 15 + k + 1)..shuffle(rng);
      return List.generate(gridSize, (row) => isCenter(col, row) ? 0 : range[row]);
    });
    return BingoCard._(id, numbers);
  }

  final int id;
  final List<List<int>> numbers;

  int numberAt(int col, int row) => numbers[col][row];

  /// Validación AUTORITATIVA, pensada para el servidor: compara los
  /// números del cartón contra los que el servidor realmente cantó (nunca
  /// contra lo que el jugador marcó en su dispositivo).
  bool isWinner(Set<int> calledNumbers, Pattern pattern) {
    for (var col = 0; col < gridSize; col++) {
      for (var row = 0; row < gridSize; row++) {
        if (!pattern[col][row] || isCenter(col, row)) continue;
        if (!calledNumbers.contains(numbers[col][row])) return false;
      }
    }
    return true;
  }

  bool isIdenticalTo(BingoCard other) {
    for (var col = 0; col < gridSize; col++) {
      for (var row = 0; row < gridSize; row++) {
        if (numbers[col][row] != other.numbers[col][row]) return false;
      }
    }
    return true;
  }

  bool isDuplicateIn(Iterable<BingoCard> others) =>
      others.any((o) => !identical(o, this) && isIdenticalTo(o));

  Map<String, dynamic> toJson() => {'id': id, 'numbers': numbers};

  factory BingoCard.fromJson(Map<String, dynamic> json) => BingoCard._(
        json['id'] as int,
        [
          for (final col in json['numbers'] as List)
            [for (final n in col as List) n as int],
        ],
      );
}
