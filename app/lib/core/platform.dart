import 'package:flutter/foundation.dart';

/// El anfitrión solo puede usarse en computadora (Windows, Linux, macOS).
/// En móvil y web la app solo ofrece unirse como jugador.
bool get isDesktop =>
    !kIsWeb &&
    const {TargetPlatform.windows, TargetPlatform.linux, TargetPlatform.macOS}
        .contains(defaultTargetPlatform);

/// Nombre que se le reporta al Broker al crear sala ("windows", "android",
/// "web", ...). El Broker rechaza crear salas desde lo que no sea escritorio.
String get platformName => kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
