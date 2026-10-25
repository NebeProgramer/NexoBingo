import 'package:flutter/foundation.dart';

/// Flag SOLO para desarrolladores (equivale a `DEV_MODE` de la versión
/// Java): `flutter run --dart-define=DEV_MODE=true` muestra en el inicio
/// un campo para apuntar a otro Broker. En los builds para jugadores
/// queda en false y siempre se usa [defaultBrokerUrl].
const bool devMode = bool.fromEnvironment('DEV_MODE');

/// Broker fijado al compilar: `--dart-define=BROKER_URL=ws://1.2.3.4:8080/ws`.
const String _brokerUrlDefine = String.fromEnvironment('BROKER_URL');

/// URL del WebSocket del Broker.
///
/// - Si se compiló con BROKER_URL, se usa esa.
/// - En web, el mismo servidor que entregó la página (el Broker sirve el
///   build web), así el jugador solo abre `http://<servidor>:8080`.
/// - Si no, localhost (solo sirve en la misma máquina: en un teléfono
///   "localhost" es el propio teléfono).
String get defaultBrokerUrl {
  if (_brokerUrlDefine.isNotEmpty) return _brokerUrlDefine;
  if (kIsWeb && (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
    final scheme = Uri.base.scheme == 'https' ? 'wss' : 'ws';
    return Uri(scheme: scheme, host: Uri.base.host, port: Uri.base.port, path: '/ws').toString();
  }
  return 'ws://localhost:8080/ws';
}

/// Dirección web que el anfitrión puede compartir para que los jugadores
/// entren desde el navegador (solo funciona si el Broker sirve el build web).
String webJoinUrl(String brokerUrl, String code) {
  final ws = Uri.parse(brokerUrl);
  return Uri(
    scheme: ws.scheme == 'wss' ? 'https' : 'http',
    host: ws.host,
    port: ws.hasPort ? ws.port : null,
    path: '/',
    queryParameters: {'code': code},
  ).toString();
}
