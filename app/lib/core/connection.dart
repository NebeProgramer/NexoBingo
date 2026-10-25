import 'dart:async';

import 'package:bingo_core/bingo_core.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { connecting, connected, reconnecting, closed }

/// Conexión WebSocket con el Broker.
///
/// Siempre es la app la que abre la conexión (funciona detrás de
/// cualquier router) y el Broker empuja los cambios por ella. Si la
/// conexión se cae —típico en el móvil al pasar la app a segundo plano—
/// se reconecta sola y retoma la sesión con `resume` y el token que el
/// Broker entregó al crear o unirse.
class GameConnection {
  GameConnection(this.url);

  final String url;
  final status = ValueNotifier(ConnectionStatus.connecting);
  final _messages = StreamController<Map<String, dynamic>>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retryTimer;
  int _retries = 0;
  bool _disposed = false;

  String? _code;
  String? _token;

  Stream<Map<String, dynamic>> get messages => _messages.stream;

  /// Abre la primera conexión. Lanza si el Broker no responde a tiempo.
  ///
  /// En hosting gratuito (Render) el servidor se duerme tras un rato sin
  /// uso y tarda cerca de un minuto en despertar: se reintenta hasta
  /// [wakeTimeout] y se avisa con [onSlow] si la espera se alarga, para
  /// que la pantalla muestre "despertando el servidor".
  Future<void> open({Duration wakeTimeout = const Duration(seconds: 100), VoidCallback? onSlow}) async {
    final deadline = DateTime.now().add(wakeTimeout);
    final slowTimer = Timer(const Duration(seconds: 4), () => onSlow?.call());
    try {
      while (true) {
        try {
          await _connect(timeout: deadline.difference(DateTime.now()));
          return;
        } catch (_) {
          if (_disposed || DateTime.now().isAfter(deadline)) rethrow;
          // Respuesta inmediata con error (p. ej. 502 mientras arranca): reintentar.
          await Future<void>.delayed(const Duration(seconds: 2));
        }
      }
    } finally {
      slowTimer.cancel();
    }
  }

  Future<void> _connect({Duration timeout = const Duration(seconds: 15)}) async {
    _retryTimer?.cancel();
    await _subscription?.cancel();
    final channel = WebSocketChannel.connect(Uri.parse(url));
    _channel = channel;
    await channel.ready.timeout(timeout.isNegative ? Duration.zero : timeout);
    if (_disposed) {
      channel.sink.close();
      return;
    }
    _retries = 0;
    _subscription = channel.stream.listen(
      (raw) {
        final msg = decodeMessage(raw);
        if (msg != null) _messages.add(msg);
      },
      onDone: _onDisconnected,
      onError: (_) {},
      cancelOnError: false,
    );
    status.value = ConnectionStatus.connected;
    if (_code != null && _token != null) {
      send(Msg.resume, {'code': _code, 'token': _token});
    }
  }

  void _onDisconnected() {
    if (_disposed) return;
    if (_code == null) {
      status.value = ConnectionStatus.closed;
      return;
    }
    status.value = ConnectionStatus.reconnecting;
    _scheduleRetry();
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    final seconds = [1, 2, 4, 8][_retries.clamp(0, 3)];
    _retries++;
    _retryTimer = Timer(Duration(seconds: seconds), () async {
      try {
        await _connect();
      } catch (_) {
        _scheduleRetry();
      }
    });
  }

  /// Llamar cuando la app vuelve al primer plano: no espera al próximo
  /// reintento programado.
  void reconnectNow() {
    if (_disposed || status.value == ConnectionStatus.connected) return;
    _retries = 0;
    _retryTimer?.cancel();
    _connect().catchError((_) => _scheduleRetry());
  }

  /// Guarda la sesión con la que se retoma la sala tras un corte.
  void setSession(String code, String token) {
    _code = code;
    _token = token;
  }

  /// Olvida la sesión (al salir de la sala): un corte ya no reconecta.
  void clearSession() {
    _code = null;
    _token = null;
  }

  void send(String type, [Map<String, dynamic> data = const {}]) {
    if (status.value != ConnectionStatus.connected) return;
    _channel?.sink.add(encodeMessage(type, data));
  }

  /// Espera la primera respuesta de alguno de [types] (o un error).
  Future<Map<String, dynamic>> waitFor(Set<String> types) => messages
      .firstWhere((m) => types.contains(m['type']) || m['type'] == Msg.error)
      .timeout(const Duration(seconds: 10));

  /// Solo para pruebas: corta la conexión como si se perdiera la señal.
  @visibleForTesting
  void debugDropConnection() => _channel?.sink.close();

  void dispose() {
    _disposed = true;
    _retryTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    status.value = ConnectionStatus.closed;
    _messages.close();
  }
}
