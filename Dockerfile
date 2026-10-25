# Imagen del Broker de NexoBingo para Render (o cualquier hosting con Docker).
# Una sola imagen sirve el WebSocket del juego (/ws) y la versión web de la
# app, así jugadores web y Broker comparten dirección y no hay que
# configurar nada en la web.

# --- 1. Compilar la web de Flutter y el servidor en Dart ---
FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /src
COPY . .
RUN flutter config --no-analytics >/dev/null \
 && flutter pub get \
 && cd app && flutter build web --release \
 && cd ../server && dart compile exe bin/server.dart -o /out/server \
 && cp -r /src/app/build/web /out/web

# --- 2. Imagen final, liviana: solo el ejecutable y los archivos web ---
FROM debian:bookworm-slim
COPY --from=build /out /app
# Render indica el puerto con la variable PORT (el servidor la lee sola).
ENV PORT=8080
EXPOSE 8080
CMD ["/app/server", "--web-root", "/app/web"]
