# NexoBingo — Instrucciones para asistentes de IA

Lee este archivo completo antes de escribir cualquier línea de código. Las decisiones de arquitectura ya están tomadas. Tu trabajo es implementarlas, no reinterpretarlas.

## Contexto del proyecto

- **Nombre:** NexoBingo
- **Descripción:** Bingo multijugador en tiempo real. Un anfitrión crea la sala desde una computadora y los jugadores se unen con un código de 6 dígitos desde el celular, la PC o el navegador.
- **Autor:** Anderson ([portafolio](https://repositorio-aeop.onrender.com))
- **Repositorio:** https://github.com/NebeProgramer/NexoBingo (rama `main`)
- **Estado:** versión 2.0.0 publicada (migración completa de Java a Flutter + Dart). En desarrollo para la siguiente versión: AutoSelector, trofeos de ganadores, límite de 10 jugadores, y dos funciones premium construidas pero bloqueadas (varios cartones e historial exportable). Ver [checklist.md](checklist.md).

## Stack tecnológico (no cambiar)

| Área | Tecnología |
|---|---|
| Lenguaje | Dart 3.8+ |
| App | Flutter (última versión estable; en desarrollo: 3.47.2) |
| Servidor (Broker) | Dart puro: `dart:io` `HttpServer` + WebSocket |
| Lógica compartida | Paquete `bingo_core` (Dart puro, sin Flutter) |
| Comunicación | WebSocket con mensajes JSON (`/ws`) |
| Estado en la app | `StatefulWidget` + streams de `GameConnection` |
| Preferencias locales | `shared_preferences` |
| Hosting del servidor | Render, plan gratuito, Docker |
| Versión web | Build web de Flutter servido por el mismo Broker |

No existen base de datos, cuentas de usuario ni pagos. Si una tarea los necesita, es de la fase premium y requiere decisión explícita (ver [funciones_premium.md](funciones_premium.md)).

## Plataformas objetivo

| Plataforma | Rol permitido | Estado |
|---|---|---|
| Windows | Anfitrión y jugador | Probado (instalado en la PC de Anderson) |
| Linux, macOS | Anfitrión y jugador | Compila; sin probar |
| Android | Solo jugador | Probado (Infinix X6850) |
| iOS | Solo jugador | Sin probar (requiere Mac) |
| Web | Solo jugador | Probado en `https://nexobingo.onrender.com` |

## Estructura de carpetas (respetar siempre)

```
/                                  ← workspace de Dart (pubspec.yaml raíz)
├── Dockerfile                     ← imagen para Render (web + servidor)
├── render.yaml                    ← blueprint de Render
├── packages/
│   └── bingo_core/
│       ├── lib/
│       │   ├── bingo_core.dart    ← exporta todo el paquete
│       │   └── src/
│       │       ├── ballot.dart        ← balota (letra + número)
│       │       ├── ball_bag.dart      ← bolsa de 75 balotas sin repetir
│       │       ├── bingo_card.dart    ← cartón 5x5 y validación de victoria
│       │       ├── game_mode.dart     ← modos y patrones de victoria
│       │       ├── game.dart          ← reglas de la partida, límites y opciones
│       │       ├── round_record.dart  ← una ronda del historial (premium)
│       │       └── protocol.dart      ← mensajes JSON y estados
│       └── test/
├── server/
│   ├── bin/server.dart            ← punto de entrada (args, PORT)
│   ├── lib/
│   │   ├── broker.dart            ← salas, tokens, permisos, reconexión
│   │   └── http_server.dart       ← /ws, /healthz y archivos web
│   └── test/
├── app/
│   ├── lib/
│   │   ├── main.dart
│   │   ├── core/
│   │   │   ├── config.dart        ← BROKER_URL, DEV_MODE, enlace web
│   │   │   ├── connection.dart    ← WebSocket, reconexión, despertar servidor
│   │   │   └── platform.dart      ← isDesktop, platformName
│   │   ├── screens/
│   │   │   ├── home_screen.dart           ← crear (solo escritorio) / unirse
│   │   │   ├── host_screen.dart           ← panel del anfitrión
│   │   │   ├── player_screen.dart         ← cartón del jugador
│   │   │   └── pattern_editor_dialog.dart ← editor del patrón personalizado
│   │   ├── services/
│   │   │   ├── settings.dart      ← preferencias guardadas
│   │   │   ├── extras.dart        ← cartel del café, chequeo de actualizaciones
│   │   │   ├── export.dart        ← historial a CSV (premium)
│   │   │   ├── export_io.dart     ← guardar en Descargas (escritorio)
│   │   │   └── export_stub.dart   ← sin archivos (web)
│   │   └── ui/
│   │       ├── theme.dart         ← AppColors y tema
│   │       └── widgets/
│   │           ├── common.dart        ← AppButton, SectionCard, BallotBadge, ReconnectingBanner
│   │           ├── pattern_grid.dart  ← PatternGrid (CustomPainter), ModeBadge
│   │           ├── trophy_badge.dart  ← trofeo con el número de victorias
│   │           └── premium.dart       ← PremiumTag (candado) y showPremiumDialog
│   └── test/
├── docs/
│   ├── release-notes/             ← notas de versión (formato de Vertex)
│   └── plan/                      ← este archivo, checklist, premium
└── logo/
```

Dónde va cada cosa:
- **Reglas del juego:** siempre en `bingo_core`. El servidor y la app las usan; nunca se duplican.
- **Permisos y difusión de estado:** en `server/lib/broker.dart`.
- **Pantallas:** en `app/lib/screens/`, un archivo por pantalla.
- **Widgets reutilizables:** en `app/lib/ui/widgets/`.

## Roles de usuario (crítico)

Existen 2 roles. Toda lógica de acceso depende de esto.

**Anfitrión:**
- Solo en computadora (Windows, Linux, macOS).
- Crea la sala y recibe un código de 6 dígitos y un token secreto.
- Elige el modo de juego (solo entre rondas), inicia, canta balotas y finaliza.
- Ve la lista de jugadores, con su estado de conexión, y el tablero de 75 balotas.

- Decide si se permite el marcado automático en su sala (por defecto sí, se puede cambiar en cualquier momento).

**Jugador:**
- En cualquier plataforma, sin cuenta.
- Se une con nombre (1 a 30 caracteres) y código. Máximo 10 jugadores por sala (200 con premium).
- Recibe su cartón (o cartones, con premium) solo cuando inicia la ronda.
- Marca a mano (solo balotas ya cantadas) o activa el AutoSelector, si el anfitrión lo permite.
- Canta BINGO y ve los trofeos de quienes han ganado rondas en la sala.

La restricción del anfitrión se aplica **dos veces**, y ambas son obligatorias:
1. La app oculta "Crear partida" si `isDesktop` es falso.
2. El servidor rechaza `create_room` si `platform` no está en `hostPlatforms` (`windows`, `linux`, `macos`).

## Gratis y premium (crítico)

Premium no se ofrece todavía. Hay un solo interruptor global en el servidor: la variable de entorno `NEXOBINGO_PREMIUM=true` (por defecto apagado). El servidor la pasa a cada sala como `Game(premium: ...)`.

**Gratis (siempre disponible):**
- Hasta 10 jugadores por sala (`maxPlayersFree`).
- 1 cartón por jugador.
- AutoSelector y trofeos de ganadores.

**Premium (construido, bloqueado):**
- Hasta 200 jugadores (`maxPlayersPremium`).
- 1 a 4 cartones por jugador (`maxCardsPerPlayer`), solo entre rondas.
- Historial de rondas en el panel del anfitrión y exportación a CSV.

Reglas del bloqueo:
- **El servidor es quien bloquea:** `Game` lanza `GameException` si se pide algo premium sin premium, y el historial ni siquiera viaja (`HostState.history` vacío).
- **La app muestra lo premium con `PremiumTag`** y, al tocarlo, `showPremiumDialog`. Nunca envía la petición premium si `HostState.premium` es falso.
- **NO** activar premium ni agregar funciones premium nuevas sin aprobación de Anderson; ver [funciones_premium.md](funciones_premium.md).

## Protocolo WebSocket (`bingo_core/lib/src/protocol.dart`)

Cada mensaje es JSON con un campo `type` y sus datos al mismo nivel. El cliente siempre abre la conexión y el servidor empuja los cambios.

**Cliente → servidor:**

| `type` | Quién | Datos |
|---|---|---|
| `create_room` | Anfitrión | `platform` |
| `join_room` | Jugador | `code`, `name` |
| `resume` | Ambos | `code`, `token` (reconexión) |
| `leave` | Ambos | — (anfitrión: cierra la sala) |
| `set_mode` | Anfitrión | `mode`, `pattern` (25 caracteres `0`/`1`) |
| `set_options` | Anfitrión | `allowAutoMark?` (bool, cuando sea), `cardsPerPlayer?` (1–4, entre rondas, premium) |
| `start` / `draw` / `end` | Anfitrión | — |
| `sing` | Jugador | — |

**Servidor → cliente:**

| `type` | Para | Datos |
|---|---|---|
| `room_created` | Anfitrión | `code`, `token` |
| `joined` | Jugador | `code`, `token`, `tableId`, `name` |
| `host_state` | Anfitrión | `HostState`: jugadores (con `wins`), balotas, modo, patrón, ronda, ganador, `premium`, `maxPlayers`, `allowAutoMark`, `cardsPerPlayer`, `history` (solo con premium) |
| `player_state` | Jugador | `PlayerState`: `cards` (vacío hasta que inicia la ronda), `card` (el primero, para apps 2.0.0), balotas, modo, patrón, ganador (`winnerTableId`, `winnerCardId`), `allowAutoMark`, `winners` (jugadores con ≥1 victoria) |
| `ballot` | Anfitrión | `number` (llega antes que a los jugadores) |
| `sing_result` | Jugador que cantó | `valid`, `message` |
| `room_closed` | Jugadores | `message` |
| `error` | Quien lo causó | `message`, `fatal` (si es `true`, la app vuelve al inicio) |

Patrones de victoria: `List<List<bool>>` indexado `[col][row]` (col 0..4 = B, I, N, G, O; row 0..4 de arriba hacia abajo). La casilla central `[2][2]` es el ID del cartón y nunca se exige.

## Estado del servidor (sin base de datos)

Todo vive en memoria dentro del Broker:

```
Broker.rooms: Map<code, Room>
└── Room
    ├── code: String          (6 dígitos, único)
    ├── hostToken: String     (32 hex, secreto)
    ├── host: Peer?           (null si el anfitrión está desconectado)
    ├── seats: Map<token, Seat{tableId, peer?}>
    ├── closeTimer: Timer?    (cierra la sala 60 s después de perder al anfitrión)
    └── game: Game
        ├── premium: bool         (de NEXOBINGO_PREMIUM)
        ├── players: List<Player{name, id, cards, wins}>
        ├── started: bool
        ├── called: List<Ballot>
        ├── mode: GameMode, customPattern
        ├── cardsPerPlayer: int, allowAutoMark: bool
        ├── history: List<RoundRecord>  (máximo 200 rondas)
        ├── roundId: int
        └── lastWinnerTableId / lastWinnerCardId / lastWinnerRoundId
```

Consecuencia: un redeploy o que Render se duerma cierra todas las salas. No agregar persistencia sin decisión explícita.

## Preferencias locales (`shared_preferences`)

| Clave | Valor | Uso |
|---|---|---|
| `gameMode` | nombre del enum | Último modo del anfitrión |
| `customPattern` | 25 caracteres `0`/`1` | Patrón personalizado guardado |
| `playerName` | String | Nombre del jugador para el formulario |
| `autoMark` | bool | AutoSelector activado por el jugador |
| `devBrokerUrl` | String | Servidor elegido en `DEV_MODE` |
| `coffeeDismissedUntil` | int (ms) | Cartel del café pospuesto 15 días |

## Reglas del juego (`bingo_core/lib/src/game.dart`)

1. **Registro:**
   - El ID del jugador es aleatorio, entre 100 y 999, y es también el ID de su primer cartón. Los cartones extra (premium) reciben otros IDs; ningún ID se repite en la sala.
   - Cada cartón se genera por columna (B 1-15, I 16-30, N 31-45, G 46-60, O 61-75) y nunca repite números con otro de la sala.
   - No hay registro con la ronda en curso ni con la sala llena (`maxPlayers`).
2. **Inicio:** requiere al menos 1 jugador. A partir de aquí `cardsFor` entrega los cartones.
3. **Balotas:** salen al azar de la bolsa de 75 sin repetir; `null` cuando se acaban.
4. **BINGO:**
   - Se valida contra los números que el **servidor** cantó y el patrón del modo, revisando todos los cartones del jugador. Nunca se usa lo que el jugador marcó.
   - Si es falso, la partida sigue.
   - Si es válido, gana el cartón con ID más bajo entre todos los que cumplan el patrón. Su dueño suma 1 a `wins` (trofeo), la ronda queda en el historial y se cierra sola.
5. **Fin de ronda:** limpia balotas, crea una bolsa nueva, reparte cartones nuevos (mismo ID de jugador) y hace `roundId++`. Si se finaliza a mano con la ronda en curso, queda en el historial como "sin ganador".
6. **Modo de juego:** solo se cambia con la ronda detenida. Personalizado exige al menos 1 casilla.
7. **Cartones por jugador:** solo entre rondas; al cambiarlo se reparten de nuevo los cartones de todos.
8. **AutoSelector:** lo hace la app del jugador (marca las balotas cantadas que tiene). El servidor solo transmite `allowAutoMark`, y el BINGO se valida igual que siempre.

Modos (`GameMode`):

| Modo | Casillas exigidas |
|---|---|
| `complete` | Todas |
| `ex` | Las dos diagonales |
| `el` | Columna B + última fila |
| `ti` | Primera fila + columna N |
| `personalized` | Las que dibuje el anfitrión |

## Conexión y reconexión (`app/lib/core/connection.dart`)

- **Primera conexión:** reintenta hasta 100 s, porque Render gratuito tarda ~1 min en despertar. A los 4 s la pantalla muestra "Despertando el servidor, puede tardar hasta un minuto...".
- **Reconexión:** si se cae la conexión con sesión activa, reintenta a los 1, 2, 4 y 8 s y envía `resume` con el token.
- **Al volver la app al primer plano** (móvil): `reconnectNow()`.
- **Servidor:** hace ping cada 20 s para detectar conexiones muertas.

## Paleta de colores (respetar siempre)

NexoBingo tiene un solo tema oscuro ("sala de juegos nocturna"). Usar siempre `AppColors` (`app/lib/ui/theme.dart`); nunca colores sueltos en las pantallas.

| Token | Color | Uso |
|---|---|---|
| `bgDark` | `#101823` | Fondo de pantallas |
| `bgPanel` | `#18233A` | Tarjetas (`SectionCard`), diálogos |
| `bgCard` | `#1F2C47` | Casillas, campos de texto, listas |
| `border` | `#2C3B5C` | Bordes, casilla central del patrón |
| `gold` | `#F2B705` | Títulos, código de sala, acentos |
| `goldDark` | `#C79300` | Botón ¡CANTAR BINGO!, Crear partida |
| `textLight` | `#F3F5F9` | Texto principal |
| `textMuted` | `#8C9AB4` | Texto secundario |
| `green` | `#2ECC71` | Columna N, casillas marcadas, patrón exigido, Iniciar |
| `red` | `#E8534B` | Columna B, Finalizar, errores |
| `blue` | `#4AA3F0` | Columna G, Cantar balota, Unirse |
| `orange` | `#F08A3C` | Columna I |
| `purple` | `#B673E0` | Columna O |

## Convenciones de código

- Idioma del código: inglés (variables, funciones, clases).
- Idioma de la UI: español (todo texto visible al usuario).
- Comentarios: español.
- Clases: PascalCase (ej: `BingoCard`). Variables y funciones: camelCase (ej: `winPattern`).
- Archivos: snake_case en inglés (ej: `player_screen.dart`).
- Constantes: camelCase con `const` (convención de Dart, ej: `gridSize`, `hostPlatforms`).
- Un widget principal por archivo; widgets privados pequeños pueden ir en el mismo archivo.
- Usar `const` donde sea posible.

## Dependencias (usar estas versiones)

**`app/pubspec.yaml`:**
```yaml
dependencies:
  flutter:
    sdk: flutter
  bingo_core: any               # se resuelve dentro del workspace
  web_socket_channel: ^3.0.3
  shared_preferences: ^2.5.5
  url_launcher: ^6.3.2
  http: ^1.6.0
  package_info_plus: ^9.0.1     # NO subir a 10.x: rompe el build de Android

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  flutter_launcher_icons: ^0.14.4
```

**`server/pubspec.yaml`:** `bingo_core: any`, `args: ^2.7.0`; dev: `lints`, `test`, `web_socket_channel`.

**`packages/bingo_core/pubspec.yaml`:** sin dependencias; dev: `lints`, `test`.

Cada pubspec lleva `resolution: workspace`. No agregar dependencias nuevas sin que la tarea lo pida.

## Comandos esenciales

```bash
dart pub get                                                    # en la raíz, una vez

# Pruebas (todas deben pasar antes de cada commit)
cd packages/bingo_core && dart analyze && dart test
cd server && dart analyze && dart test
cd app && flutter analyze && flutter test

# Prueba de punta a punta contra Render
cd app && flutter test test/connection_e2e_test.dart --dart-define=E2E_BROKER=wss://nexobingo.onrender.com/ws

# Servidor local (agregar NEXOBINGO_PREMIUM=true delante para probar premium)
cd server && dart run bin/server.dart --port 8080 --web-root ../app/build/web

# Builds de producción (siempre con BROKER_URL, nunca con DEV_MODE)
cd app
flutter build apk     --release --dart-define=BROKER_URL=wss://nexobingo.onrender.com/ws
flutter build windows --release --dart-define=BROKER_URL=wss://nexobingo.onrender.com/ws
flutter build web     --release
```

## Entorno de desarrollo actual

- **PC:** Windows 11, Flutter 3.47.2, Visual Studio 2026.
- **Celular de pruebas:** Infinix X6850 (Android), por adb/USB.
- **Servidor:** `https://nexobingo.onrender.com` (auto-deploy desde `main`; salud en `/healthz`).
- **App de escritorio instalada en:** `%LOCALAPPDATA%\Programs\NexoBingo`, con acceso directo en el escritorio.
- **El proyecto está dentro de OneDrive**, que bloquea archivos al compilar:
  - Ante "Flutter failed to delete a directory" o `AccessDeniedException`: reintentar o borrar la carpeta indicada en `app/build/`.
  - APK: si falla, compilar desde una copia fuera de OneDrive, excluyendo `app/build`, `.dart_tool` y `*/flutter/ephemeral`.
  - Windows: compilar en la carpeta del proyecto. En rutas temporales muy largas CMake falla con "No CMAKE_CXX_COMPILER".
  - Tras cambiar la versión de un plugin: borrar `app/build/<plugin>` antes de recompilar el APK.
- **Git:** Anderson hace los commits y los push (a veces con GitHub Desktop). No hacer push sin que lo pida.

## Publicar una versión

1. Subir la versión en `app/pubspec.yaml` y `server/pubspec.yaml`.
2. Escribir `docs/release-notes/X.Y.Z.md` con las plantillas de Vertex (cambio mayor, nuevas funciones, arreglo de bugs o experimental), **sin** sección de Colorimetría.
3. Compilar `NexoBingo.apk` y `NexoBingo-Windows.zip` con `BROKER_URL` de producción.
4. Crear la release en GitHub con tag **`X.Y.Z`** sin "v": el chequeo de actualizaciones compara ese tag con la versión de la app.
5. Si el protocolo cambió de forma incompatible, publicar servidor y apps al mismo tiempo y avisarlo en "Cambios importantes".

## Reglas que nunca debes romper

1. **NUNCA** permitir crear o controlar salas fuera de escritorio; mantener las dos barreras (app y servidor).
2. **NUNCA** poner reglas del juego en las pantallas ni en el servidor: van en `bingo_core`.
3. **NUNCA** confiar en el cliente: el servidor valida permisos, estado de la ronda y cada BINGO.
4. **NUNCA** entregar el cartón antes de que inicie la ronda, ni habilitar funciones premium solo en la app: el bloqueo vive en el servidor.
5. **NUNCA** manejar dinero de apuestas: nada de entradas, pozos, premios ni porcentajes. Sería operar juegos de azar sin licencia de Coljuegos. Cualquier cobro es por uso de la herramienta y requiere aprobación de Anderson.
6. **NUNCA** romper el protocolo en silencio: los campos nuevos son opcionales; un cambio incompatible exige versión mayor.
7. **NUNCA** publicar builds con `DEV_MODE=true` ni sin `BROKER_URL` de producción.
8. **NUNCA** usar colores fuera de `AppColors` ni dejar textos de UI en inglés.
9. **NUNCA** dejar una pantalla sin revisar en tamaño teléfono (390×844) y PC.
10. **NUNCA** hacer commit con pruebas fallando; toda función nueva trae su prueba.

## Tarea actual

Consulta siempre [checklist.md](checklist.md) para saber en qué tarea estás. Cuando te pidan implementar una tarea, entrega:
1. Los archivos completos con todo el código necesario.
2. Los imports correctos.
3. Comentarios en español explicando la lógica.
4. Las pruebas correspondientes y el resultado de correrlas.
5. Si la tarea requiere configuración externa (Render, GitHub, pasarela de pago, pubspec), indícalo claramente al final.

---
*Fin de instrucciones — versión 1.0 (25 oct 2026, NexoBingo 2.0.0)*
