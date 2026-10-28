import 'dart:async';
import 'dart:math' as math;

import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config.dart';
import '../core/connection.dart';
import '../services/export.dart';
import '../services/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/pattern_grid.dart';
import '../ui/widgets/premium.dart';
import '../ui/widgets/trophy_badge.dart';
import 'pattern_editor_dialog.dart';

/// Panel del anfitrión (sucesor de `GameServerUI.java`): ver jugadores,
/// elegir el modo de juego, iniciar la ronda, cantar balotas y finalizar.
/// Solo se llega aquí desde escritorio (ver `HomeScreen`).
class HostScreen extends StatefulWidget {
  const HostScreen({super.key, required this.connection, required this.code, required this.settings});

  final GameConnection connection;
  final String code;
  final Settings settings;

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  late final StreamSubscription<Map<String, dynamic>> _sub;
  HostState? _state;

  late GameMode _mode = widget.settings.mode;
  late Pattern? _customPattern = widget.settings.customPattern;

  GameConnection get _conn => widget.connection;
  bool get _started => _state?.started ?? false;
  bool get _premium => _state?.premium ?? false;
  Pattern get _previewPattern => _mode == GameMode.personalized ? copyPattern(_customPattern) : _mode.fixedPattern();

  @override
  void initState() {
    super.initState();
    _sub = _conn.messages.listen(_onMessage);
    _conn.status.addListener(_onStatus);
    // La sala recién creada arranca en "Cartón lleno": le avisamos el
    // último modo que usó este anfitrión.
    _sendMode();
  }

  @override
  void dispose() {
    _sub.cancel();
    _conn.status.removeListener(_onStatus);
    _conn.dispose();
    super.dispose();
  }

  void _onStatus() {
    if (!mounted) return;
    setState(() {});
    // Tras reconectar, reenviar el modo por si se cambió sin conexión.
    if (_conn.status.value == ConnectionStatus.connected && !_started) _sendMode();
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case Msg.hostState:
        setState(() => _state = HostState.fromJson(msg));
      case Msg.error:
        if (msg['fatal'] == true) {
          _leave(message: msg['message'] as String);
        } else {
          _snack(msg['message'] as String);
        }
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  void _sendMode() => _conn.send(Msg.setMode, {
        'mode': _mode.name,
        if (_customPattern != null) 'pattern': encodePattern(_customPattern!),
      });

  Future<void> _applyMode(GameMode mode) async {
    setState(() => _mode = mode);
    await widget.settings.saveMode(mode, _customPattern);
    _sendMode();
  }

  Future<void> _onModeSelected(GameMode? mode) async {
    if (mode == null || mode == _mode) return;
    if (mode == GameMode.personalized) {
      final edited = await showPatternEditor(context, _customPattern);
      if (edited != null) {
        _customPattern = edited;
      } else if (_customPattern == null) {
        return; // canceló y no hay patrón previo: se queda el modo anterior
      }
      // Si canceló pero ya había un patrón guardado, se usa ese.
    }
    await _applyMode(mode);
  }

  Future<void> _editPattern() async {
    final edited = await showPatternEditor(context, _customPattern);
    if (edited == null) return;
    _customPattern = edited;
    await _applyMode(GameMode.personalized);
  }

  void _setAutoMark(bool allow) => _conn.send(Msg.setOptions, {'allowAutoMark': allow});

  void _setCardsPerPlayer(int? count) {
    if (count == null) return;
    _conn.send(Msg.setOptions, {'cardsPerPlayer': count});
  }

  /// Historial de rondas (premium): lista y exportación a CSV/Excel.
  Future<void> _openHistory() async {
    if (!_premium) {
      await showPremiumDialog(context, 'El historial de rondas exportable');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) => _HistoryDialog(
        code: widget.code,
        // Se lee del estado más reciente cada vez que se abre.
        history: _state?.history ?? const [],
        onExported: (path) {
          if (path == null) {
            _snack('No se pudo guardar el archivo.');
            return;
          }
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(
              content: Text('Guardado en $path'),
              action: SnackBarAction(label: 'Abrir', onPressed: () => launchUrl(Uri.file(path))),
            ));
        },
      ),
    );
  }

  void _start() {
    // El WebSocket conserva el orden: la ronda arranca con el modo que
    // muestra el selector aunque el cambio anterior no hubiera llegado.
    _sendMode();
    _conn.send(Msg.start);
  }

  Future<void> _end() async {
    final ok = await _confirm('¿Finalizar la partida actual? Se repartirán cartones nuevos para la siguiente ronda.');
    if (ok) _conn.send(Msg.end);
  }

  Future<bool> _confirm(String text) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar'),
          content: Text(text),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
          ],
        ),
      ) ??
      false;

  Future<void> _askLeave() async {
    if (await _confirm('¿Cerrar la sala? Los jugadores conectados saldrán de la partida.')) _leave();
  }

  void _leave({String? message}) {
    _conn.send(Msg.leave);
    _conn.clearSession();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final players = state?.players ?? const <PlayerInfo>[];
    final called = state?.called ?? const <int>[];
    final reconnecting = _conn.status.value != ConnectionStatus.connected;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('NexoBingo · Sala ${widget.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(icon: const Icon(Icons.close), tooltip: 'Cerrar sala', onPressed: _askLeave),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                key: const Key('history'),
                onPressed: _openHistory,
                icon: const Icon(Icons.history),
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Text('Historial de rondas'),
                  if (!_premium) ...[const SizedBox(width: 6), const PremiumTag()],
                ]),
              ),
            ),
          ],
        ),
        body: Column(children: [
          ReconnectingBanner(visible: reconnecting),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _codeBlock(players.length, called.length)),
              const SizedBox(width: 16),
              _modeSelector(),
              const SizedBox(width: 24),
              _optionsPanel(),
            ]),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: 260, child: _playersCard(players)),
                const SizedBox(width: 16),
                Expanded(child: _ballotsCard(called)),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Row(children: [
              Expanded(
                child: AppButton(
                    label: 'Iniciar juego',
                    icon: Icons.play_arrow,
                    color: AppColors.green,
                    onPressed: !_started && players.isNotEmpty && !reconnecting ? _start : null),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                    label: 'Cantar balota',
                    icon: Icons.circle,
                    color: AppColors.blue,
                    onPressed: _started && called.length < 75 && !reconnecting ? () => _conn.send(Msg.draw) : null),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: AppButton(
                    label: 'Finalizar partida',
                    icon: Icons.stop,
                    color: AppColors.red,
                    onPressed: _started && !reconnecting ? _end : null),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _codeBlock(int players, int calledCount) {
    final link = webJoinUrl(_conn.url, widget.code);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(widget.code,
                style:
                    const TextStyle(color: AppColors.gold, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 6)),
          ),
        ),
        IconButton(
          tooltip: 'Copiar código',
          icon: const Icon(Icons.copy, color: AppColors.textMuted),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: widget.code));
            _snack('Código copiado');
          },
        ),
      ]),
      Text(
        _started
            ? 'Juego en curso — balotas cantadas: $calledCount/75 · ${_mode.displayName}'
            : 'Esperando inicio — $players jugador(es) registrado(s) · ${_mode.displayName}',
        style: const TextStyle(color: AppColors.textMuted),
      ),
      const SizedBox(height: 4),
      Text('Los jugadores entran con la app y el código, o desde el navegador en $link',
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
    ]);
  }

  Widget _modeSelector() {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(
        width: 190,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('MODO DE JUEGO', style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<GameMode>(
            key: ValueKey(_mode),
            initialValue: _mode,
            isDense: true,
            isExpanded: true,
            dropdownColor: AppColors.bgCard,
            decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
            items: [
              for (final m in GameMode.values)
                DropdownMenuItem(value: m, child: Text(m.displayName, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: _started ? null : _onModeSelected,
          ),
          if (_mode == GameMode.personalized) ...[
            const SizedBox(height: 6),
            AppButton(
              label: 'Editar patrón',
              icon: Icons.edit,
              color: AppColors.green,
              height: 32,
              onPressed: _started ? null : _editPattern,
            ),
          ],
        ]),
      ),
      const SizedBox(width: 12),
      SizedBox.square(
        dimension: 72,
        child: Tooltip(
          message: 'Patrón para ganar: ${_mode.displayName}',
          child: PatternGrid(pattern: _previewPattern),
        ),
      ),
    ]);
  }

  /// Opciones de la sala: AutoSelector (gratis) y cartones por jugador (premium).
  Widget _optionsPanel() {
    final allowAuto = _state?.allowAutoMark ?? true;
    final cards = _state?.cardsPerPlayer ?? 1;
    return SizedBox(
      width: 210,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('OPCIONES DE LA SALA',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold, fontSize: 13)),
        const SizedBox(height: 2),
        Row(children: [
          const Expanded(child: Text('Permitir marcado automático', style: TextStyle(fontSize: 13))),
          Switch(key: const Key('allowAutoMark'), value: allowAuto, onChanged: _state == null ? null : _setAutoMark),
        ]),
        Row(children: [
          const Expanded(child: Text('Cartones por jugador', style: TextStyle(fontSize: 13))),
          if (_premium)
            DropdownButton<int>(
              key: const Key('cardsPerPlayer'),
              value: cards,
              isDense: true,
              dropdownColor: AppColors.bgCard,
              items: [for (var n = 1; n <= maxCardsPerPlayer; n++) DropdownMenuItem(value: n, child: Text('$n'))],
              onChanged: _started ? null : _setCardsPerPlayer,
            )
          else
            // Bloqueado hasta activar premium: muestra "1" con candado.
            InkWell(
              key: const Key('cardsPerPlayerLocked'),
              borderRadius: BorderRadius.circular(6),
              onTap: () => showPremiumDialog(context, 'Dar varios cartones a cada jugador'),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('1', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 6),
                  PremiumTag(),
                ]),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _playersCard(List<PlayerInfo> players) {
    final max = _state?.maxPlayers ?? maxPlayersFree;
    return SectionCard(
      title: 'Jugadores (${players.length}/$max)',
      child: players.isEmpty
          ? const Center(
              child: Text('Comparte el código para que se unan.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)))
          : ListView.separated(
              itemCount: players.length,
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (_, i) {
                final p = players[i];
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    Icon(Icons.circle, size: 10, color: p.connected ? AppColors.green : AppColors.textMuted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(p.name, overflow: TextOverflow.ellipsis)),
                    // Trofeo con sus victorias (solo si ya ganó alguna ronda).
                    if (p.wins > 0) ...[TrophyBadge(wins: p.wins, size: 24), const SizedBox(width: 8)],
                    Text('#${p.tableId}', style: const TextStyle(color: AppColors.textMuted)),
                  ]),
                );
              },
            ),
    );
  }

  /// Tablero de las 75 balotas (filas B..O) con las cantadas encendidas,
  /// pensado para proyectarse en una pantalla grande.
  Widget _ballotsCard(List<int> called) {
    final calledSet = called.toSet();
    final last = called.isEmpty ? null : Ballot.fromNumber(called.last);
    return SectionCard(
      title: 'Balotas cantadas (${called.length}/75)',
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 130,
          child: Column(children: [
            if (last != null)
              BallotBadge(letter: last.letter, number: last.number, size: 120)
            else
              const SizedBox(
                height: 120,
                child: Center(child: Text('Aún no sale ninguna', style: TextStyle(color: AppColors.textMuted))),
              ),
            const SizedBox(height: 12),
            for (final n in called.reversed.skip(1).take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(Ballot.fromNumber(n).display, style: const TextStyle(color: AppColors.textMuted)),
              ),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: LayoutBuilder(builder: (context, c) {
            // 16 columnas (letra + 15 números) y 5 filas, con 2px de margen.
            final cell = math.max(10.0, math.min((c.maxWidth - 32) / 16, (c.maxHeight - 10) / 5 - 2));
            return Column(children: [
              for (var col = 0; col < 5; col++)
                Row(children: [
                  SizedBox(
                    width: cell,
                    height: cell,
                    child: Center(
                      child: Text(Ballot.letters[col],
                          style: TextStyle(
                              color: AppColors.letter(Ballot.letters[col]),
                              fontWeight: FontWeight.bold,
                              fontSize: cell * 0.5)),
                    ),
                  ),
                  for (var k = 1; k <= 15; k++)
                    _boardCell(col * 15 + k, calledSet.contains(col * 15 + k), Ballot.letters[col], cell),
                ]),
            ]);
          }),
        ),
      ]),
    );
  }

  Widget _boardCell(int n, bool on, String letter, double size) {
    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? AppColors.letter(letter) : AppColors.bgCard,
      ),
      alignment: Alignment.center,
      child: Text('$n',
          style: TextStyle(
              fontSize: size * 0.38,
              fontWeight: FontWeight.bold,
              color: on ? AppColors.bgDark : AppColors.textMuted.withValues(alpha: 0.6))),
    );
  }
}

/// Historial de rondas de la sala con botón para exportarlo (premium).
class _HistoryDialog extends StatelessWidget {
  const _HistoryDialog({required this.code, required this.history, required this.onExported});

  final String code;
  final List<RoundRecord> history;
  final void Function(String? path) onExported;

  @override
  Widget build(BuildContext context) {
    final rounds = history.reversed.toList(); // la más reciente primero
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Historial de rondas · Sala $code',
                style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: rounds.isEmpty
                  ? const Center(
                      child: Text('Todavía no ha terminado ninguna ronda.',
                          style: TextStyle(color: AppColors.textMuted)))
                  : ListView.separated(
                      itemCount: rounds.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final r = rounds[i];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(color: AppColors.bgCard, borderRadius: BorderRadius.circular(10)),
                          child: Row(children: [
                            SizedBox(
                              width: 70,
                              child: Text('Ronda ${r.round}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(width: 110, child: Text(r.mode.displayName)),
                            Expanded(
                              child: Text(
                                r.winnerName == null ? 'Sin ganador' : '${r.winnerName} · #${r.winnerCardId}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: r.winnerName == null ? AppColors.textMuted : AppColors.textLight),
                              ),
                            ),
                            Text('${r.ballotsCalled} ${r.ballotsCalled == 1 ? 'balota' : 'balotas'} · ${formatDateTime(r.endedAt).substring(11)}',
                                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                          ]),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              const Spacer(),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
              const SizedBox(width: 10),
              AppButton(
                label: 'Exportar a Excel (CSV)',
                icon: Icons.download,
                color: AppColors.green,
                height: 42,
                onPressed: rounds.isEmpty
                    ? null
                    : () async {
                        final path = await saveHistoryCsv(code, history);
                        if (context.mounted) Navigator.pop(context);
                        onExported(path);
                      },
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
