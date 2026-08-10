# NexoBingo

Bingo multijugador en tiempo real, escrito en Java (Swing + RMI), pensado para jugarse entre computadoras en **redes distintas** — no solo en la misma LAN.

<p align="center">
  <img src="logo/nexobingo-logo-512.png" alt="Logo de NexoBingo" width="180">
</p>

## Descarga

Para jugar no hace falta compilar nada: solo necesitas tener **Java 21 o superior** instalado (JRE es suficiente).

**[⬇ Descargar la última versión](https://repositorio-aeop.onrender.com/desktop/VirtualBingo)**

También puedes buscar el `.zip` de cada versión en la sección [Releases](https://github.com/NebeProgramer/NexoBingo/releases) de este repositorio.

1. Descarga y descomprime `NexoBingo.zip`.
2. Ejecuta `NexoBingo.jar` con doble clic, o desde una terminal:

   ```bash
   java -jar NexoBingo.jar
   ```

La aplicación revisa automáticamente al abrirse si hay una versión más nueva disponible y te avisa con un enlace de descarga.

> Esto solo instala el juego (Nexo + cliente). El Broker es un componente aparte que corre en un servidor con IP pública; ver la sección [Arquitectura](#arquitectura) más abajo.

## Qué es esto

NexoBingo es un juego de bingo cliente-servidor: uno crea la sala (anfitrión), reparte los números y controla la partida; los demás se unen con un código de 6 dígitos y juegan desde su propia máquina, marcando su cartón a mano y cantando BINGO cuando crean tener uno.

Toda la comunicación viaja por **Java RMI**, coordinada por un **Broker** central (el único componente que necesita ser públicamente alcanzable) para que anfitrión y jugadores puedan estar en redes completamente distintas sin que nadie tenga que abrir puertos en su propio router.

## Características

- Crear o unirse a una partida con un código de sala de 6 dígitos
- Varias partidas simultáneas soportadas por el mismo Broker
- Cartones generados aleatoriamente por jugador, con validación de duplicados
- Marcado manual del cartón (el jugador decide qué marcar) y validación de BINGO en el servidor, no en el cliente
- Panel del anfitrión con lista de jugadores y balotas cantadas en tiempo real
- Pensado para jugar entre redes distintas: solo el Broker necesita IP pública

## Arquitectura

```
                    ┌─────────────────────────┐
                    │   Broker (VPS pública)   │
                    │  - reparte códigos       │
                    │  - crea y aloja cada     │
                    │    partida (Game)        │
                    └───────────┬──────────────┘
                     conexiones salientes
                    (nunca al revés — nadie
                     necesita abrir puertos)
              ┌────────────────┼────────────────┐
              │                                  │
   ┌──────────▼──────────┐          ┌────────────▼───────────┐
   │  Anfitrión (Nexo →   │          │  Jugador (Nexo → une-  │
   │  GameServerUI)        │          │  se → BingoClientUI)   │
   │  Controla la partida  │          │  Marca su cartón,      │
   │  por polling remoto   │          │  canta BINGO           │
   └────────────────────────┘          └─────────────────────────┘
```

La partida (`Game`) vive físicamente en la máquina del Broker, no en la del anfitrión. Tanto el panel del anfitrión como el cliente del jugador se refrescan por **polling** (preguntan al servidor cada ~800ms) en vez de recibir *push* del servidor — así ninguno de los dos necesita ser alcanzable desde afuera, solo el Broker.

## Stack técnico

- Java 21+ (Swing para la interfaz, RMI para la comunicación)
- Maven
- Sin dependencias externas

## Estructura del proyecto

```
src/main/java/com/mycompany/virtual_bingo/
├── Broker/       → BrokerServer: crea y reparte partidas por código
├── Nexus/        → NexusUI: pantalla de inicio (crear/unirse)
├── Server/       → Game (lógica) y GameServerUI (panel del anfitrión)
├── Client/       → BingoClientUI (cliente del jugador)
├── RMI/          → Contratos remotos (BingoService, ClientState, ...)
├── Game_Objects/ → Cartones, balotas, tablero
└── UI/           → Tema visual, componentes reutilizables, cartel de café
```

## Cómo correrlo

### Requisitos

- Java 21 o superior
- Maven (o abrir el proyecto directo en NetBeans)

### 1. Levantar el Broker

El Broker debe correr en una máquina con IP pública alcanzable por todos los jugadores (una VPS, por ejemplo):

```bash
java -Djava.rmi.server.hostname=<IP_PUBLICA> -cp target/classes com.mycompany.virtual_bingo.Broker.BrokerServer
```

### 2. Compilar y correr el juego

```bash
mvn clean package
java -jar target/NexoBingo.jar
```

Se abre la ventana **Nexo**: ahí eliges **Crear partida** (te da un código de 6 dígitos para compartir) o **Unirse a partida** (pides el código a quien la creó).

> La carpeta `target/` no está incluida en este repositorio (se genera al compilar). Si solo quieres jugar sin compilar, ve a la sección [Descarga](#descarga).

> El Broker al que se conecta el juego está fijo en el código para producción (`NexusUI.PRODUCTION_BROKER_HOST`). Para desarrollo, hay un flag `DEV_MODE` en esa misma clase que, en `true`, muestra un campo para apuntar a otro Broker (por ejemplo uno local) sin tocar el resto del código.

## Roadmap

- [ ] Cliente móvil (Flutter) que hable con el mismo Broker vía WebSocket, para jugar desde el celular como en Kahoot
- [ ] Historial de partidas / estadísticas por jugador

## Apoya el proyecto

Si te sirvió, la app tiene un botón de "invitarme un café" la primera vez que la abres. También puedes escribirme directo.

## Autor

Hecho por **Anderson**, estudiante de ingeniería de software.
Portafolio: https://repositorio-aeop.onrender.com

## Licencia

Por definir.
