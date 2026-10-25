// Comprueba que las pantallas de juego se dibujan sin desbordes en
// tamaño de teléfono y de PC, usando una conexión falsa.
//
// Para guardar capturas PNG con fuentes reales:
//   flutter test test/screens_layout_test.dart \
//     --dart-define=SHOT_DIR=<carpeta> --dart-define=FONT_DIR=<flutter>/bin/cache/artifacts/material_fonts
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexobingo/core/connection.dart';
import 'package:nexobingo/screens/host_screen.dart';
import 'package:nexobingo/screens/player_screen.dart';
import 'package:nexobingo/services/settings.dart';
import 'package:nexobingo/ui/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _fontDir = String.fromEnvironment('FONT_DIR');

class FakeConnection extends GameConnection {
  FakeConnection() : super('ws://localhost:8080/ws') {
    status.value = ConnectionStatus.connected;
  }

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <String>[];

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  void send(String type, [Map<String, dynamic> data = const {}]) => sent.add(type);

  void emit(String type, Map<String, dynamic> data) => _controller.add({'type': type, ...data});
}

final _shotKey = GlobalKey();

Future<void> _pump(WidgetTester tester, Size size, Widget screen) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(RepaintBoundary(
    key: _shotKey,
    child: MaterialApp(debugShowCheckedModeBanner: false, theme: buildTheme(), home: screen),
  ));
}

Future<void> _shot(WidgetTester tester, String name) async {
  final ex = tester.takeException();
  if (ex is FlutterError) debugPrint(ex.toStringDeep());
  expect(ex, isNull);
  if (_shotDir.isEmpty) return;
  await tester.runAsync(() async {
    final boundary = _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await File('$_shotDir/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
  });
}

Map<String, dynamic> _playerState(Game game, int tableId, String code) => PlayerState(
      code: code,
      tableId: tableId,
      roundId: game.roundId,
      started: game.started,
      card: game.cardFor(tableId),
      called: [for (final b in game.called) b.number],
      mode: game.mode,
      pattern: game.winPattern,
      winnerTableId: -1,
      winnerRoundId: -1,
    ).toJson();

void main() {
  setUpAll(() async {
    if (_fontDir.isEmpty) return;
    final roboto = FontLoader('Roboto')
      ..addFont(_file('$_fontDir/roboto-regular.ttf'))
      ..addFont(_file('$_fontDir/roboto-bold.ttf'));
    await roboto.load();
    await (FontLoader('MaterialIcons')..addFont(_file('$_fontDir/materialicons-regular.otf'))).load();
  });

  late Game game;
  late Player ana;

  setUp(() {
    game = Game(random: Random(7));
    ana = game.register('Ana María');
    game.register('Beto');
    game.register('Carla');
    game.setGameMode(GameMode.personalized, emptyPattern()
      ..[0][0] = true
      ..[4][0] = true
      ..[0][4] = true
      ..[4][4] = true
      ..[2][1] = true);
    game.start();
    for (var i = 0; i < 18; i++) {
      game.draw();
    }
  });

  for (final (name, size) in [('player_phone', const Size(390, 844)), ('player_desktop', const Size(1100, 760))]) {
    testWidgets('PlayerScreen sin desbordes: $name', (tester) async {
      final conn = FakeConnection();
      await _pump(tester, size,
          PlayerScreen(connection: conn, code: '482913', tableId: ana.tableId, playerName: ana.name));
      conn.emit(Msg.playerState, _playerState(game, ana.tableId, '482913'));
      await tester.pump();
      // Marcar una casilla ya cantada.
      final called = game.calledNumbers;
      final hit = [
        for (var c = 0; c < 5; c++)
          for (var r = 0; r < 5; r++)
            if (called.contains(ana.card.numberAt(c, r))) ana.card.numberAt(c, r),
      ];
      if (hit.isNotEmpty) {
        // InkWell = casilla del cartón (la tira de balotas no es tocable).
        await tester.tap(find.widgetWithText(InkWell, '${hit.first}'));
        await tester.pump();
        final cell = tester.widget<Material>(
            find.ancestor(of: find.widgetWithText(InkWell, '${hit.first}'), matching: find.byType(Material)).first);
        expect(cell.color, AppColors.green);
      }
      expect(find.text('Personalizado'), findsOneWidget); // mini-vista del modo
      await _shot(tester, name);
    });
  }

  testWidgets('PlayerScreen esperando inicio (teléfono)', (tester) async {
    final g = Game(random: Random(8));
    final p = g.register('Ana');
    final conn = FakeConnection();
    await _pump(tester, const Size(390, 844), PlayerScreen(connection: conn, code: '482913', tableId: p.tableId, playerName: 'Ana'));
    conn.emit(Msg.playerState, _playerState(g, p.tableId, '482913'));
    await tester.pump();
    expect(find.textContaining('aparecerá'), findsOneWidget);
    await _shot(tester, 'player_waiting_phone');
  });

  testWidgets('HostScreen sin desbordes (PC)', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await Settings.load();
    final conn = FakeConnection();
    await _pump(tester, const Size(1200, 760), HostScreen(connection: conn, code: '482913', settings: settings));
    expect(conn.sent, contains(Msg.setMode)); // envía el modo guardado al entrar
    conn.emit(
      Msg.hostState,
      HostState(
        code: '482913',
        players: [
          for (final p in game.players) PlayerInfo(name: p.name, tableId: p.tableId, connected: p.name != 'Carla'),
        ],
        started: true,
        called: [for (final b in game.called) b.number],
        mode: GameMode.ti,
        pattern: GameMode.ti.fixedPattern(),
        roundId: 0,
        winnerTableId: -1,
        winnerRoundId: -1,
      ).toJson(),
    );
    await tester.pump();
    await _shot(tester, 'host_desktop');
  });
}

Future<ByteData> _file(String path) async => ByteData.sublistView(await File(path).readAsBytes());
