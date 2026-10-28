// Comprueba que las pantallas de juego se dibujan sin desbordes en
// tamaño de teléfono y de PC, y que sus funciones responden, usando una
// conexión falsa.
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
import 'package:nexobingo/ui/widgets/common.dart';
import 'package:nexobingo/ui/widgets/premium.dart';
import 'package:nexobingo/ui/widgets/trophy_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _shotDir = String.fromEnvironment('SHOT_DIR');
const _fontDir = String.fromEnvironment('FONT_DIR');

class FakeConnection extends GameConnection {
  FakeConnection() : super('ws://localhost:8080/ws') {
    status.value = ConnectionStatus.connected;
  }

  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  final sent = <String>[];
  final sentData = <Map<String, dynamic>>[];

  @override
  Stream<Map<String, dynamic>> get messages => _controller.stream;

  @override
  void send(String type, [Map<String, dynamic> data = const {}]) {
    sent.add(type);
    sentData.add({'type': type, ...data});
  }

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

Map<String, dynamic> _playerState(
  Game game,
  int tableId,
  String code, {
  bool allowAutoMark = true,
}) =>
    PlayerState(
      code: code,
      tableId: tableId,
      roundId: game.roundId,
      started: game.started,
      cards: game.cardsFor(tableId) ?? const [],
      called: [for (final b in game.called) b.number],
      mode: game.mode,
      pattern: game.winPattern,
      winnerTableId: game.lastWinnerTableId,
      winnerRoundId: game.lastWinnerRoundId,
      allowAutoMark: allowAutoMark,
      winners: [
        for (final p in game.players)
          if (p.wins > 0) PlayerInfo(name: p.name, tableId: p.tableId, connected: true, wins: p.wins),
      ],
    ).toJson();

Map<String, dynamic> _hostState(Game game) => HostState(
      code: '482913',
      players: [
        for (final p in game.players)
          PlayerInfo(name: p.name, tableId: p.tableId, connected: p.name != 'Carla', wins: p.wins),
      ],
      started: game.started,
      called: [for (final b in game.called) b.number],
      mode: game.mode,
      pattern: game.winPattern,
      roundId: game.roundId,
      winnerTableId: game.lastWinnerTableId,
      winnerRoundId: game.lastWinnerRoundId,
      premium: game.premium,
      maxPlayers: game.maxPlayers,
      allowAutoMark: game.allowAutoMark,
      cardsPerPlayer: game.cardsPerPlayer,
      history: game.premium ? game.history : const [],
    ).toJson();

/// Juega una ronda entera hasta que [p] gane (con el patrón de una casilla).
void _winRound(Game game, Player p) {
  game.start();
  while (!p.cards.any((c) => c.isWinner(game.calledNumbers, game.winPattern))) {
    game.draw();
  }
  game.sing(p.id);
}

/// Números ya cantados que hay en el primer cartón de [p].
List<int> _calledOnCard(Game game, Player p) => [
      for (var c = 0; c < 5; c++)
        for (var r = 0; r < 5; r++)
          if (!isCenter(c, r) && game.calledNumbers.contains(p.card.numberAt(c, r))) p.card.numberAt(c, r),
    ];

int _greenCells(WidgetTester tester) =>
    tester.widgetList<Material>(find.byType(Material)).where((m) => m.color == AppColors.green).length;

Future<Settings> _settings() async {
  SharedPreferences.setMockInitialValues({});
  return Settings.load();
}

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
    // Ana ya ganó 2 rondas (para los trofeos). Se asigna directo: jugando
    // rondas, otro cartón con ID menor podría ganarle.
    ana.wins = 2;
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
    testWidgets('PlayerScreen sin desbordes, marcado manual y trofeo: $name', (tester) async {
      final conn = FakeConnection();
      final settings = await _settings();
      await _pump(tester, size,
          PlayerScreen(connection: conn, code: '482913', tableId: ana.tableId, playerName: ana.name, settings: settings));
      conn.emit(Msg.playerState, _playerState(game, ana.tableId, '482913'));
      await tester.pump();

      // Marcar a mano una casilla ya cantada.
      final hit = _calledOnCard(game, ana);
      if (hit.isNotEmpty) {
        // Solo dentro del cartón (la tira de balotas y el contador de
        // ganadores pueden mostrar el mismo número).
        final cardPanel = find.ancestor(of: find.textContaining('TU CARTÓN'), matching: find.byType(SectionCard));
        await tester.tap(find.descendant(of: cardPanel, matching: find.widgetWithText(InkWell, '${hit.first}')));
        await tester.pump();
        expect(_greenCells(tester), 1);
      }
      expect(find.text('Personalizado'), findsOneWidget); // mini-vista del modo
      // Ana ganó 2 rondas: lleva su trofeo junto al nombre.
      final trophy = tester.widget<TrophyBadge>(find.byType(TrophyBadge));
      expect(trophy.wins, 2);
      await _shot(tester, name);
    });
  }

  testWidgets('AutoSelector marca solo lo cantado y respeta al anfitrión', (tester) async {
    final conn = FakeConnection();
    final settings = await _settings();
    await _pump(tester, const Size(390, 844),
        PlayerScreen(connection: conn, code: '482913', tableId: ana.tableId, playerName: ana.name, settings: settings));
    conn.emit(Msg.playerState, _playerState(game, ana.tableId, '482913'));
    await tester.pump();
    expect(_greenCells(tester), 0);

    await tester.tap(find.byKey(const Key('autoMark')));
    await tester.pump();
    expect(_greenCells(tester), _calledOnCard(game, ana).length);
    expect(settings.autoMark, isTrue); // la preferencia queda guardada

    // Sale una balota nueva: se marca sola si está en el cartón.
    game.draw();
    conn.emit(Msg.playerState, _playerState(game, ana.tableId, '482913'));
    await tester.pump();
    expect(_greenCells(tester), _calledOnCard(game, ana).length);
    await _shot(tester, 'player_automark_phone');

    // El anfitrión lo prohíbe: el interruptor queda bloqueado.
    conn.emit(Msg.playerState, _playerState(game, ana.tableId, '482913', allowAutoMark: false));
    await tester.pump();
    expect(find.textContaining('desactivado por el anfitrión'), findsOneWidget);
    expect(tester.widget<Switch>(find.byKey(const Key('autoMark'))).onChanged, isNull);
  });

  testWidgets('Lista de ganadores de la sala', (tester) async {
    final conn = FakeConnection();
    final settings = await _settings();
    final beto = game.players[1];
    await _pump(tester, const Size(390, 844),
        PlayerScreen(connection: conn, code: '482913', tableId: beto.tableId, playerName: beto.name, settings: settings));
    conn.emit(Msg.playerState, _playerState(game, beto.tableId, '482913'));
    await tester.pump();
    expect(find.byType(TrophyBadge), findsNothing); // Beto no ha ganado
    await tester.tap(find.byKey(const Key('winners')));
    await tester.pumpAndSettle();
    expect(find.text('Ana María'), findsOneWidget);
    expect(find.text('2 victorias'), findsOneWidget);
    await _shot(tester, 'player_winners_phone');
  });

  testWidgets('Varios cartones (premium): selector de cartón', (tester) async {
    final g = Game(random: Random(9), premium: true);
    final p = g.register('Ana');
    g.setCardsPerPlayer(3);
    g.start();
    final conn = FakeConnection();
    final settings = await _settings();
    await _pump(tester, const Size(390, 844),
        PlayerScreen(connection: conn, code: '482913', tableId: p.tableId, playerName: 'Ana', settings: settings));
    conn.emit(Msg.playerState, _playerState(g, p.tableId, '482913'));
    await tester.pump();
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.text('#${p.cards[2].id}'));
    await tester.pump();
    expect(find.text('TU CARTÓN #${p.cards[2].id}'), findsOneWidget);
    await _shot(tester, 'player_multicard_phone');
  });

  testWidgets('PlayerScreen esperando inicio (teléfono)', (tester) async {
    final g = Game(random: Random(8));
    final p = g.register('Ana');
    final conn = FakeConnection();
    final settings = await _settings();
    await _pump(tester, const Size(390, 844),
        PlayerScreen(connection: conn, code: '482913', tableId: p.tableId, playerName: 'Ana', settings: settings));
    conn.emit(Msg.playerState, _playerState(g, p.tableId, '482913'));
    await tester.pump();
    expect(find.textContaining('aparecerá'), findsOneWidget);
    await _shot(tester, 'player_waiting_phone');
  });

  testWidgets('HostScreen gratis: trofeos, AutoSelector y premium bloqueado', (tester) async {
    final settings = await _settings();
    final conn = FakeConnection();
    await _pump(tester, const Size(1200, 760), HostScreen(connection: conn, code: '482913', settings: settings));
    expect(conn.sent, contains(Msg.setMode)); // envía el modo guardado al entrar
    conn.emit(Msg.hostState, _hostState(game));
    await tester.pump();
    expect(find.text('JUGADORES (3/10)'), findsOneWidget);
    expect(tester.widget<TrophyBadge>(find.byType(TrophyBadge)).wins, 2);
    expect(find.byType(PremiumTag), findsNWidgets(2)); // cartones + historial
    await _shot(tester, 'host_desktop');

    await tester.tap(find.byKey(const Key('allowAutoMark')));
    expect(conn.sentData.last, {'type': Msg.setOptions, 'allowAutoMark': false});

    await tester.tap(find.byKey(const Key('cardsPerPlayerLocked')));
    await tester.pumpAndSettle();
    expect(find.text('Función premium'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('history')));
    await tester.pumpAndSettle();
    expect(find.text('Función premium'), findsOneWidget);
    expect(conn.sent.where((t) => t == Msg.setOptions), hasLength(1)); // lo premium no se envía
  });

  testWidgets('HostScreen premium: cartones e historial', (tester) async {
    final g = Game(random: Random(10), premium: true);
    final p = g.register('Ana');
    g.setGameMode(GameMode.personalized, emptyPattern()..[0][0] = true);
    _winRound(g, p);
    g.start();
    g.draw();
    g.end();
    final settings = await _settings();
    final conn = FakeConnection();
    await _pump(tester, const Size(1200, 760), HostScreen(connection: conn, code: '482913', settings: settings));
    conn.emit(Msg.hostState, _hostState(g));
    await tester.pump();
    expect(find.byType(PremiumTag), findsNothing);
    expect(find.byKey(const Key('cardsPerPlayer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('history')));
    await tester.pumpAndSettle();
    expect(find.text('Ronda 1'), findsOneWidget);
    expect(find.text('Ronda 2'), findsOneWidget);
    expect(find.text('Sin ganador'), findsOneWidget);
    await _shot(tester, 'host_history_desktop');
  });
}

Future<ByteData> _file(String path) async => ByteData.sublistView(await File(path).readAsBytes());
