# ---- Stage 1: build Flutter web ----
FROM ghcr.io/cirruslabs/flutter:3.24.5 AS build
WORKDIR /app
COPY . .
RUN flutter config --enable-web \
 && flutter pub get \
 && flutter build web --release

# ---- Stage 2: serve with nginx (Render injects $PORT) ----
FROM nginx:alpine
ENV PORT=10000
COPY nginx.conf.template /etc/nginx/templates/default.conf.template
COPY --from=build /app/build/web /usr/share/nginx/html
EXPOSE 10000
