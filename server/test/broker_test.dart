import 'dart:async';
import 'dart:io';

import 'package:bingo_core/bingo_core.dart';
import 'package:nexobingo_server/broker.dart';
import 'package:nexobingo_server/http_server.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/io.dart';

/// Cliente de prueba: guarda todo lo que llega y permite esperar un tipo.
class TestClient {
  TestClient(this.channel) {
    channel.stream.listen((raw) {
      final msg = decodeMessage(raw)!;
      _inbox.add(msg);
      _signal.complete();
      _signal = Completer();
    }, onDone: () => closed = true);
  }

  static Future<TestClient> connect(int port) async {
    final channel = IOWebSocketChannel.connect('ws://localhost:$port/ws');
    await channel.ready;
    return TestClient(channel);
  }

  final IOWebSocketChannel channel;
  final List<Map<String, dynamic>> _inbox = [];
  Completer<void> _signal = Completer();
  bool closed = false;

  void send(String type, [Map<String, dynamic> data = const {}]) => channel.sink.add(encodeMessage(type, data));

  /// Espera (y consume) el siguiente mensaje de [type] que cumpla [where].
  Future<Map<String, dynamic>> next(String type, {bool Function(Map<String, dynamic>)? where}) async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (true) {
      final i = _inbox.indexWhere((m) => m['type'] == type && (where?.call(m) ?? true));
      if (i >= 0) return _inbox.removeAt(i);
      final left = deadline.difference(DateTime.now());
      if (left.isNegative) throw TimeoutException('No llegó $type');
      await _signal.future.timeout(left, onTimeout: () {});
    }
  }

  void clear() => _inbox.clear();
  Future<void> close() => channel.sink.close();
}

void main() {
  late HttpServer server;
  late Broker broker;
  int port() => server.port;

  setUp(() async {
    broker = Broker(hostGrace: const Duration(milliseconds: 300));
    server = await startServer(broker: broker, port: 0, address: InternetAddress.loopbackIPv4);
  });

  tearDown(() => server.close(force: true));

  test('el anfitrión no puede crear sala desde web/móvil', () async {
    final phone = await TestClient.connect(port());
    phone.send(Msg.createRoom, {'platform': 'android'});
    final err = await phone.next(Msg.error);
    expect(err['fatal'], isTrue);
    expect(broker.rooms, isEmpty);
    await phone.close();
  });

  test('ronda completa: crear, unirse, modo, iniciar, cantar, BINGO', () async {
    final host = await TestClient.connect(port());
    host.send(Msg.createRoom, {'platform': 'windows'});
    final created = await host.next(Msg.roomCreated);
    final code = created['code'] as String;
    expect(code, matches(RegExp(r'^\d{6}$')));

    final ana = await TestClient.connect(port());
    ana.send(Msg.joinRoom, {'code': code, 'name': 'Ana'});
    final joined = await ana.next(Msg.joined);
    final anaId = joined['tableId'] as int;

    final beto = await TestClient.connect(port());
    beto.send(Msg.joinRoom, {'code': code, 'name': 'Beto'});
    await beto.next(Msg.joined);

    // Código inexistente.
    final ghost = await TestClient.connect(port());
    ghost.send(Msg.joinRoom, {'code': '000000', 'name': 'X'});
    expect((await ghost.next(Msg.error))['message'], contains('código'));

    // Un jugador no puede usar comandos de anfitrión.
    ana.send(Msg.start);
    expect((await ana.next(Msg.error))['message'], contains('anfitrión'));

    // Antes de iniciar no hay cartón.
    var anaState = PlayerState.fromJson(await ana.next(Msg.playerState));
    expect(anaState.card, isNull);

    final pattern = emptyPattern()..[0][0] = true;
    host.send(Msg.setMode, {'mode': GameMode.personalized.name, 'pattern': encodePattern(pattern)});
    host.send(Msg.start);
    anaState = PlayerState.fromJson(await ana.next(Msg.playerState, where: (m) => m['started'] == true));
    expect(anaState.mode, GameMode.personalized);
    expect(patternsEqual(anaState.pattern, pattern), isTrue);
    final card = anaState.card!;
    expect(card.id, anaId);

    // Nadie se une con la ronda en curso.
    ghost.send(Msg.joinRoom, {'code': code, 'name': 'Tarde'});
    expect((await ghost.next(Msg.error))['message'], contains('en juego'));

    // BINGO falso.
    ana.send(Msg.sing);
    expect((await ana.next(Msg.singResult))['valid'], isFalse);

    // Cantar hasta que salga la casilla B de la primera fila de Ana.
    final target = card.numberAt(0, 0);
    while (true) {
      host.send(Msg.draw);
      final ballot = await host.next(Msg.ballot);
      if (ballot['number'] == target) break;
    }
    ana.send(Msg.sing);
    final result = await ana.next(Msg.singResult);
    expect(result['valid'], isTrue);

    final hostState = HostState.fromJson(await host.next(Msg.hostState, where: (m) => m['roundId'] == 1));
    expect(hostState.started, isFalse);
    expect(hostState.winnerRoundId, 0);
    expect(hostState.players, hasLength(2));

    for (final c in [host, ana, beto, ghost]) {
      await c.close();
    }
  });

  test('reconexión del jugador y cierre de sala si el anfitrión no vuelve', () async {
    final host = await TestClient.connect(port());
    host.send(Msg.createRoom, {'platform': 'linux'});
    final code = (await host.next(Msg.roomCreated))['code'] as String;

    final ana = await TestClient.connect(port());
    ana.send(Msg.joinRoom, {'code': code, 'name': 'Ana'});
    final joined = await ana.next(Msg.joined);
    await ana.close();

    // El anfitrión ve a Ana desconectada.
    await host.next(Msg.hostState, where: (m) => (m['players'] as List).any((p) => p['connected'] == false));

    final ana2 = await TestClient.connect(port());
    ana2.send(Msg.resume, {'code': code, 'token': joined['token']});
    expect((await ana2.next(Msg.joined))['tableId'], joined['tableId']);

    await host.close();
    final closed = await ana2.next(Msg.roomClosed);
    expect(closed['message'], contains('anfitrión'));
    expect(broker.rooms, isEmpty);
    await ana2.close();
  });
}
