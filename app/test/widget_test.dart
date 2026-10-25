import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexobingo/main.dart';
import 'package:nexobingo/services/settings.dart';
import 'package:nexobingo/ui/widgets/pattern_grid.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<Settings> _settings([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return Settings.load();
}

void main() {
  for (final (platform, canHost) in [
    (TargetPlatform.windows, true),
    (TargetPlatform.macOS, true),
    (TargetPlatform.linux, true),
    (TargetPlatform.android, false),
    (TargetPlatform.iOS, false),
  ]) {
    testWidgets('"Crear partida" ${canHost ? 'aparece' : 'NO aparece'} en ${platform.name}', (tester) async {
      debugDefaultTargetPlatformOverride = platform;
      final settings = await _settings();
      await tester.pumpWidget(NexoBingoApp(settings: settings, showStartupDialogs: false));
      expect(find.byKey(const Key('create')), canHost ? findsOneWidget : findsNothing);
      expect(find.byKey(const Key('join')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('el formulario de unirse valida el código', (tester) async {
    final settings = await _settings();
    await tester.pumpWidget(NexoBingoApp(settings: settings, showStartupDialogs: false));
    await tester.tap(find.byKey(const Key('join')));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'Ana');
    await tester.enterText(find.byType(TextField).last, '12');
    await tester.tap(find.text('Unirse'));
    await tester.pump();
    expect(find.text('El código debe tener exactamente 6 dígitos.'), findsOneWidget);
  });

  testWidgets('PatternGrid editable marca la casilla tocada y nunca el centro', (tester) async {
    Pattern pattern = emptyPattern();
    await tester.pumpWidget(MaterialApp(
      home: Center(
        child: SizedBox(
          width: 250,
          height: 250,
          child: StatefulBuilder(
            builder: (context, setState) =>
                PatternGrid(pattern: pattern, onChanged: (p) => setState(() => pattern = p)),
          ),
        ),
      ),
    ));
    final box = tester.getRect(find.byType(PatternGrid));
    // Esquina superior izquierda (B, fila 0) y centro (ID).
    await tester.tapAt(box.topLeft + const Offset(20, 20));
    await tester.tapAt(box.center);
    await tester.pump();
    expect(pattern[0][0], isTrue);
    expect(countCells(pattern), 1);
  });

  test('Settings: personalizado sin patrón vuelve a cartón lleno', () async {
    final s = await _settings({'gameMode': 'personalized'});
    expect(s.mode, GameMode.complete);
    final p = emptyPattern()..[1][1] = true;
    await s.saveMode(GameMode.personalized, p);
    expect(s.mode, GameMode.personalized);
    expect(patternsEqual(s.customPattern, p), isTrue);
  });
}
