# Checklist — NexoBingo

Tareas pendientes para que NexoBingo siga su curso. Marca cada casilla al terminarla. Los detalles de cómo hacer cada cosa están en [execute_instructions.md](execute_instructions.md).

---

## 📦 Release 2.0.0

- [ ] Reemplazar el enlace del café (`_coffeeUrl` en `app/lib/services/extras.dart`) por el enlace real.
- [ ] Revisar el enlace de descarga (`_downloadUrl` en el mismo archivo) y corregirlo en el portafolio si hace falta.
- [ ] Compilar `NexoBingo.apk` final: `BROKER_URL` de producción, **sin** `DEV_MODE`.
- [ ] Reinstalar el APK final en el celular (el actual muestra el campo de servidor).
- [ ] Compilar `NexoBingo-Windows.zip` final y comprobar que abre en una PC distinta a la de desarrollo.
- [ ] Prueba completa con varias personas reales: anfitrión en PC, un jugador en la app Android y otro en la web desde un celular.
  - [ ] Crear sala y compartir el enlace web con el código.
  - [ ] Probar cada modo de juego, incluido Personalizado.
  - [ ] BINGO falso (la partida sigue) y BINGO válido (cierra la ronda).
  - [ ] Bloquear el celular un minuto y volver (debe reconectar con el mismo cartón).
  - [ ] Finalizar partida y jugar una segunda ronda.
  - [ ] Entrar con el servidor dormido (debe mostrar "Despertando el servidor...").
- [ ] Decidir si `docs/release-notes/2.0.0.md` va en el repositorio (hoy está en `.gitignore`).
- [ ] Crear la release `2.0.0` en GitHub (tag sin "v") con las notas y los dos archivos.
- [ ] Actualizar la página de descarga del portafolio para la 2.0.0.
- [ ] Borrar la rama `Android` del repositorio de GitHub si ya no sirve.

---

## 🆕 Próxima versión (2.1.0)

Lo que ya está en el código y falta publicar.

- [ ] Hacer commit y push: Render redespliega el servidor con las funciones nuevas. **Primero el servidor**: una app nueva contra el servidor viejo muestra "Tipo de mensaje desconocido" al cambiar opciones.
- [ ] Verificar en Render que `/healthz` responde y que el log dice "Funciones premium: desactivadas".
- [ ] Recompilar e instalar el APK y la app de Windows.
- [ ] Prueba real con varias personas:
  - [ ] AutoSelector encendido y apagado; el anfitrión lo prohíbe en plena ronda.
  - [ ] Trofeos: alguien gana dos rondas y su trofeo muestra "2" en la lista del anfitrión y en la de los jugadores.
  - [ ] El jugador número 11 no puede entrar.
  - [ ] Las funciones con candado muestran el aviso "Función premium".
- [x] Logo nuevo (rejilla "N") con versión monocromática; íconos regenerados para todas las plataformas.
- [ ] Notas de versión `docs/release-notes/2.1.0.md` (plantilla de nuevas funciones).
- [ ] Subir la versión a `2.1.0` en `app/pubspec.yaml` y `server/pubspec.yaml`.

---

## 🛠️ Deuda técnica

- [ ] **Salas en memoria:** se pierden con cada redeploy o cuando Render se duerme. Evaluar guardarlas en una base de datos o al menos avisar a los jugadores antes de un redeploy.
- [ ] **Render gratuito se duerme:** confirmar si una partida larga sin mensajes lo mantiene despierto. Si no, agregar un mensaje periódico desde la app durante la partida.
- [ ] Pasar `package_info_plus` a 10.x cuando la configuración de Gradle de Flutter lo soporte (hoy rompe el build de Android).
- [ ] Quitar el aviso de fuentes de `cupertino_icons` del build web (no se usa).
- [ ] Probar y, si funciona, activar el build web con `--wasm` (más rápido en navegadores compatibles).
- [ ] Mover el proyecto fuera de OneDrive, o excluir `app/build` de la sincronización, para acabar con los bloqueos al compilar.
- [x] Límite de jugadores por sala en el servidor: 10 gratis (200 con premium).
- [ ] Límite de salas abiertas a la vez en el servidor (protege el plan gratuito de abusos).
- [ ] Limitar la frecuencia de mensajes por conexión (evitar que un cliente sature el servidor).
- [ ] Agregar `docs/release-notes/BUGS.md` y las plantillas, igual que en Vertex, para registrar bugs con ID.

---

## 🚀 Funciones del roadmap

- [ ] Canto de balotas por voz en el panel del anfitrión (letra + número).
- [x] Trofeos de ganadores dentro de la sala (gratis).
- [x] Historial de rondas exportable a CSV (premium, construido y bloqueado).
- [x] AutoSelector: marcado automático, con interruptor del anfitrión (gratis).
- [x] Varios cartones por jugador (premium, construido y bloqueado).
- [x] Mostrar el nombre del ganador, no solo el número de cartón, en el aviso de victoria.
- [ ] Código QR de la sala en el panel del anfitrión para que los jugadores escaneen el enlace web.
- [ ] Opción para que el anfitrión expulse a un jugador.
- [ ] Probar y publicar en iOS y macOS (requiere Mac).
- [ ] Publicar en Google Play (requiere cuenta de desarrollador, pago único de USD 25).

---

## 💼 Decisión premium

Antes de escribir código de pago. El detalle está en [funciones_premium.md](funciones_premium.md).

- [ ] Hablar con algunos posibles clientes (colegios, iglesias, empresas, organizadores de eventos) y preguntarles cuánto pagarían y qué funciones les importan.
- [ ] Consultar con un abogado:
  - [ ] Que el modelo de pago por herramienta no cuenta como operar juegos de azar.
  - [ ] Términos y condiciones, y política de privacidad (Ley 1581 de 2012, datos personales).
  - [ ] Cómo facturar (RUT, régimen simple, facturación electrónica de la DIAN).
- [ ] Elegir modelo: suscripción mensual, pago por evento, o ambos.
- [ ] Fijar precios en COP.
- [ ] Elegir pasarela de pago (Wompi, Mercado Pago o PayU) y abrir la cuenta.
- [ ] Decidir: ¿se lanza premium? Sí / No. Si es sí, seguir las fases de `funciones_premium.md`.

---

## ✅ Antes de cada release

- [ ] `dart test` en `packages/bingo_core` y `server`, y `flutter test` en `app`: todo en verde.
- [ ] `dart analyze` / `flutter analyze` sin problemas.
- [ ] Prueba de punta a punta contra Render.
- [ ] Versión actualizada en `app/pubspec.yaml` y `server/pubspec.yaml`.
- [ ] Notas de la versión escritas con la plantilla correcta.
- [ ] Artefactos compilados sin `DEV_MODE` y con `BROKER_URL` de producción.
- [ ] Release creada en GitHub con tag `X.Y.Z`.
