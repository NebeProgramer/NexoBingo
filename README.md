# NexoBingo

Bingo multijugador en tiempo real, hecho en **Flutter + Dart**. El anfitrión controla la partida desde una **computadora**; los jugadores juegan desde el **móvil (Android/iOS), la PC o el navegador**.

<p align="center">
  <img src="logo/nexobingo-logo-512.png" alt="Logo de NexoBingo" width="180">
</p>

## Qué es esto

Uno crea la sala (anfitrión), reparte los números y controla la partida; los demás se unen con un código de 6 dígitos, marcan su cartón a mano y cantan BINGO cuando creen tener uno. El servidor valida cada BINGO contra las balotas que realmente cantó.

## Características

- Crear sala (solo en Windows, Linux o macOS) o unirse con un código de 6 dígitos (cualquier plataforma)
- Jugadores en Android, iOS, Windows, Linux, macOS y **navegador web** (sin instalar nada)
- Modos de juego: cartón lleno, X, L, T y **personalizado** (el anfitrión dibuja el patrón); cada jugador ve en la esquina una mini‑vista de lo que debe cubrir
- Varias salas simultáneas en el mismo servidor
- Cartones aleatorios sin duplicados, entregados solo cuando inicia la ronda
- Validación de BINGO en el servidor; si hay ganadores simultáneos gana el cartón con ID más bajo
- Actualizaciones en tiempo real por WebSocket y **reconexión automática** (por ejemplo, si el móvil pasa a segundo plano)
- Tablero de las 75 balotas para el anfitrión (ideal para proyectar)

## Arquitectura

```
                 ┌──────────────────────────────┐
                 │   Broker (server/, en Dart)  │
                 │  - reparte códigos de sala   │
                 │  - aloja cada partida (Game) │
                 │  - sirve la versión web      │
                 └──────────────┬───────────────┘
                   WebSocket /ws (siempre abre el cliente,
                   así nadie necesita abrir puertos en casa)
           ┌────────────────────┼─────────────────────┐
┌──────────▼──────────┐ ┌───────▼────────┐ ┌──────────▼──────────┐
│ Anfitrión (app en   │ │ Jugador móvil  │ │ Jugador PC / web    │
│ Windows/Linux/macOS)│ │ (Android/iOS)  │ │ (app o navegador)   │
└─────────────────────┘ └────────────────┘ └─────────────────────┘
```

Solo el Broker necesita ser alcanzable por todos. La regla de "anfitrión solo en computadora" se aplica dos veces: la app solo muestra **Crear partida** en escritorio, y el Broker rechaza crear salas desde otras plataformas.

## Estructura del proyecto

```
pubspec.yaml            → workspace de Dart (un solo `dart pub get` en la raíz)
packages/bingo_core/    → lógica compartida: cartones, balotas, modos, Game, protocolo JSON
server/                 → Broker: WebSocket + archivos estáticos del build web
app/                    → app Flutter (todas las plataformas)
logo/                   → logo e íconos
```

## Cómo correrlo

### Requisitos

- Flutter 3.32 o superior (incluye Dart)
- Para compilar: Visual Studio (Windows), Android SDK (Android) o Xcode (iOS/macOS) según la plataforma

```bash
dart pub get          # en la raíz: resuelve los tres paquetes
```

### 1. Levantar el Broker

```bash
cd app && flutter build web     # opcional: para que los jugadores entren desde el navegador
cd ../server
dart run bin/server.dart --port 8080 --web-root ../app/build/web
```

Al arrancar imprime las direcciones a las que se puede conectar cada dispositivo (por ejemplo `ws://192.168.1.63:8080/ws`). Para un servidor fijo puedes compilarlo con `dart compile exe bin/server.dart -o nexobingo_server.exe`.

> En un teléfono `localhost` es el propio teléfono: usa la IP de la máquina del Broker en la red local, o una IP pública / dominio con el puerto 8080 abierto para jugar entre redes distintas.

### 2. Correr o compilar la app

La dirección del Broker se fija al compilar:

```bash
cd app
flutter run -d windows --dart-define=BROKER_URL=ws://192.168.1.63:8080/ws   # anfitrión
flutter run -d android --dart-define=BROKER_URL=ws://192.168.1.63:8080/ws   # jugador
flutter build apk      --dart-define=BROKER_URL=ws://mi-servidor.com:8080/ws
flutter build windows  --dart-define=BROKER_URL=ws://mi-servidor.com:8080/ws
```

- Sin `BROKER_URL`, la app usa `ws://localhost:8080/ws`, que solo sirve en la misma máquina del Broker.
- La versión **web** no necesita `BROKER_URL`: se conecta al mismo servidor que la entregó. El anfitrión ve en su panel el enlace para compartir (`http://<servidor>:8080/?code=123456`), que abre directamente el formulario para unirse.
- `--dart-define=DEV_MODE=true` muestra en el inicio un campo para escribir otro Broker sin recompilar.

## Pruebas

```bash
cd packages/bingo_core && dart test   # lógica del juego
cd server && dart test                # Broker con clientes WebSocket reales
cd app && flutter test                # pantallas en tamaño teléfono y PC
```

Prueba de punta a punta contra un Broker corriendo:

```bash
cd app && flutter test test/connection_e2e_test.dart --dart-define=E2E_BROKER=ws://localhost:8080/ws
```

## Historia

Las versiones 1.x eran Java (Swing + RMI). La 2.0 migró todo a Flutter + Dart para poder jugar desde el móvil y el navegador; el polling cada 800 ms se reemplazó por WebSocket.

## Roadmap

- [ ] Cantar las balotas por voz en el panel del anfitrión
- [ ] Historial de partidas / estadísticas por jugador

## Apoya el proyecto

Si te sirvió, la app tiene un botón de "invitarme un café" la primera vez que la abres. También puedes escribirme directo.

## Autor

Hecho por **Anderson**, estudiante de ingeniería de software.
Portafolio: https://repositorio-aeop.onrender.com

## Licencia

Por definir.
