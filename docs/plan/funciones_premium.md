# Funciones premium — NexoBingo

> **Estado: decisión pendiente.** Por ahora NexoBingo no ofrece premium. Dos funciones premium ya están **construidas pero bloqueadas**: varios cartones por jugador e historial de rondas exportable. Las demás siguen siendo propuesta. Antes de activar o cobrar algo hay que completar la sección "Decisión premium" del [checklist](checklist.md).

## Cómo está bloqueado hoy

- **Interruptor único en el servidor:** la variable de entorno `NEXOBINGO_PREMIUM`. Sin ella (o con cualquier valor distinto de `true`), el servidor:
  - limita las salas a **10 jugadores**;
  - rechaza dar más de 1 cartón por jugador;
  - no envía el historial de rondas.
- **La app muestra estas funciones con candado** (etiqueta "Premium"). Al tocarlas aparece el aviso "Función premium… ¡Muy pronto!".
- **Para activarlas** (cuando se decida): en Render, *Environment → Add Environment Variable*, `NEXOBINGO_PREMIUM` = `true`, y guardar (Render redespliega). Se activan para **todas** las salas, porque todavía no hay cuentas que distingan quién pagó. Antes de cobrar hay que construir las cuentas (sección 5).
- **Para probar en local:** `NEXOBINGO_PREMIUM=true dart run bin/server.dart` en `server/`.

---

## 1. La idea

NexoBingo gana dinero **vendiendo la herramienta a quien organiza bingos**, no participando en el juego.

- **Quién paga:** el anfitrión (colegios, iglesias, fundaciones, empresas, organizadores de fiestas, novenas, bazares).
- **Quién no paga:** los jugadores. Siempre entran gratis, desde la app o la web.
- **Qué no hace NexoBingo:** no cobra entradas a los jugadores, no guarda pozos, no reparte premios ni se queda con un porcentaje de nada. Eso sería operar juegos de suerte y azar, que en Colombia exige concesión de Coljuegos (Ley 643 de 2001).

Ventaja práctica: como el anfitrión solo existe en computadora, los pagos pueden hacerse por una página web y no a través de Google Play o la App Store. Así se evita su comisión, de hasta el 30%.

---

## 2. Gratis vs. Premium

| Función | Gratis | Premium | Estado |
| :--- | :---: | :---: | :--- |
| Crear salas y jugar | ✅ | ✅ | Hecho |
| Jugadores por sala | Hasta 10 | Hasta 200 | Hecho (200 bloqueado) |
| Modos fijos (lleno, X, L, T) | ✅ | ✅ | Hecho |
| Patrón personalizado | 1 guardado | Ilimitados, con nombre | 1 guardado hecho |
| Jugadores desde app y web | ✅ | ✅ | Hecho |
| AutoSelector (marcado automático, el anfitrión puede prohibirlo) | ✅ | ✅ | Hecho |
| Trofeos de ganadores en la sala | ✅ | ✅ | Hecho |
| Varios cartones por jugador (1 a 4) | — | ✅ | **Construido, bloqueado** |
| Historial de rondas y exportar a Excel (CSV) | — | ✅ | **Construido, bloqueado** |
| Canto de balotas por voz | — | ✅ | Propuesta |
| Pantalla para proyectar (modo presentación) | — | ✅ | Propuesta |
| Logo, nombre y colores del evento | — | ✅ | Propuesta |
| Código QR de la sala | ✅ | ✅ | Propuesta |
| Rondas programadas (una tras otra con distintos modos) | — | ✅ | Propuesta |
| Coanfitrión (otra persona ayuda a cantar) | — | ✅ | Propuesta |
| Expulsar jugadores | ✅ | ✅ | Propuesta |
| Sin publicidad | — (publicidad discreta) | ✅ | Propuesta |
| Servidor sin "despertar" (siempre encendido) | — | ✅ | Requiere plan pago de Render |

Principio: **la versión gratuita debe ser buena de verdad** para una reunión familiar. Premium es para quien organiza eventos grandes o con su propia marca.

---

## 3. Detalle de las funciones premium

### 🔊 Canto de balotas por voz
La app del anfitrión dice en voz alta cada balota ("B... doce"). Se puede hacer con audios grabados (más natural) o con la voz del sistema. Opcional: que también suene en el celular de cada jugador.

### 📺 Modo presentación
Una ventana a pantalla completa para conectar a un televisor o video beam: balota actual en grande, tablero de las 75, modo de juego y código QR para unirse. El panel de control queda en otra ventana.

### 🎨 Marca del evento
Logo, nombre del evento y color principal, visibles en la pantalla de los jugadores y en el modo presentación. Ideal para empresas y fundaciones.

### 🃏 Varios cartones por jugador — *construido, bloqueado*
El anfitrión elige en "Opciones de la sala" cuántos cartones recibe cada jugador (1 a 4), solo entre rondas. El jugador cambia de cartón con las etiquetas `#ID` encima del cartón o deslizando. Canta BINGO una sola vez: el servidor revisa todos sus cartones. Si varios cartones ganan a la vez, gana el de ID más bajo.

### 📊 Historial de rondas — *construido, bloqueado*
Botón "Historial de rondas" en el panel del anfitrión: cada ronda terminada con su número, modo, ganador (o "Sin ganador" si se finalizó a mano), cantidad de balotas y hora. "Exportar a Excel (CSV)" guarda el archivo en Descargas, listo para abrir en Excel en español. Exportar a PDF queda para después.

### 🗓️ Rondas programadas
Preparar antes del evento la secuencia de rondas ("1: Forma X, 2: Forma L, 3: Cartón lleno") para avanzar con un clic.

### 👥 Coanfitrión
Un segundo anfitrión (también en computadora) que puede cantar balotas y validar, por si el principal se desconecta.

---

## 4. Modelo de precios (a validar con clientes)

Valores de referencia para empezar la conversación, no definitivos:

| Plan | Precio sugerido | Para quién |
| :--- | :--- | :--- |
| **Evento** | 15.000 – 25.000 COP por 24 horas | Una fiesta, bazar o novena puntual |
| **Mensual** | 20.000 – 35.000 COP al mes | Quien organiza bingos seguido |
| **Anual** | 2 meses gratis frente al mensual | Colegios, iglesias, empresas |

Costos a cubrir: plan pago de Render (~USD 7 al mes por servicio, para que no se duerma), base de datos, comisión de la pasarela (~3% + valor fijo por transacción), impuestos y el dominio.

---

## 5. Qué hay que construir

Hoy NexoBingo no tiene cuentas ni guarda nada en el servidor. Premium necesita:

1. **Cuentas de anfitrión.** Inicio de sesión con correo o Google. Solo el anfitrión tiene cuenta; los jugadores siguen entrando sin registrarse.
2. **Base de datos.** Para cuentas, suscripciones, patrones guardados, marcas e historial. Opciones gratuitas para empezar: Supabase o Neon (PostgreSQL). La base de datos gratuita de Render no sirve: se borra a los 30 días.
3. **Pagos.** Página de pago en la web (Wompi, Mercado Pago o PayU). La pasarela avisa al servidor (webhook) cuando un pago se aprueba y el servidor activa el plan.
4. **El servidor aplica los límites.** El Broker revisa el plan del anfitrión al crear la sala y al unirse cada jugador (por ejemplo, rechaza al jugador 11 en una sala gratuita). Nunca confiar en que la app respete los límites por su cuenta.
5. **Servidor siempre encendido.** Pasar Render a un plan pago antes de cobrar: un cliente que pagó no puede esperar un minuto a que el servidor despierte.
6. **Persistencia de salas.** Que una sala premium sobreviva a un reinicio del servidor.
7. **Documentos legales.** Términos y condiciones, política de privacidad y política de reembolsos, visibles en la app y en la web.

---

## 6. Fases de implementación (si se aprueba)

### Fase 0 — Validar (sin código)
- Hablar con 5 a 10 posibles clientes.
- Consultar con un abogado y resolver la facturación.
- Definir precios.

### Fase 1 — Base
- Cuentas de anfitrión e inicio de sesión en la app de escritorio.
- Base de datos.
- Límites del plan gratuito aplicados en el servidor.
- Render en plan pago.

### Fase 2 — Primeras funciones premium (las más pedidas por los clientes en la Fase 0)
- Ya construidas y bloqueadas: varios cartones, historial exportable y salas de hasta 200 jugadores.
- Probables siguientes: canto por voz, modo presentación.
- Al pasar a cuentas, el permiso premium deja de ser la variable global `NEXOBINGO_PREMIUM` y pasa a depender del plan del anfitrión (`Game(premium: ...)` por sala).

### Fase 3 — Pagos
- Página de planes y pago en la web.
- Webhook de la pasarela y activación automática del plan.
- Facturación electrónica.

### Fase 4 — Resto de funciones
- Marca del evento, historial y reportes, varios cartones, rondas programadas, coanfitrión.

### Fase 5 — Lanzamiento
- Notas de versión (plantilla de nuevas funciones o de cambio mayor).
- Publicar en el portafolio y, si aplica, en Google Play.

---

## 7. Cómo saber si funciona

- Cuántos anfitriones crean salas cada mes (gratis y premium).
- Cuántos pasan de gratis a premium.
- Cuántos premium renuevan al mes siguiente.
- Funciones premium más usadas.
- Costos mensuales frente a ingresos.

---

## 8. Riesgos

- **Que se use para apostar.** Los términos deben prohibir usar NexoBingo para juegos con apuesta de dinero sin autorización, y dejar claro que la responsabilidad es del organizador.
- **Pocos clientes dispuestos a pagar:** por eso primero se valida en la Fase 0.
- **Costos fijos sin ingresos:** el plan pago de Render y la base de datos cuestan aunque nadie compre. Activarlos solo cuando haya clientes confirmados.
- **Soporte:** un cliente que paga espera respuesta si algo falla en pleno evento. Definir un canal de soporte (por ejemplo, WhatsApp) antes de lanzar.
