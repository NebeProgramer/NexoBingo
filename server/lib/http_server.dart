/// Servidor HTTP del Broker: `/ws` es el WebSocket del juego y cualquier
/// otra ruta sirve los archivos del build web de Flutter (si se indicó
/// `webRoot`), para que un jugador entre desde el navegador del móvil
/// con solo abrir `http://<servidor>:<puerto>`.
library;

import 'dart:io';

import 'broker.dart';

class _WebSocketPeer implements Peer {
  _WebSocketPeer(this.socket);
  final WebSocket socket;

  @override
  void send(String message) {
    if (socket.readyState == WebSocket.open) socket.add(message);
  }

  @override
  void close() => socket.close(WebSocketStatus.normalClosure, 'Sesión abierta en otro lugar');
}

const _contentTypes = {
  'html': 'text/html; charset=utf-8',
  'js': 'application/javascript',
  'mjs': 'application/javascript',
  'json': 'application/json',
  'css': 'text/css',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'svg': 'image/svg+xml',
  'ico': 'image/x-icon',
  'wasm': 'application/wasm',
  'ttf': 'font/ttf',
  'otf': 'font/otf',
  'woff2': 'font/woff2',
  'txt': 'text/plain; charset=utf-8',
};

Future<HttpServer> startServer({
  required Broker broker,
  int port = 8080,
  String? webRoot,
  InternetAddress? address,
}) async {
  final server = await HttpServer.bind(address ?? InternetAddress.anyIPv4, port);
  final root = webRoot == null ? null : Directory(webRoot).absolute;

  server.listen((request) async {
    try {
      if (request.uri.path == '/ws' && WebSocketTransformer.isUpgradeRequest(request)) {
        final socket = await WebSocketTransformer.upgrade(request);
        // Detecta conexiones muertas (móvil sin señal) sin esperar al TCP.
        socket.pingInterval = const Duration(seconds: 20);
        final connection = broker.connect(_WebSocketPeer(socket));
        socket.listen(connection.onMessage, onDone: connection.onDone, onError: (_) {}, cancelOnError: true);
        return;
      }
      if (request.uri.path == '/healthz') {
        // Para el health check del hosting (Render) y para "despertarlo".
        request.response
          ..headers.contentType = ContentType.json
          ..write('{"ok":true,"rooms":${broker.rooms.length}}');
        await request.response.close();
        return;
      }
      await _serveStatic(request, root);
    } catch (e) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  });
  return server;
}

Future<void> _serveStatic(HttpRequest request, Directory? root) async {
  final response = request.response;
  if (root == null) {
    response
      ..statusCode = HttpStatus.ok
      ..headers.contentType = ContentType.text
      ..write('Broker de NexoBingo en línea. WebSocket en /ws.');
    await response.close();
    return;
  }

  var relative = Uri.decodeComponent(request.uri.path);
  if (relative.endsWith('/')) relative += 'index.html';
  final segments = relative.split('/').where((s) => s.isNotEmpty).toList();
  if (segments.any((s) => s == '..' || s.contains('\\'))) {
    response.statusCode = HttpStatus.forbidden;
    await response.close();
    return;
  }

  var file = File([root.path, ...segments].join(Platform.pathSeparator));
  if (!await file.exists()) {
    // App de una sola página: cualquier ruta desconocida carga index.html.
    file = File('${root.path}${Platform.pathSeparator}index.html');
    if (!await file.exists()) {
      response.statusCode = HttpStatus.notFound;
      await response.close();
      return;
    }
  }

  final ext = file.path.split('.').last.toLowerCase();
  response.headers.set(HttpHeaders.contentTypeHeader, _contentTypes[ext] ?? 'application/octet-stream');
  if (ext == 'html') response.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');
  await response.addStream(file.openRead());
  await response.close();
}
