/// Modos de juego: definen QUÉ casillas del cartón deben estar cantadas
/// para que un BINGO sea válido.
///
/// Todos los patrones son `Pattern` = `List<List<bool>>` indexado
/// `[col][row]`, el mismo orden que `BingoCard.cells`: col = B,I,N,G,O
/// (0..4) y row = fila de arriba hacia abajo (0..4). La casilla central
/// (2,2) es el ID del cartón y nunca se exige.
library;

typedef Pattern = List<List<bool>>;

const int gridSize = 5;

enum GameMode {
  complete('Cartón lleno'), // Llenar todo el cartón
  ex('Forma X'), // Las dos diagonales
  el('Forma L'), // Columna B + última fila
  ti('Forma T'), // Primera fila + columna N
  personalized('Personalizado'); // Patrón definido por el anfitrión

  const GameMode(this.displayName);

  final String displayName;

  /// Patrón fijo del modo. Para [personalized] devuelve un patrón vacío:
  /// ese lo define el anfitrión y lo guarda el `Game`.
  Pattern fixedPattern() {
    final p = emptyPattern();
    for (var col = 0; col < gridSize; col++) {
      for (var row = 0; row < gridSize; row++) {
        p[col][row] = switch (this) {
          GameMode.complete => true,
          GameMode.ex => col == row || col == gridSize - 1 - row,
          GameMode.el => col == 0 || row == gridSize - 1,
          GameMode.ti => row == 0 || col == gridSize ~/ 2,
          GameMode.personalized => false,
        };
      }
    }
    p[2][2] = false; // casilla del ID
    return p;
  }

  static GameMode fromName(String? name) => GameMode.values
      .firstWhere((m) => m.name == name, orElse: () => GameMode.complete);
}

Pattern emptyPattern() =>
    List.generate(gridSize, (_) => List.filled(gridSize, false));

bool isCenter(int col, int row) => col == gridSize ~/ 2 && row == gridSize ~/ 2;

/// Casillas exigidas por el patrón (sin contar el ID central).
int countCells(Pattern pattern) {
  var count = 0;
  for (var col = 0; col < gridSize; col++) {
    for (var row = 0; row < gridSize; row++) {
      if (pattern[col][row] && !isCenter(col, row)) count++;
    }
  }
  return count;
}

/// true si es una matriz 5x5 con al menos una casilla exigida.
bool isValidPattern(Pattern? pattern) {
  if (pattern == null || pattern.length != gridSize) return false;
  if (pattern.any((column) => column.length != gridSize)) return false;
  return countCells(pattern) > 0;
}

/// Copia defensiva (tolera null o tamaños raros) con el centro apagado.
Pattern copyPattern(Pattern? pattern) {
  final c = emptyPattern();
  if (pattern != null) {
    for (var col = 0; col < gridSize && col < pattern.length; col++) {
      for (var row = 0; row < gridSize && row < pattern[col].length; row++) {
        c[col][row] = pattern[col][row];
      }
    }
  }
  c[2][2] = false;
  return c;
}

bool patternsEqual(Pattern? a, Pattern? b) {
  if (a == null || b == null) return a == b;
  return encodePattern(a) == encodePattern(b);
}

/// Serializa el patrón como 25 caracteres '0'/'1' (col-major). Es el
/// formato que viaja por la red y el que se guarda en las preferencias.
String encodePattern(Pattern pattern) {
  final sb = StringBuffer();
  for (var col = 0; col < gridSize; col++) {
    for (var row = 0; row < gridSize; row++) {
      sb.write(pattern[col][row] ? '1' : '0');
    }
  }
  return sb.toString();
}

/// Inverso de [encodePattern]; devuelve null si el texto no es válido.
Pattern? decodePattern(String? text) {
  if (text == null || text.length != gridSize * gridSize) return null;
  final p = emptyPattern();
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (ch != '0' && ch != '1') return null;
    p[i ~/ gridSize][i % gridSize] = ch == '1';
  }
  p[2][2] = false;
  return p;
}
