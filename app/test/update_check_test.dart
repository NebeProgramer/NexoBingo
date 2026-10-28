import 'package:flutter_test/flutter_test.dart';
import 'package:nexobingo/services/extras.dart';

void main() {
  test('solo avisa con versiones superiores', () {
    expect(isNewerVersion('2.1.0', '2.0.0'), isTrue);
    expect(isNewerVersion('v3.0.0', '2.9.9'), isTrue);
    expect(isNewerVersion('2.10.0', '2.9.0'), isTrue); // por número, no por texto
    expect(isNewerVersion('2.1.1', '2.1'), isTrue);
  });

  test('no avisa con la misma versión ni con inferiores', () {
    expect(isNewerVersion('2.0.0', '2.1.0'), isFalse); // el caso reportado
    expect(isNewerVersion('2.1.0', '2.1.0'), isFalse);
    expect(isNewerVersion('v2.1.0', '2.1.0+2'), isFalse);
    expect(isNewerVersion('2.1', '2.1.0'), isFalse);
    expect(isNewerVersion('1.0.0', '2.1.0'), isFalse);
  });

  test('tags que no son versión no disparan el aviso', () {
    expect(isNewerVersion('beta', '2.1.0'), isFalse);
    expect(isNewerVersion('', '2.1.0'), isFalse);
  });
}
