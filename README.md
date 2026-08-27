# Criador Pro

Gestión profesional de cría y genealogía avícola. Offline-first: la app funciona
entera sin conexión y sincroniza cuando vuelve la red.

La arquitectura, las convenciones de producto y las reglas de código están en
[CLAUDE.md](CLAUDE.md).

## Puesta en marcha

```bash
flutter pub get
dart run build_runner build          # genera el código de Drift (*.g.dart)
flutter gen-l10n                     # genera las traducciones
```

Ninguno de los dos generados se versiona, así que hay que ejecutarlos tras
clonar el repo y cada vez que cambien las tablas o los `.arb`.

---

## Conectar con Supabase

Cinco pasos. Los cuatro primeros son de una sola vez.

### 1. Ejecuta las migraciones

En el SQL Editor de tu proyecto, **en este orden**. Todas son idempotentes: se
pueden volver a ejecutar sin romper nada, así que ante la duda, ejecútalas.

| # | Archivo | Qué añade |
|---|---|---|
| 1 | [`20260801000000_init.sql`](supabase/migrations/20260801000000_init.sql) | `profiles`, `birds`, `clutches` con RLS por `owner_id`, los triggers de `updated_at` y `delete_current_user()`, que exige App Store |
| 2 | [`20260803000000_profiles_alignment.sql`](supabase/migrations/20260803000000_profiles_alignment.sql) | `farm_name`, `location`, `country_code`, `locale`, `next_plate`, `avatar_url`, y que `handle_new_user()` guarde lo que manda el alta. Sin esto el nombre y el teléfono se pierden |
| 3 | [`20260805000000_plate_rpc.sql`](supabase/migrations/20260805000000_plate_rpc.sql) | `next_plate()` y `active_bird_count()` — `RS-01` y `RS-02` |
| 4 | [`20260806000000_birds_plate.sql`](supabase/migrations/20260806000000_birds_plate.sql) | La placa deja de ser texto opcional y pasa a entero obligatorio. Es el cambio del que cuelga todo el registro |
| 5 | [`20260815000000_evaluations.sql`](supabase/migrations/20260815000000_evaluations.sql) | `evaluations` — pruebas de campo (`RF-PRU`) |
| 6 | [`20260815010000_transactions.sql`](supabase/migrations/20260815010000_transactions.sql) | `transactions` — contabilidad (`RF-CON`) |
| 7 | [`20260816000000_bird_markings.sql`](supabase/migrations/20260816000000_bird_markings.sql) | `birth_mark`, `wing_band_left`, `wing_band_right` y `comb` en `birds` |
| 8 | [`20260826000000_payroll.sql`](supabase/migrations/20260826000000_payroll.sql) | `employees` y `payroll_payments` — empleomanía (`RF-NOM`) |
| 9 | [`20260827000000_bird_photos.sql`](supabase/migrations/20260827000000_bird_photos.sql) | El bucket privado `bird-photos` y sus políticas — `RF-REG-15` |

#### Cuáles te faltan

La app funciona igual sin las últimas: Drift crea las tablas en local y todo se
guarda. Lo que falla es la **sincronización** de esos módulos, y falla en
silencio —la operación se queda en la cola reintentando—, así que conviene
comprobarlo en vez de suponerlo.

Esta consulta lo dice de un vistazo:

```sql
select 'evaluations'      as modulo, to_regclass('public.evaluations')      is not null as listo
union all select 'transactions',     to_regclass('public.transactions')     is not null
union all select 'employees',        to_regclass('public.employees')        is not null
union all select 'payroll_payments', to_regclass('public.payroll_payments') is not null
union all select 'birds.comb',       exists (
  select 1 from information_schema.columns
  where table_schema = 'public' and table_name = 'birds' and column_name = 'comb'
)
union all select 'bucket bird-photos', exists (
  select 1 from storage.buckets where id = 'bird-photos'
);
```

Cada `false` es la migración de esa fila: 5, 6, 8, 8, 7 y 9 respectivamente.

### 2. Cambia las plantillas de correo

**Authentication → Emails.** La app pide un código de seis dígitos
(`RF-AUT-06`), no un enlace: las pantallas 5 y 8 son seis casillas. Hay que
sustituir el cuerpo de dos plantillas por el de [supabase/templates/](supabase/templates/),
que usan `{{ .Token }}` en lugar de `{{ .ConfirmationURL }}`.

| Plantilla | Archivo | Asunto |
|---|---|---|
| Confirm sign up | [confirm_signup.html](supabase/templates/confirm_signup.html) | `Tu código de verificación — Criador Pro` |
| Reset password | [reset_password.html](supabase/templates/reset_password.html) | `Recupera tu contraseña — Criador Pro` |

Pega el HTML tal cual, sin envolverlo ni añadirle comentarios: el editor guarda
el cuerpo literal y un comentario `<!-- -->` al principio puede impedir que el
botón *Save changes* surta efecto. Recarga la página después de guardar para
comprobar que persistió.

> **Para publicar hace falta SMTP propio.** El correo integrado de Supabase
> envía desde `noreply@mail.app.supabase.io` y tiene un límite de unos pocos
> mensajes por hora — suficiente para desarrollar, no para producción, y no
> permite remitente propio.
>
> **Authentication → Emails → SMTP Settings.** Con Resend (3.000 correos al mes
> gratis) los valores son `smtp.resend.com`, puerto `465`, usuario `resend` y la
> API key `re_…` como contraseña. Sin dominio verificado, Resend solo entrega a
> la dirección con la que te registraste.

### 3. Ajusta el código de verificación

**Authentication → Sign In / Providers → Email:**

| Ajuste | Valor | Por qué |
|---|---|---|
| Confirm email | activado | Sin esto no se envía código y la pantalla 5 sobra |
| Email OTP Length | **6** | `RV-04`. Supabase genera 8 por omisión y la pantalla tiene seis casillas: con 8, el código llega cortado y la verificación falla siempre |
| Email OTP Expiration | **600** | `RV-04`: diez minutos |

**Authentication → Rate Limits** → *Rate limit for sending emails*: el valor por
omisión del correo integrado se agota en cuatro pruebas seguidas y devuelve
`over_email_send_rate_limit`, que la app muestra como «Demasiados intentos»
(`E-AUTH-03`). Súbelo mientras desarrollas; antes de publicar, cíñelo a
`RNF-18` (3 envíos de código por hora).

### 4. Pon tus credenciales

```bash
cp env.example.json env.json
```

Rellena `env.json` con la URL y la clave publicable de **Project Settings →
API**. El archivo está en `.gitignore` y nunca se comitea; no escribas las
claves en `.vscode/launch.json`, que sí se versiona.

La clave publicable es pública por diseño — lo que protege los datos es la RLS,
no el secreto de la clave.

### 5. Ejecuta

```bash
flutter run --dart-define-from-file=env.json
```

En VS Code no hace falta acordarse del flag: [.vscode/settings.json](.vscode/settings.json)
lo añade a toda ejecución con `dart.flutterRunAdditionalArgs`. Tras clonar hay
que recargar la ventana una vez para que el ajuste se aplique.

> **El flag no es opcional.** Si `env.json` no existe, el comando falla con
> *«Did not find the file passed to --dart-define-from-file»* y la app no
> arranca. Es deliberado: olvidarlo antes producía un fallo silencioso —la app
> abría en modo local y parecía rota sin decir por qué—. Para trabajar sin
> backend a propósito, comenta la línea de `settings.json`.

**Al compilar para publicar**, el ajuste de VS Code no interviene y el flag hay
que pasarlo a mano:

```bash
flutter build ipa --dart-define-from-file=env.json
flutter build appbundle --dart-define-from-file=env.json
```

Compilar desde Xcode o Android Studio directamente tampoco lo aplica.

### Comprobar que quedó bien

Crea una cuenta desde la app y revisa en el **Table Editor → profiles** que la
fila nueva trae `full_name`, `phone`, `country_code` y `locale` con lo que
escribiste, `next_plate = 1` y `plan = 'free'`.

Si el registro falla con *«Database error saving new user»*, el trigger
`handle_new_user()` está reventando: míralo en **Logs → Postgres**.

---

## Comprobaciones

```bash
flutter analyze
# Solo el código escrito a mano: los generados no siguen esta convención.
find lib test -name '*.dart' ! -name '*.g.dart' -not -path '*/generated/*' \
  -print0 | xargs -0 dart format --set-exit-if-changed
flutter test
```

## Ejecutar en Chrome

Web no es plataforma objetivo —el producto es iOS y Android—, pero es la forma
más rápida de revisar una pantalla.

```bash
flutter run -d chrome --dart-define-from-file=env.json
```

Drift necesita allí dos binarios que se sirven desde `web/` y **están
versionados**: `sqlite3.wasm` (el motor SQLite compilado) y `drift_worker.js`
(el worker que lo ejecuta fuera del hilo de la interfaz). Sin ellos la app
arranca y muere con *«When compiling to the web, the `web` parameter needs to
be set»*.

Sus versiones van atadas a las de `sqlite3` y `drift` en `pubspec.lock`. Al
subir cualquiera de los dos paquetes, vuelve a descargarlos con la versión que
corresponda:

```bash
# Las versiones exactas salen del lockfile:
awk '/^  drift:/{f=1} f&&/version:/{print $2; f=0}' pubspec.lock
awk '/^  sqlite3:/{f=1} f&&/version:/{print $2; f=0}' pubspec.lock

curl -L -o web/drift_worker.js \
  https://github.com/simolus3/drift/releases/download/drift-<versión>/drift_worker.js
curl -L -o web/sqlite3.wasm \
  https://github.com/simolus3/sqlite3.dart/releases/download/sqlite3-<versión>/sqlite3.wasm
```

Ojo: la etiqueta de `sqlite3.wasm` es la del **paquete `sqlite3`**, que no
coincide con la del binario publicado; si el enlace da 404, mira las
[releases de sqlite3.dart](https://github.com/simolus3/sqlite3.dart/releases)
y toma la más cercana.

## Desplegar en Coolify

Lo que se despliega es **la versión web**, útil para revisar pantallas y
enseñar el producto. No es una entrega: las compras dentro de la app no
funcionan en el navegador (`RF-CTA`) y el comportamiento sin conexión que
exigen `RNF-01`–`RNF-06` solo se mide en un teléfono.

### Configuración del recurso

1. **New Resource → Application → Public/Private Repository**, apuntando a este
   repositorio y a la rama `main`.
2. **Build Pack: `Dockerfile`.** No Nixpacks: no sabe generar los `*.g.dart` de
   Drift ni las traducciones, que no están versionados.
3. **Port Exposes: `80`.**
4. En **Environment Variables**, añade las dos y marca **Build Variable** en
   ambas. Sin esa marca llegan al contenedor en ejecución, que es demasiado
   tarde: `String.fromEnvironment` se resuelve al **compilar**, y la app
   arrancaría en modo solo local.

   | Variable | Valor |
   |---|---|
   | `SUPABASE_URL` | `https://<tu-proyecto>.supabase.co` |
   | `SUPABASE_ANON_KEY` | `sb_publishable_...` |

   La clave publicable es pública por diseño: viaja dentro del bundle y
   cualquiera puede leerla. Lo que protege los datos es la RLS (`RS-13`), no el
   secreto de la clave. **Nunca** pongas aquí la `service_role`.
5. Añade el dominio del despliegue a **Supabase → Authentication → URL
   Configuration → Redirect URLs**, o la verificación por correo rebotará.

### Detalles que ya están resueltos

- **SDK fijado** a la misma versión que usa el equipo (`FLUTTER_VERSION` en el
  Dockerfile). Al subir Flutter en local, súbelo también ahí y en CI.
- **`try_files` a `index.html`**: go_router usa rutas reales, así que sin eso
  recargar en `/birds/…` daría un 404 del servidor.
- **CanvasKit empaquetado** (`--no-web-resources-cdn`): el despliegue no
  depende de una CDN de terceros.
- **Sin COOP/COEP**: darían a Drift el almacenamiento más rápido, pero aislar
  el origen bloquea las respuestas de Supabase. El motivo está en `nginx.conf`.

### Comprobar un despliegue

```bash
curl -sI https://<dominio>/                       # 200
curl -s -o /dev/null -w '%{http_code}\n' https://<dominio>/birds/1/pedigree   # 200, no 404
curl -s -o /dev/null -w '%{content_type}\n' https://<dominio>/sqlite3.wasm    # application/wasm
```

Si `sqlite3.wasm` sale como `application/octet-stream`, la base local no
arranca y la app queda sin datos.
# criadorpro
