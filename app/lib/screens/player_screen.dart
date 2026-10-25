import 'dart:async';
import 'dart:math' as math;

import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/connection.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import '../ui/widgets/pattern_grid.dart';

/// Pantalla del jugador (sucesora de `BingoClientUI.java`). Funciona en
/// móvil, PC y web. El jugador marca su propia casilla (no se marca sola
/// al cantarse la balota) y decide cuándo cantar BINGO; el servidor es
/// quien valida contra las balotas que realmente cantó.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.connection,
    required this.code,
    required this.tableId,
    required this.playerName,
  });

  final GameConnection connection;
  final String code;
  final int tableId;
  final String playerName;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> with WidgetsBindingObserver {
  late final StreamSubscription<Map<String, dynamic>> _sub;
  PlayerState? _state;
  final Set<int> _marked = {};
  int _roundId = -1;
  int _calledCount = 0;
  int? _seenWinnerRound; // null hasta el primer estado (no anunciar ganadores viejos)
  bool _singing = false;

  GameConnection get _conn => widget.connection;
  BingoCard? get _card => _state?.card;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sub = _conn.messages.listen(_onMessage);
    _conn.status.addListener(_onStatus);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub.cancel();
    _conn.status.removeListener(_onStatus);
    _conn.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // En el móvil la conexión suele morir en segundo plano: al volver,
    // reconectar ya en vez de esperar el siguiente reintento.
    if (state == AppLifecycleState.resumed) _conn.reconnectNow();
  }

  void _onStatus() {
    if (mounted) setState(() {});
  }

  void _onMessage(Map<String, dynamic> msg) {
    switch (msg['type']) {
      case Msg.playerState:
        _applyState(PlayerState.fromJson(msg));
      case Msg.singResult:
        setState(() => _singing = false);
        // Si fue válido, el anuncio de ganador llega con el estado.
        if (msg['valid'] != true) _alert(msg['message'] as String);
      case Msg.roomClosed:
        _exit(msg['message'] as String);
      case Msg.error:
        if (msg['fatal'] == true) {
          _exit(msg['message'] as String);
        } else {
          setState(() => _singing = false);
          _snack(msg['message'] as String);
        }
    }
  }

  void _applyState(PlayerState s) {
    final previous = _state;
    setState(() {
      // Ronda nueva (cierre manual o por BINGO): limpiar las marcas.
      if (s.roundId != _roundId) {
        _roundId = s.roundId;
        _marked.clear();
      }
      if (s.called.length > _calledCount && previous != null) HapticFeedback.lightImpact();
      _calledCount = s.called.length;
      _state = s;
    });

    // Anuncio de victoria (propia o ajena), una sola vez por ronda.
    if (_seenWinnerRound == null) {
      _seenWinnerRound = s.winnerRoundId;
    } else if (s.winnerTableId != -1 && s.winnerRoundId != _seenWinnerRound) {
      _seenWinnerRound = s.winnerRoundId;
      final iWon = s.winnerTableId == widget.tableId;
      if (iWon) HapticFeedback.heavyImpact();
      _alert(iWon ? '¡Ganaste! Cartón #${s.winnerTableId}' : 'Ganó el cartón #${s.winnerTableId}',
          title: iWon ? '¡BINGO!' : 'Fin de la ronda');
    }
  }

  void _snack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 2)));
  }

  Future<void> _alert(String text, {String title = 'NexoBingo'}) => showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title, style: const TextStyle(color: AppColors.gold)),
          content: Text(text, style: const TextStyle(fontSize: 16)),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
        ),
      );

  /// Marcado MANUAL: solo si esa balota ya salió. Un segundo toque la
  /// desmarca (por si el jugador se equivoca).
  void _onCellTap(int number) {
    final called = _state?.called ?? const [];
    if (!_marked.contains(number) && !called.contains(number)) {
      _snack('Esa balota todavía no ha sido cantada.');
      return;
    }
    setState(() => _marked.contains(number) ? _marked.remove(number) : _marked.add(number));
  }

  void _sing() {
    setState(() => _singing = true);
    _conn.send(Msg.sing);
  }

  Future<void> _askLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Salir'),
        content: const Text('¿Salir de la sala? Perderás tu cartón.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí')),
        ],
      ),
    );
    if (ok == true) {
      _conn.send(Msg.leave);
      _exit(null);
    }
  }

  void _exit(String? message) {
    _conn.clearSession();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).popUntil((r) => r.isFirst);
    if (message != null) messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  String get _statusText {
    final s = _state;
    if (s == null) return 'Conectando...';
    if (s.started && s.card != null) return '¡Juego iniciado! Tu cartón es el #${s.card!.id}';
    return 'Hola ${widget.playerName}. Espera a que el anfitrión inicie la partida.';
  }

  @override
  Widget build(BuildContext context) {
    final s = _state;
    final reconnecting = _conn.status.value != ConnectionStatus.connected;
    final called = s?.called ?? const <int>[];
    final canSing = s != null && s.started && s.card != null && !_singing && !reconnecting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sala ${widget.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
          leading: IconButton(icon: const Icon(Icons.logout), tooltip: 'Salir', onPressed: _askLeave),
        ),
        body: SafeArea(
          top: false,
          child: Column(children: [
            ReconnectingBanner(visible: reconnecting),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.playerName,
                        style: const TextStyle(color: AppColors.gold, fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(_statusText, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                  ]),
                ),
                const SizedBox(width: 12),
                // Mini-vista del modo en la esquina: qué hay que cubrir para ganar.
                if (s != null) ModeBadge(mode: s.mode, pattern: s.pattern),
              ]),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth >= 700;
                final card = _cardPanel();
                if (wide) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Expanded(child: card),
                      const SizedBox(width: 16),
                      SizedBox(width: 200, child: _historyPanel(called)),
                    ]),
                  );
                }
                return Column(children: [
                  _recentStrip(called),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: card)),
                ]);
              }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: AppButton(
                  label: _singing ? 'Validando...' : '¡CANTAR BINGO!',
                  icon: Icons.star,
                  color: AppColors.goldDark,
                  height: 56,
                  onPressed: canSing ? _sing : null,
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _cardPanel() {
    final card = _card;
    return SectionCard(
      title: card == null ? 'Tu cartón' : 'Tu cartón #${card.id}',
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(builder: (context, c) {
        final cell = math.min(c.maxWidth / 5, c.maxHeight / 6);
        return Center(
          child: SizedBox(
            width: cell * 5,
            height: cell * 6,
            child: Stack(children: [
              Column(children: [
                Row(children: [
                  for (final letter in Ballot.letters)
                    SizedBox(
                      width: cell,
                      height: cell,
                      child: Center(
                        child: Text(letter,
                            style: TextStyle(
                                color: AppColors.letter(letter), fontWeight: FontWeight.bold, fontSize: cell * 0.45)),
                      ),
                    ),
                ]),
                for (var row = 0; row < 5; row++)
                  Row(children: [
                    for (var col = 0; col < 5; col++) _cell(card, col, row, cell),
                  ]),
              ]),
              if (card == null)
                Positioned.fill(
                  top: cell,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.bgDark.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(12)),
                      child: const Text('Tu cartón aparecerá\ncuando inicie la ronda',
                          textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
                    ),
                  ),
                ),
            ]),
          ),
        );
      }),
    );
  }

  Widget _cell(BingoCard? card, int col, int row, double size) {
    final letter = Ballot.letters[col];
    final center = isCenter(col, row);
    final number = card?.numberAt(col, row);
    final marked = number != null && _marked.contains(number);
    final label = card == null ? '' : (center ? '#${card.id}' : '$number');
    final d = size - 6;

    return SizedBox(
      width: size,
      height: size,
      child: Center(
        child: Material(
          color: center ? AppColors.bgCard : (marked ? AppColors.green : AppColors.bgCard),
          shape: CircleBorder(side: BorderSide(color: center ? AppColors.textMuted : AppColors.letter(letter), width: 2.4)),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: card == null || center ? null : () => _onCellTap(number!),
            child: SizedBox(
              width: d,
              height: d,
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      color: center ? AppColors.textMuted : AppColors.textLight,
                      fontWeight: FontWeight.bold,
                      fontSize: center ? d * 0.26 : d * 0.36,
                    )),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// En móvil: las últimas balotas en una tira horizontal (la más nueva primero).
  Widget _recentStrip(List<int> called) {
    return SizedBox(
      height: 64,
      child: called.isEmpty
          ? const Center(child: Text('Aún no sale ninguna balota', style: TextStyle(color: AppColors.textMuted)))
          : ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (i, n) in called.reversed.indexed)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Center(
                      child: BallotBadge(
                          letter: Ballot.fromNumber(n).letter, number: n, size: i == 0 ? 58 : 44),
                    ),
                  ),
              ],
            ),
    );
  }

  /// En PC: historial completo al costado, con la última balota grande.
  Widget _historyPanel(List<int> called) {
    final last = called.isEmpty ? null : Ballot.fromNumber(called.last);
    return SectionCard(
      title: 'Balotas cantadas',
      child: Column(children: [
        if (last != null) ...[
          BallotBadge(letter: last.letter, number: last.number, size: 96),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: called.isEmpty
              ? const Center(child: Text('Aún no sale ninguna', style: TextStyle(color: AppColors.textMuted)))
              : ListView(children: [
                  for (final n in called.reversed.skip(1))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(Ballot.fromNumber(n).display,
                          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFA9E4B4))),
                    ),
                ]),
        ),
      ]),
    );
  }
}
