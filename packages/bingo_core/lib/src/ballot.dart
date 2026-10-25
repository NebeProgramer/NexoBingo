/// Una balota del bingo (letra + número). Inmutable: el "marcado" vive
/// aparte (en el jugador, como conjunto de casillas marcadas; en el
/// servidor, como conjunto de números cantados).
class Ballot {
  const Ballot(this.letter, this.number);

  static const letters = ['B', 'I', 'N', 'G', 'O'];

  /// Letra que corresponde a un número 1..75 (B 1-15, I 16-30, ...).
  factory Ballot.fromNumber(int number) =>
      Ballot(letters[(number - 1) ~/ 15], number);

  final String letter;
  final int number;

  /// Formato con el que se muestra en los historiales: "B-12".
  String get display => '$letter-$number';

  @override
  String toString() => display;

  @override
  bool operator ==(Object other) =>
      other is Ballot && other.letter == letter && other.number == number;

  @override
  int get hashCode => Object.hash(letter, number);
}
