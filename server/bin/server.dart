/// Punto de entrada del Broker.
///
///   dart run bin/server.dart --port 8080 --web-root ../app/build/web
///
/// Debe quedar corriendo antes de que nadie cree o se una a una sala.
/// Para jugar entre redes distintas, esta máquina necesita el puerto TCP
/// abierto/redirigido; desde la misma red basta con su IP local.
library;

import 'dart:io';

import 'package:args/args.dart';
import 'package:nexobingo_server/broker.dart';
import 'package:nexobingo_server/http_server.dart';

Future<void> main(List<String> args) async {
  final parser = ArgParser()
    ..addOption('port', abbr: 'p', defaultsTo: Platform.environment['PORT'] ?? '8080')
    ..addOption('web-root', help: 'Carpeta del build web de Flutter (app/build/web) para servirlo.')
    ..addFlag('help', abbr: 'h', negatable: false);
  final options = parser.parse(args);
  if (options['help'] as bool) {
    print(parser.usage);
    return;
  }

  final port = int.parse(options['port'] as String);
  final webRoot = options['web-root'] as String?;
  final server = await startServer(broker: Broker(), port: port, webRoot: webRoot);

  print('Broker de NexoBingo listo en el puerto ${server.port}.');
  if (webRoot != null) print('Sirviendo la versión web desde $webRoot');
  print('Direcciones para conectarse:');
  print('  ws://localhost:${server.port}/ws  (esta misma máquina)');
  for (final iface in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
    for (final addr in iface.addresses) {
      print('  ws://${addr.address}:${server.port}/ws  (${iface.name})'
          '${webRoot != null ? '  ·  web: http://${addr.address}:${server.port}' : ''}');
    }
  }
}
