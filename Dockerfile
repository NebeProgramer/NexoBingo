# Imagen del Broker de NexoBingo para Render (o cualquier hosting con Docker).
# Una sola imagen sirve el WebSocket del juego (/ws) y la versión web de la
# app, así jugadores web y Broker comparten dirección y no hay que
# configurar nada en la web.

# --- 1. Compilar la versión web de Flutter ---
FROM ghcr.io/cirruslabs/flutter:stable AS web
WORKDIR /src
COPY . .
RUN flutter config --no-analytics >/dev/null \
 && flutter pub get \
 && cd app && flutter build web --release

# --- 2. Compilar el servidor con la imagen oficial de Dart ---
# El workspace de la raíz incluye la app Flutter, que esta imagen no puede
# resolver; por eso aquí server y bingo_core se resuelven como paquetes
# sueltos (bingo_core por ruta local).
FROM dart:stable AS server
WORKDIR /src
COPY packages/bingo_core packages/bingo_core
COPY server server
RUN sed -i '/^resolution: workspace/d' packages/bingo_core/pubspec.yaml server/pubspec.yaml \
 && printf '\ndependency_overrides:\n  bingo_core:\n    path: ../packages/bingo_core\n' >> server/pubspec.yaml \
 && cd server && dart pub get \
 && mkdir -p /out && dart compile exe bin/server.dart -o /out/server

# --- 3. Imagen final mínima ---
# /runtime/ trae solo las librerías del sistema que necesita un ejecutable
# compilado por Dart (patrón oficial de la imagen dart).
FROM scratch
COPY --from=server /runtime/ /
COPY --from=server /out/server /app/server
COPY --from=web /src/app/build/web /app/web
# Render indica el puerto con la variable PORT (el servidor la lee sola).
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server", "--web-root", "/app/web"]
