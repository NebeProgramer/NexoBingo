import 'dart:io';

import 'package:bingo_core/bingo_core.dart';
import 'package:nexobingo_server/broker.dart';
import 'package:nexobingo_server/http_server.dart';
import 'package:test/test.dart';

import 'broker_test.dart' show TestClient;

/// Levanta un Broker en un puerto libre (con o sin premium).
Future<HttpServer> _start({required bool premium}) => startServer(
  broker: Broker(premium: premium, hostGrace: const Duration(milliseconds: 300)),
  port: 0,
  address: InternetAddress.loopbackIPv4,
);

Future<(TestClient, String)> _host(int port) async {
  final host = await TestClient.connect(port);
  host.send(Msg.createRoom, {'platform': 'windows'});
  final code = (await host.next(Msg.roomCreated))['code'] as String;
  return (host, code);
}

Future<(TestClient, int)> _join(int port, String code, String name) async {
  final c = await TestClient.connect(port);
  c.send(Msg.joinRoom, {'code': code, 'name': name});
  final joined = await c.next(Msg.joined);
  return (c, joined['tableId'] as int);
}

void main() {
  group('Sin premium', () {
    late HttpServer server;
    setUp(() async => server = await _start(premium: false));
    tearDown(() => server.close(force: true));

    test('la sala admite 10 jugadores y rechaza el 11', () async {
      final (host, code) = await _host(server.port);
      final players = <TestClient>[];
      for (var i = 0; i < maxPlayersFree; i++) {
        players.add((await _join(server.port, code, 'J$i')).$1);
      }
      final extra = await TestClient.connect(server.port);
      extra.send(Msg.joinRoom, {'code': code, 'name': 'Once'});
      expect((await extra.next(Msg.error))['message'], contains('llena'));
      for (final c in [host, extra, ...players]) {
        await c.close();
      }
    });

    test('rechaza varios cartones y no manda historial', () async {
      final (host, code) = await _host(server.port);
      final (ana, _) = await _join(server.port, code, 'Ana');
      host.send(Msg.setOptions, {'cardsPerPlayer': 3});
      expect((await host.next(Msg.error))['message'], contains('premium'));

      host.send(Msg.start);
      host.send(Msg.end);
      final state = HostState.fromJson(
        await host.next(Msg.hostState, where: (m) => m['roundId'] == 1),
      );
      expect(state.premium, isFalse);
      expect(state.maxPlayers, maxPlayersFree);
      expect(state.cardsPerPlayer, 1);
      expect(state.history, isEmpty);
      await host.close();
      await ana.close();
    });

    test('el anfitrión puede prohibir el marcado automático', () async {
      final (host, code) = await _host(server.port);
      final (ana, _) = await _join(server.port, code, 'Ana');
      host.send(Msg.setOptions, {'allowAutoMark': false});
      final state = PlayerState.fromJson(
        await ana.next(Msg.playerState, where: (m) => m['allowAutoMark'] == false),
      );
      expect(state.allowAutoMark, isFalse);
      // Un jugador no puede cambiar opciones.
      ana.send(Msg.setOptions, {'allowAutoMark': true});
      expect((await ana.next(Msg.error))['message'], contains('anfitrión'));
      await host.close();
      await ana.close();
    });

    test('trofeos: el ganador aparece con su número de victorias', () async {
      final (host, code) = await _host(server.port);
      final (ana, _) = await _join(server.port, code, 'Ana');
      final (beto, _) = await _join(server.port, code, 'Beto');
      host.send(Msg.setMode, {
        'mode': GameMode.personalized.name,
        'pattern': encodePattern(emptyPattern()..[0][0] = true),
      });
      host.send(Msg.start);
      final started = PlayerState.fromJson(
        await ana.next(Msg.playerState, where: (m) => m['started'] == true),
      );
      final target = started.card!.numberAt(0, 0);
      while ((await _drawOne(host)) != target) {}
      ana.send(Msg.sing);
      expect((await ana.next(Msg.singResult))['valid'], isTrue);

      // Beto (otro jugador) ve a Ana en la lista de ganadores.
      final betoState = PlayerState.fromJson(
        await beto.next(Msg.playerState, where: (m) => (m['winners'] as List).isNotEmpty),
      );
      // Si Beto también completó el patrón con menor ID, ganó él: se
      // valida que haya exactamente un ganador con 1 victoria.
      expect(betoState.winners, hasLength(1));
      expect(betoState.winners.single.wins, 1);
      final hostState = HostState.fromJson(
        await host.next(Msg.hostState, where: (m) => m['roundId'] == 1),
      );
      expect(hostState.players.map((p) => p.wins).reduce((a, b) => a + b), 1);
      expect(betoState.winnerTableId, isNot(-1));
      for (final c in [host, ana, beto]) {
        await c.close();
      }
    });
  });

  group('Con premium', () {
    late HttpServer server;
    setUp(() async => server = await _start(premium: true));
    tearDown(() => server.close(force: true));

    test('varios cartones llegan al jugador e historial al anfitrión', () async {
      final (host, code) = await _host(server.port);
      final (ana, anaId) = await _join(server.port, code, 'Ana');
      host.send(Msg.setOptions, {'cardsPerPlayer': 3});
      host.send(Msg.start);
      final state = PlayerState.fromJson(
        await ana.next(Msg.playerState, where: (m) => m['started'] == true),
      );
      expect(state.cards, hasLength(3));
      expect(state.cards.first.id, anaId);

      host.send(Msg.end);
      final hostState = HostState.fromJson(
        await host.next(Msg.hostState, where: (m) => m['roundId'] == 1),
      );
      expect(hostState.premium, isTrue);
      expect(hostState.maxPlayers, maxPlayersPremium);
      expect(hostState.cardsPerPlayer, 3);
      expect(hostState.history, hasLength(1));
      expect(hostState.history.single.winnerName, isNull);
      await host.close();
      await ana.close();
    });
  });
}

/// Canta una balota y devuelve su número.
Future<int> _drawOne(TestClient host) async {
  host.send(Msg.draw);
  return (await host.next(Msg.ballot))['number'] as int;
}
