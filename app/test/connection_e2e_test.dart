// Prueba de punta a punta de GameConnection contra un Broker real.
// Solo corre si se indica dónde está:
//   (en server/)  dart run bin/server.dart --port 8099
//   (en app/)     flutter test test/connection_e2e_test.dart --dart-define=E2E_BROKER=ws://localhost:8099/ws
import 'package:bingo_core/bingo_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexobingo/core/connection.dart';

const _broker = String.fromEnvironment('E2E_BROKER');

void main() {
  test('anfitrión y jugador juegan una ronda y el jugador se reconecta', () async {
    final host = GameConnection(_broker);
    await host.open();
    final created = host.waitFor({Msg.roomCreated});
    host.send(Msg.createRoom, {'platform': 'windows'});
    final room = await created;
    final code = room['code'] as String;
    host.setSession(code, room['token'] as String);

    final player = GameConnection(_broker);
    await player.open();
    final joinedF = player.waitFor({Msg.joined});
    player.send(Msg.joinRoom, {'code': code, 'name': 'Ana'});
    final joined = await joinedF;
    expect(joined['type'], Msg.joined);
    player.setSession(code, joined['token'] as String);

    final startedF = player.messages
        .firstWhere((m) => m['type'] == Msg.playerState && m['started'] == true)
        .timeout(const Duration(seconds: 5));
    host.send(Msg.setMode, {'mode': GameMode.ex.name});
    host.send(Msg.start);
    final state = PlayerState.fromJson(await startedF);
    expect(state.mode, GameMode.ex);
    expect(state.card, isNotNull);

    // Corte de conexión simulado: GameConnection debe reconectar y retomar.
    final resumedF = player.waitFor({Msg.joined});
    player.debugDropConnection();
    final resumed = await resumedF.timeout(const Duration(seconds: 10));
    expect(resumed['tableId'], joined['tableId']);
    expect(player.status.value, ConnectionStatus.connected);

    host.send(Msg.leave);
    final closed = await player.waitFor({Msg.roomClosed});
    expect(closed['type'], Msg.roomClosed);
    host.dispose();
    player.dispose();
  }, skip: _broker.isEmpty ? 'Define E2E_BROKER para correrla' : false, timeout: const Timeout(Duration(seconds: 30)));
}
