import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config.dart';
import '../core/connection.dart';
import '../core/platform.dart';
import '../services/extras.dart';
import '../services/settings.dart';
import '../ui/theme.dart';
import '../ui/widgets/common.dart';
import 'host_screen.dart';
import 'player_screen.dart';

/// Pantalla de inicio (sucesora de `NexusUI.java`): crear o unirse a una
/// sala. "Crear partida" solo aparece en computadora: el anfitrión no
/// puede usarse desde el móvil ni desde el navegador.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.settings, this.showStartupDialogs = true});

  final Settings settings;
  final bool showStartupDialogs;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _View { home, join }

class _HomeScreenState extends State<HomeScreen> {
  late final _nameController = TextEditingController(text: widget.settings.playerName);
  final _codeController = TextEditingController();
  late final _brokerController = TextEditingController(text: widget.settings.devBrokerUrl ?? defaultBrokerUrl);

  var _view = _View.home;
  var _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    // En web, un enlace "http://servidor/?code=123456" abre directo el
    // formulario de unirse con el código ya escrito.
    final code = kIsWeb ? Uri.base.queryParameters['code'] : null;
    if (code != null && RegExp(r'^\d{6}$').hasMatch(code)) {
      _codeController.text = code;
      _view = _View.join;
    }
    if (widget.showStartupDialogs) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await maybeShowCoffee(context, widget.settings);
        if (mounted) await checkForUpdates(context);
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _brokerController.dispose();
    super.dispose();
  }

  String get _brokerUrl => devMode ? _brokerController.text.trim() : defaultBrokerUrl;

  Future<GameConnection?> _connect() async {
    if (devMode) await widget.settings.saveDevBrokerUrl(_brokerUrl);
    final connection = GameConnection(_brokerUrl);
    try {
      await connection.open(onSlow: () {
        if (mounted && _busy) {
          setState(() => _status = 'Despertando el servidor, puede tardar hasta un minuto...');
        }
      });
      return connection;
    } catch (_) {
      connection.dispose();
      setState(() {
        _busy = false;
        _status = 'No se pudo conectar con el servidor central.';
      });
      return null;
    }
  }

  Future<void> _createGame() async {
    setState(() {
      _busy = true;
      _status = 'Creando sala...';
    });
    final connection = await _connect();
    if (connection == null) return;
    final reply = connection.waitFor({Msg.roomCreated});
    connection.send(Msg.createRoom, {'platform': platformName});
    await _finish(connection, reply, (msg) {
      connection.setSession(msg['code'] as String, msg['token'] as String);
      return HostScreen(connection: connection, code: msg['code'] as String, settings: widget.settings);
    });
  }

  Future<void> _joinGame() async {
    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    if (name.isEmpty) {
      setState(() => _status = 'Escribe tu nombre.');
      return;
    }
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _status = 'El código debe tener exactamente 6 dígitos.');
      return;
    }
    await widget.settings.savePlayerName(name);
    setState(() {
      _busy = true;
      _status = 'Buscando la sala $code...';
    });
    final connection = await _connect();
    if (connection == null) return;
    final reply = connection.waitFor({Msg.joined});
    connection.send(Msg.joinRoom, {'code': code, 'name': name});
    await _finish(connection, reply, (msg) {
      connection.setSession(msg['code'] as String, msg['token'] as String);
      return PlayerScreen(
        connection: connection,
        code: msg['code'] as String,
        tableId: msg['tableId'] as int,
        playerName: name,
        settings: widget.settings,
      );
    });
  }

  Future<void> _finish(
    GameConnection connection,
    Future<Map<String, dynamic>> reply,
    Widget Function(Map<String, dynamic>) screen,
  ) async {
    try {
      final msg = await reply;
      if (!mounted) return;
      if (msg['type'] == Msg.error) {
        connection.dispose();
        setState(() {
          _busy = false;
          _status = msg['message'] as String;
        });
        return;
      }
      setState(() {
        _busy = false;
        _status = null;
      });
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen(msg)));
      if (mounted) setState(() => _codeController.clear());
    } catch (_) {
      connection.dispose();
      if (mounted) {
        setState(() {
          _busy = false;
          _status = 'El servidor no respondió.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset('assets/nexobingo-logo-1024.png', height: 120),
                  const SizedBox(height: 12),
                  const Text('NexoBingo',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.gold, fontSize: 30, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 28),
                  if (devMode) ...[
                    TextField(
                      controller: _brokerController,
                      decoration: const InputDecoration(labelText: 'Servidor central (broker)'),
                    ),
                    const SizedBox(height: 18),
                  ],
                  if (_view == _View.home) ..._homeButtons() else ..._joinForm(),
                  const SizedBox(height: 16),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                  if (_status != null)
                    Text(_status!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _homeButtons() => [
        const Text('¿Qué quieres hacer?', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        if (isDesktop) ...[
          AppButton(
            key: const Key('create'),
            label: 'Crear partida',
            icon: Icons.add_circle_outline,
            color: AppColors.goldDark,
            height: 52,
            onPressed: _busy ? null : _createGame,
          ),
          const SizedBox(height: 14),
        ],
        AppButton(
          key: const Key('join'),
          label: 'Unirse a partida',
          icon: Icons.login,
          color: AppColors.blue,
          height: 52,
          onPressed: _busy
              ? null
              : () => setState(() {
                    _view = _View.join;
                    _status = null;
                  }),
        ),
        if (!isDesktop) ...[
          const SizedBox(height: 14),
          const Text('Para crear una sala usa la app en una computadora.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ],
      ];

  List<Widget> _joinForm() => [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          maxLength: 30,
          decoration: const InputDecoration(labelText: 'Tu nombre', counterText: ''),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _codeController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          style: const TextStyle(fontSize: 22, letterSpacing: 6, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
          decoration: const InputDecoration(labelText: 'Código de 6 dígitos'),
          onSubmitted: (_) => _busy ? null : _joinGame(),
        ),
        const SizedBox(height: 18),
        AppButton(label: 'Unirse', color: AppColors.green, height: 50, onPressed: _busy ? null : _joinGame),
        const SizedBox(height: 10),
        TextButton(
          onPressed: _busy
              ? null
              : () => setState(() {
                    _view = _View.home;
                    _status = null;
                  }),
          child: const Text('← Volver'),
        ),
      ];
}
