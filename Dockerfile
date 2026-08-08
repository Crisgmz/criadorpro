# Criador Pro — imagen de la build web, para Coolify.
#
# Ojo con qué es esto: el producto es una app móvil de iOS y Android, y esta
# imagen sirve **solo** la versión web, útil para revisar pantallas y enseñar
# el producto. Las compras dentro de la app no funcionan en el navegador
# (`RF-CTA`), y el comportamiento sin conexión que exige `RNF-01`..`RNF-06` solo
# se mide de verdad en un teléfono. No confundir este despliegue con una
# entrega del producto.

# --- Construcción -----------------------------------------------------------

# El SDK se instala desde el archivo oficial en lugar de usar una imagen de
# Flutter ya hecha: las que hay publicadas van por detrás del canal estable y
# hoy traen Dart 3.12.0, que no cumple el `sdk: ^3.12.2` del pubspec. Fijando
# la versión, el despliegue compila con **exactamente** el mismo SDK con el que
# se probó, que es lo que evita el «en mi máquina funciona».
#
# Flutter solo publica archivo de Linux para x64, de ahí el `--platform`. En un
# servidor ARM habría que construir con emulación o volver a una imagen
# multiarquitectura.
FROM --platform=linux/amd64 debian:bookworm-slim AS build

# `git` no es opcional: Flutter lo usa para resolver su propia versión y falla
# al arrancar sin él. `xz-utils` descomprime el archivo del SDK.
RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl git unzip xz-utils \
 && rm -rf /var/lib/apt/lists/*

ARG FLUTTER_VERSION=3.44.8
ENV FLUTTER_HOME=/opt/flutter
ENV PATH="${FLUTTER_HOME}/bin:${FLUTTER_HOME}/bin/cache/dart-sdk/bin:${PATH}"

RUN curl -fsSL -o /tmp/flutter.tar.xz \
      "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
 && tar -xJf /tmp/flutter.tar.xz -C /opt \
 && rm /tmp/flutter.tar.xz \
 # El SDK queda con otro propietario que el usuario que construye; sin esto,
 # git se niega a leerlo y Flutter no arranca.
 && git config --global --add safe.directory "${FLUTTER_HOME}" \
 # Solo los artefactos de web: precargar Android e iOS aquí sería descargar
 # cientos de megas que esta imagen no usa.
 && flutter precache --web --no-android --no-ios

WORKDIR /app

# La clave publicable es pública por diseño — lo que protege los datos es la
# RLS (`RS-13`), no el secreto de la clave. Aun así entra como argumento y no
# escrita en el repositorio, para poder apuntar a otro proyecto de Supabase sin
# tocar el código.
ARG SUPABASE_URL=""
ARG SUPABASE_ANON_KEY=""

# Las dependencias primero y en su propia capa: mientras el `pubspec` no
# cambie, Docker se salta la descarga entera en cada despliegue.
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# `*.g.dart` y `lib/l10n/generated/` no se versionan (ver .gitignore), así que
# aquí no existen todavía: hay que generarlos o la compilación no encuentra ni
# las tablas de Drift ni las traducciones.
RUN dart run build_runner build --delete-conflicting-outputs \
 && flutter gen-l10n

# `--no-web-resources-cdn` empaqueta CanvasKit en la propia imagen en lugar de
# traerlo de gstatic al arrancar: en un servidor propio no tiene sentido que
# cada visita dependa de una CDN de terceros.
RUN flutter build web --release \
      --no-web-resources-cdn \
      --dart-define=SUPABASE_URL="$SUPABASE_URL" \
      --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"

# --- Servicio ---------------------------------------------------------------

FROM nginx:1.29-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

# Coolify espera el contenedor sano antes de mandarle tráfico; sin esto, un
# despliegue roto se anuncia como bueno.
#
# `127.0.0.1` y no `localhost`: dentro del contenedor, `localhost` resuelve
# primero a `::1`, nginx solo escucha en IPv4 y la comprobación termina en
# «connection refused». El contenedor sirve páginas perfectamente y aun así se
# declara enfermo, que es la peor combinación posible.
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --spider -q http://127.0.0.1/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
