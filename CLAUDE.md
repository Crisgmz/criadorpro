# Criador Pro — guía del proyecto

App móvil (iOS/Android) de gestión de cría, genealogía y administración para
criaderos avícolas. **Offline-first**: funciona entera dentro del galpón sin
señal y sincroniza cuando vuelve la red.

> **Tesis del producto.** El criador no quiere una app. Quiere no perder su
> libro. Todo lo que construyamos debe ser más rápido que escribir a mano — o no
> lo usará.

Mercado inicial: República Dominicana. Idioma origen: español (el inglés es
traducción). Precio: Gratis / Pro US$4,99 / Élite US$19,99 al mes, cobrado
exclusivamente por compra dentro de la app.

---

## 1. Documentación fuente

La especificación completa vive en [Documentación de Requisitos de Software/](Documentación%20de%20Requisitos%20de%20Software/).

> **Esa carpeta no está en el repositorio.** Son 32 MB de PDF y el BRD incluye
> objetivos comerciales y precios; el repositorio es público. Pídesela a quien
> lleve el proyecto y déjala en esa misma ruta: los enlaces de este documento
> la asumen ahí. Sin ella el código compila igual, pero se pierde la autoridad
> que resuelve las dudas de alcance.
Cinco PDFs, cada uno con una autoridad distinta. **Cuando haya duda, gana el
documento más específico**; cuando este CLAUDE.md contradiga a un PDF, gana
el PDF y hay que corregir este archivo.

| Documento | Decide | Identificadores |
|---|---|---|
| [BRD](Documentación%20de%20Requisitos%20de%20Software/CriadorPRO%20BRD.pdf) | Por qué existe el proyecto, objetivos comerciales, riesgos | `ON-1..7` |
| [PRD](Documentación%20de%20Requisitos%20de%20Software/CriadorPRO%20PRD.pdf) | Qué se construye, las 41 pantallas, sistema de diseño, fases | pantallas `1..41` |
| [FRD](Documentación%20de%20Requisitos%20de%20Software/CriadorPRO%20FRD.pdf) | Comportamiento verificable por módulo, casos de uso | `RF-*` |
| [SRS](Documentación%20de%20Requisitos%20de%20Software/CriadorPRO%20SRS.pdf) | Tipos, formatos, validaciones, umbrales, errores | `RV-*` `RS-*` `RNF-*` `E-*` |
| [DDT/TDD](Documentación%20de%20Requisitos%20de%20Software/CriadorPRO%20DDT.pdf) | Cómo se implementa: capas, esquema, algoritmos | — |

Los PDFs tienen el cuerpo del texto rasterizado: `pdftotext` solo extrae los
bloques de código. Para leer la prosa hay que abrirlos como imagen.

Al implementar cualquier cosa, **cita el identificador** en el comentario o el
mensaje de commit (`// RS-04: todo o nada`). Es lo que hace auditable la
trazabilidad requisito → código → prueba.

---

## 2. Reglas innegociables

Estas cuatro no se renegocian en ninguna iteración. Romper cualquiera es un
defecto crítico, no una preferencia de estilo.

### 2.1 Terminología zootécnica — riesgo existencial

**Queda prohibido cualquier vocabulario de combate, riña o apuesta** en la
interfaz, los `.arb`, los mensajes de error, las notificaciones, los metadatos,
las capturas y la ficha de tienda. Es condición de admisión en App Store y
Google Play, y el rechazo por esta causa es el riesgo de mayor prioridad del
proyecto (BRD §8).

Vocabulario correcto: «prueba de campo», «evaluación», «favorable»,
«desfavorable», «condición», «solicitud de encuentro», «ejemplar», «criadero».

Términos a erradicar si aparecen (el prototipo aún arrastra algunos): «traba»,
«gallo» como rótulo de sexo, y cualquier derivado de pelea o apuesta. La
compuerta de compilación revisa los `.arb` y los metadatos contra la lista de
términos prohibidos antes de cada envío; si aparece uno, la compilación falla.

### 2.2 Offline-first

La red **nunca** está en el camino crítico de una acción del usuario. Toda
lectura y escritura se resuelve contra Drift (SQLite local); la sincronización
es diferida y en segundo plano (`RF-SIN-01`). Las únicas funciones que pueden
exigir conexión son autenticación, Comunidad y compras (`RNF-08`).

### 2.3 Nada se borra por dejar de pagar

Degradar de plan conserva todos los registros en modo lectura y solo bloquea la
creación de nuevos (`RS-03`, `RF-CTA-07`). Al alcanzar el límite se bloquea
crear, nunca consultar ni exportar (`RF-REG-16`).

### 2.4 Aislamiento por criadero en la base de datos

El aislamiento entre cuentas se impone con RLS en Postgres
(`owner_id = auth.uid()`), no en la aplicación (`RS-13`, `RNF-16`). Ninguna
consulta puede devolver filas de otro propietario aunque el cliente esté mal
escrito.

---

## 3. Arquitectura

Cuatro capas con dependencia estrictamente descendente. MVVM con
`ChangeNotifier`; Riverpod **solo compone dependencias**, no guarda el estado de
pantalla.

```
Vista (Widget)             observa    →  ViewModel (ChangeNotifier)
ViewModel                  invoca     →  Repositorio
Repositorio                escribe    →  Drift (SQLite local)  ── fuente de verdad
Repositorio                encola     →  sync_queue
SyncService (background)   drena      →  Supabase (Postgres + Storage)
Supabase                   responde   →  Repositorio → Drift → stream → ViewModel → Vista
```

| Capa | Responsabilidad | Prohibido |
|---|---|---|
| Vista | Construir widgets desde el estado del ViewModel y despachar intenciones | Lógica de negocio, acceso a repositorios, formatear datos crudos |
| ViewModel | Estado de una pantalla, orquestar repositorios, exponer estado listo para pintar | Importar `material.dart`, navegar, mostrar diálogos |
| Repositorio | Leer/escribir en Drift, encolar sincronización, aplicar reglas de datos y límites de plan | Lanzar excepciones hacia arriba — devuelve `Result<T>` |
| Modelo | Estructuras inmutables y su conversión desde/hacia la base | Cualquier dependencia de framework |

Contratos base: `Result<T>` sellado (`Ok` / `Err`) en [lib/core/utils/result.dart](lib/core/utils/result.dart)
y `BaseViewModel` con `ViewState { idle, busy, empty, error }` en
[lib/core/base/base_viewmodel.dart](lib/core/base/base_viewmodel.dart).
**Ninguna excepción cruza la frontera del repositorio**: se captura, se traduce
a `Failure` y se registra.

Las guardias de navegación se resuelven **solo** en el `redirect` de go_router
([lib/core/router/app_router.dart](lib/core/router/app_router.dart)). Ningún
ViewModel navega.

Un feature nunca importa de otro feature: lo compartido sube a `core/`.

### Estructura

El DDT sitúa el código en `flutter/`; en este repositorio vive en la raíz.

```
lib/
├── main.dart                  entrada, carga de entorno
├── app.dart                   MaterialApp.router, tema, localización
├── core/
│   ├── base/                  BaseViewModel, ViewState
│   ├── config/                entorno, constantes, límites de plan
│   ├── db/                    AppDatabase (Drift), tables/, daos/
│   ├── error/                 Failure y mapeo de errores
│   ├── network/               SupabaseService, ConnectivityService
│   ├── providers/             providers Riverpod compartidos
│   ├── router/                go_router, guardias, ShellRoute
│   ├── sync/                  SyncService, cola, política de reintento
│   ├── theme/                 colores, tipografía, espaciado
│   ├── utils/                 Result, formateadores, validadores
│   └── widgets/               botones, campos, tarjetas, estados vacíos
├── features/<feature>/
│   ├── model/                 entidades del feature
│   ├── repository/            acceso a datos del feature
│   ├── viewmodel/             un ViewModel por pantalla
│   └── view/                  pantallas y widgets propios
└── l10n/                      app_es.arb · app_en.arb
test/features/<feature>/       pruebas de ViewModel y repositorio
```

Features del alcance completo: `auth` · `onboarding` · `dashboard` · `birds` ·
`pedigree` · `evaluations` · `community` · `accounting` · `payroll` ·
`subscription` · `settings`.

### Navegación objetivo

```
/splash · /welcome · /login · /onboarding/profile
ShellRoute (barra inferior de 5 destinos):
  /home · /birds (:id, :id/pedigree) · /tests · /community · /account
Fuera del shell: /accounting · /payroll
```

Contabilidad y empleomanía **no ocupan pestaña**: son módulos administrativos
que se abren a pantalla completa desde Inicio y desde Mi cuenta. La barra
inferior está reservada a lo que el criador toca a diario.

---

## 4. Modelo de datos canónico

Toda entidad remota lleva además `owner_id` (uuid, no nulo), `created_at`,
`updated_at` (timestamptz, no nulos) e `is_deleted` (booleano, falso por
omisión). Los identificadores son **UUID v4 generados en el cliente** (`RS-14`),
para poder crear sin conexión y sin colisiones. Las tablas locales de Drift
añaden `is_dirty`.

| Tabla | Campos |
|---|---|
| `profiles` | `id` (= auth uid), `full_name`, `email`, `phone`, `farm_name`, `location`, `country_code` (def. `DO`), `locale` (`es`/`en`), **`next_plate`** (≥1, estrictamente creciente), `plan` (`free`/`pro`/`elite`), `plan_expires_at`, `avatar_url` |
| `birds` | `id`, **`plate`** (integer, ≥1, obligatorio), `name` (opcional), `sex` (`male`/`female`/`unknown`), `line`, `color`, **`birth_mark`**, **`wing_band_left`**, **`wing_band_right`**, `birth_date`, `father_id`, `mother_id`, `clutch_id`, `weight_g` (100–8000), `status` (`active`/`sold`/`deceased`/`loaned`), `photo_url`, `notes` |
| `clutches` | `father_id`, `mother_id`, `date`, `eggs` (0–30), `hatched` (1–30, ≤ `eggs`) |
| `evaluations` | `bird_id`, `date`, `place`, `result` (`favorable`/`unfavorable`/`undefined`), `condition` (1–10), **`weight_g`**, **`notes`** |
| `transactions` | `type` (`income`/`expense`), `category` (catálogo cerrado), `amount` `numeric(12,2)` >0, `date`, `description`, `bird_id`, `recurrence` (`none`/`weekly`/`biweekly`/`monthly`) |
| `employees` | `name`, `role`, `phone`, `document`, `salary`, `frequency` (`weekly`/`biweekly`/`monthly`), `is_active` |
| `payroll_payments` | `employee_id`, `period_start`, `period_end`, `base`, `bonus`, `deductions`, `net` (calculado, no editable), `method` (`cash`/`transfer`/`other`) |
| `sync_queue` | `entity`, `entity_id`, `operation`, `payload` (JSON), `attempts`, `last_error` — **solo local** |

**La placa es el eje del producto.** Es lo único obligatorio al registrar un
ejemplar; el nombre es opcional. El criador declara su placa actual en el
onboarding y la app continúa desde ahí — así migra sin retranscribir su libro.

### Índices

`birds(owner_id, plate)` · `birds(owner_id, name)` · `birds(father_id)` ·
`birds(mother_id)` · `transactions(owner_id, date)` ·
`evaluations(bird_id, date)` · `payroll_payments(employee_id, period_start)`.

### Funciones del servidor

| Función | Tipo | Comportamiento |
|---|---|---|
| `handle_new_user()` | Trigger | Crea `profiles` al alta en `auth.users`, con plan `free` y `next_plate = 1` |
| `touch_updated_at()` | Trigger | `updated_at = now()` en cada escritura — base de la resolución de conflictos |
| `next_plate(p_owner, p_count)` | RPC | Reserva atómicamente un bloque de N placas y devuelve el rango |
| `active_bird_count(p_owner)` | RPC | Conteo autoritativo para validar el límite de plan |
| `delete_account()` | Edge Function | Borrado físico en cascada, irreversible (`RNF-20`) |
| `verify_receipt()` | Edge Function | Valida el recibo de tienda y escribe `plan` / `plan_expires_at`. **El cliente nunca escribe su propio plan.** |

### Catálogos cerrados

Se almacenan como claves estables en inglés y se traducen en presentación. El
usuario no crea valores propios; añadir uno exige migración.

- **Ingresos**: venta de ejemplar · servicio de reproducción · venta de huevos · otro ingreso
- **Gastos**: alimento · medicina y vacunas · **nómina** · transporte · mantenimiento · compra de ejemplar · servicios · otro gasto
- La categoría **nómina** es de uso exclusivo del sistema: no aparece en el selector manual de gastos.

---

## 5. Reglas de negocio

| ID | Regla |
|---|---|
| `RS-01` | `next_plate` se incrementa atómicamente al crear cada ejemplar. Eliminar un ejemplar **no** libera ni reasigna su placa. |
| `RS-02` | El límite de plan se evalúa **en la capa de datos** antes de insertar, contando solo `status = active` e `is_deleted = false`. Gratis 25 · Pro 500 · Élite sin límite. |
| `RS-03` | Al degradar de plan: modo lectura para creación. Ningún registro se elimina ni se oculta jamás. |
| `RS-04` | Registrar una camada crea la camada y sus N crías en **una transacción local única**. Si falla cualquier inserción, no se crea ninguna y `next_plate` no avanza. |
| `RS-05` | Pedigrí: recorrido en amplitud, profundidad máxima 4, conjunto de visitados. Un nodo repetido corta la rama y se marca como referencia cíclica. |
| `RS-06` | Confirmar un pago de nómina crea, **en la misma transacción**, un gasto de categoría nómina por el neto. Anular el pago anula el gasto. |
| `RS-07` | Costo mensual de nómina = suma de salarios activos normalizados: semanal × 4,33 · quincenal × 2 · mensual × 1. Se rotula como estimación. |
| `RS-08` | Los movimientos recurrentes se generan al abrir la app, para los períodos vencidos desde la última generación, sin duplicar. |
| `RS-09` | Conflictos: gana el `updated_at` más reciente; en empate gana el servidor. **El usuario nunca ve el conflicto.** |
| `RS-10` | Todo borrado es lógico (`is_deleted = true`) para poder propagarse. El borrado de cuenta sí es físico y en cascada. |
| `RS-11` | Reintentos con espera exponencial 2·4·8·16·32 s, máximo 5 intentos. Agotados, la operación queda marcada y visible para reintento manual. |
| `RS-12` | El plan se determina por validación del recibo. Ante fallo se conserva el último estado conocido 72 horas antes de degradar. |
| `RS-13` | Aislamiento garantizado a nivel de base de datos, no de aplicación. |
| `RS-14` | Identificadores UUID v4 generados en el cliente. |

### Validaciones que más se olvidan

`RV-02` contraseña ≥8 con letra y número · `RV-04` código de 6 dígitos, 10 min,
5 intentos · `RV-07` placa inicial 1–999.999, nunca menor que la más alta
registrada · `RV-08` placa duplicada **advierte pero permite continuar** ·
`RV-09` nacimiento no futuro ni anterior a 20 años · `RV-10` el padre debe ser
macho, la madre hembra, y ninguno puede ser el propio ejemplar ni descendiente
suyo · `RV-11` crías 1–30 · `RV-12` peso 100–8000 g, fuera de rango advierte
pero permite guardar · `RV-15` deducciones ≤ base + bonificación
(«El neto no puede ser negativo») · `RV-17` cédula dominicana 11 dígitos con
dígito verificador — advertencia, no bloqueo · `RV-19` foto JPEG/PNG comprimida
a ≤2 MB y 1.600 px de lado mayor.

Las validaciones se disparan **al perder el foco, nunca mientras se escribe**
(`RF-AUT-05`).

### Sincronización

Escritura local primero, propagación después: el repositorio escribe en Drift y
encola la operación **en la misma transacción**, de modo que nunca existe un
cambio guardado sin su entrada en la cola ni al revés.

- **Disparo**: al recuperar conectividad, al abrir la app, tras cada escritura y cada 5 minutos en primer plano.
- **Orden**: FIFO estricto por `created_at` — las dependencias se respetan porque el padre siempre se encoló antes que el hijo.
- **Lote**: hasta 50 operaciones por ciclo.
- **Descarga**: `updated_at > last_pull_at` por entidad, incluyendo filas con `is_deleted = true` para propagar borrados.
- **Dispositivo nuevo**: descarga completa antes de habilitar la escritura (`RF-SIN-08`).
- **Fotos**: se guardan primero en el sistema de archivos local y se suben como operación independiente, para que una foto pesada no bloquee la cola de datos.

---

## 6. Módulos y prioridades

| Prefijo | Módulo | Alcance |
|---|---|---|
| `RF-AUT` | Autenticación | Registro, verificación, sesión, recuperación |
| `RF-ONB` | Configuración inicial | Perfil del criadero, numeración, elección de plan |
| `RF-REG` | Registros | Ejemplares, camadas, ficha, búsqueda |
| `RF-PED` | Genealogía | Construcción y visualización del pedigrí |
| `RF-PRU` | Pruebas de campo | Registro y estadísticas de evaluación |
| `RF-COM` | Comunidad | Solicitudes de encuentro y perfil público |
| `RF-CON` | Contabilidad | Movimientos, totales, reporte mensual |
| `RF-NOM` | Empleomanía | Empleados, pagos, recibos |
| `RF-CTA` | Cuenta | Perfil, membresía, idioma, eliminación |
| `RF-SIN` | Sincronización | Operación sin conexión y reconciliación |

Prioridades: **Obligatorio** (sin esto el módulo no se libera) · **Esperado**
(degrada la experiencia pero no bloquea) · **Opcional** (diferible sin
renegociar alcance).

### Restricciones por plan

| | Gratis | Pro | Élite |
|---|---|---|---|
| Ejemplares | 25 | 500 | Ilimitado |
| Pedigrí | 2 generaciones | 4 generaciones | 4 generaciones |
| Pruebas de campo | — | ✓ | ✓ |
| Contabilidad | — | ✓ | ✓ |
| Exportación a PDF | — | ✓ | ✓ |
| Empleomanía | — | — | ✓ |
| Multiusuario y roles | — | — | ✓ (fase 5) |

---

## 7. Plan de entrega

| Fase | Contenido | Criterio de salida |
|---|---|---|
| **F1** | `RF-AUT` · `RF-ONB` · `RF-REG` · `RF-PED` · `RF-SIN` | Un criador migra su libro completo y consulta pedigrí sin conexión |
| **F2** | `RF-PRU` · `RF-CON` · `RF-NOM` | Un mes contable se cierra íntegramente dentro de la app |
| **F3** | `RF-CTA-04` a `RF-CTA-12` (membresías, compras, envío) | Suscripción cobrada y aprobación en ambas tiendas |
| **F4** | `RF-COM` · `RF-PED-08` · `RF-CON-07` (exportación real a PDF) | Primer encuentro concretado y exportación real a PDF |
| **F5** | Multiusuario, roles, panel web | Un criadero operando con dos cuentas y permisos distintos |

**Estamos en F1.** Fuera del MVP: notificaciones push, marketplace, panel web,
integración con básculas o anillos electrónicos, reportes comparativos entre
criaderos.

---

## 8. Estado actual y brecha

Existe hoy: `core/` completo (Result, BaseViewModel, Drift, Supabase,
conectividad, SyncService con cola y watermarks, tema alineado al PRD, l10n
es/en), el feature `auth` con **`RF-AUT` completo** (las diez pantallas, ver
abajo), y `birds` (lista, ficha, formulario), `dashboard` y `settings`.
Migración inicial en
[supabase/migrations/20260801000000_init.sql](supabase/migrations/20260801000000_init.sql)
con `profiles`, `birds` y `clutches`.

### Autenticación — implementado

Pantallas 1–10 en [lib/features/auth/](lib/features/auth/): splash con las tres
derivaciones de `RF-AUT-01`, onboarding de tres láminas, bienvenida, alta con
medidor de fuerza y aceptación de términos, verificación por código de seis
dígitos (misma vista para alta y recuperación), inicio de sesión, y la
recuperación en tres pasos con su modal de éxito.

Dos dependencias externas pendientes:

- **Plantillas de correo de Supabase.** Las de «Confirm signup» y «Reset
  password» deben usar `{{ .Token }}`, no `{{ .ConfirmationURL }}`. Sin ese
  cambio el usuario recibe un enlace y las seis casillas no tienen qué recibir.
  Fija también la vigencia del OTP en 10 minutos (`RV-04`).
- **`RF-AUT-11`** (Google y Apple) está cableado pero inactivo:
  `AuthRepository.signInWithProvider` devuelve `providerUnavailable` y la
  pantalla de bienvenida muestra los botones deshabilitados. Faltan los client
  ID de Google Cloud, «Sign in with Apple» en el perfil de aprovisionamiento y
  los proveedores activados en Supabase.

`RF-AUT-15` ya está: cerrar sesión **conserva los datos locales**, porque la
base va cifrada (`RNF-15`). Lo que sí se limpia son las marcas de
sincronización. Si en el mismo teléfono entra **otro** criadero, se borra todo
lo del anterior: las consultas ya filtran por `owner_id`, pero el requisito
conserva el libro de su dueño, no el de quien pasara por ahí.

### Configuración inicial — implementado

Pantallas 11–14 en [lib/features/onboarding/](lib/features/onboarding/):
criadero y ubicación, numeración de partida y elección de plan, más la
celebración. Los tres pasos comparten un ViewModel porque son un formulario
único: volver atrás no pierde lo escrito (`RF-ONB-07`).

`profiles.next_plate` queda fijado en la placa siguiente a la declarada, que es
lo que permite migrar el libro sin retranscribirlo. Es el único sitio donde el
cliente escribe ese contador; a partir de ahí solo lo mueve la RPC
`next_plate()`, que serializa las reservas para que dos dispositivos del mismo
criadero no generen la misma placa.

La guardia del router lo hace obligatorio: con sesión abierta y `farm_name`
nulo, cualquier ruta lleva a la configuración.

Falta cubrir con prueba la pantalla 14; montarla en un test deja la prueba
colgada por una causa sin aislar.

### Registros — parcialmente implementado

El esquema ya es el del SRS: `birds.plate` entero obligatorio y correlativo,
nombre opcional, `weight_g` en gramos, `line`, estado `loaned` e `is_dirty`.
`clutches` guarda fecha, huevos y nacidos.

De `RF-REG` están: los conteos de Inicio con el aviso al 80 % del plan
(`RF-REG-01/02/16`), la lista ordenada por placa con búsqueda y filtros
(`RF-REG-03/04/05`) y el alta con solo la placa obligatoria y la advertencia de
duplicado (`RF-REG-06/07`).

El **registro de camadas** (`RF-REG-08` a `11`) ya está: pantalla 21 con
contador de crías, vista previa del rango de placas y confirmación con las
placas asignadas. La reserva del bloque es **local y atómica**
(`ProfilesDao.reservePlateBlock`, dentro de la misma transacción que crea las
crías), no por RPC: pedirla al servidor pondría la red en el camino crítico de
la función estrella y lo prohíbe `RF-SIN-01`. La RPC `next_plate()` sigue en el
servidor como autoridad cuando dos dispositivos del mismo criadero registran a
la vez.

La **ficha del ejemplar** (`RF-REG-12`, `RF-REG-13`) ya está: pantallas 20–22
con las tres pestañas —Datos, Pruebas y Descendencia— y la descendencia
agrupada por camada, cada cría enlazada a su propia ficha. La pestaña de
pruebas muestra su estado vacío: el registro es `RF-PRU` y la tabla
`evaluations` llega en F2.

El **selector de progenitor** (`RF-REG-11`) es la pantalla 18: lista filtrada
por sexo, buscador por placa o nombre y alta al vuelo. Se cierra devolviendo la
elección en vez de navegar, así el formulario sigue montado con lo capturado
(CU-02 alterno A). Sustituye al desplegable en el alta de ejemplar y en el
registro de camada. Al topar con el plan, la camada dice **cuántas crías caben**
y ofrece registrar esa cantidad (CU-02 alterno B).

La **foto del ejemplar** (`RF-REG-15`) ya está: cámara o galería, con los topes
de `RV-19` —1.600 px de lado mayor y 2 MB— aplicados en
[lib/core/media/photo_service.dart](lib/core/media/photo_service.dart). El
redimensionado lo hace el selector en código nativo; solo si aun así se pasa de
2 MB se recomprime en un isolate. Se ve en el formulario, en la ficha y como
miniatura en la lista.

**La foto todavía no sube a Storage.** Vive en el área privada de la app y
`birds.photo_path` no viaja en el payload de sincronización —una ruta local no
significa nada en otro dispositivo—. Falta el bucket en Supabase y la operación
de subida independiente que describe §5.

Falta de `RF-REG`:

| ID | Qué falta | Prioridad |
|---|---|---|
| `RF-REG-14` | Editar cualquier campo y **registrar pesos sucesivos con su fecha**. Exige tabla nueva. | Esperado |
| `RF-REG-15` | Subida de la foto a Storage (la captura ya está). | Esperado |

### Contabilidad — implementado

`RF-CON-01` a `RF-CON-06` y `RF-CON-08` en
[lib/features/accounting/](lib/features/accounting/): pantalla 29 con el cierre
del mes, navegación entre meses y desglose por categoría; pantalla 30 para
registrar. No ocupa pestaña —se abre desde Inicio y desde el panel lateral—,
como manda el PRD §7.

**El dinero se guarda en centavos enteros**, no en coma flotante. `12.45 * 100`
da `1244.9999…`, y sobre dos mil movimientos ese error llega a verse en el
balance. En Postgres la columna sigue siendo `numeric(12,2)`; la conversión es
exacta.

`RF-CON-04` pide el balance negativo **en rojo y sin mensajes adicionales**: un
mes en pérdidas es información, no un error que explicarle al criador.

Los recurrentes (`RS-08`) se generan al abrir la app y **no duplican**: antes de
crear se comprueba qué fechas ya existen para esa plantilla. El mensual avanza
por calendario con cuidado del desbordamiento —un movimiento del día 31 cae el
30 en los meses de treinta, en vez de saltar al 1 del siguiente.

Falta `RF-CON-07` (exportar a PDF), que es Opcional y va en F4.

### Pruebas de campo — implementado

`RF-PRU-01` a `RF-PRU-06` en [lib/features/evaluations/](lib/features/evaluations/):
pantalla 24 con las tres cifras del criadero y filtro por resultado, pantalla 25
para registrar, y la pestaña de la ficha (`RF-PRU-05`) con su estado vacío
accionable. `/tests` ya es pestaña de la barra inferior.

El módulo es de Pro en adelante (`RF-PRU-06`) y la restricción **se informa sin
ocultar la pantalla**: esconderla dejaría al criador sin saber que existe. El
tope se comprueba también en el repositorio, no solo en la interfaz.

Dos decisiones sobre las cifras de `RF-PRU-03`: las pruebas sin definir cuentan
en el total —excluirlas inflaría el porcentaje favorable— y el promedio de
condición **ignora** las pruebas que no la anotaron, porque contarlas como cero
hundiría la media. Sin ninguna condición anotada se muestra un guion, no «0,0».

Falta `RF-PRU-07` (Esperado): incorporar el peso de la prueba al historial de
pesos del ejemplar. Va junto con `RF-REG-14`, que es quien crea ese historial.

### Genealogía — implementado

`RF-PED-01` a `RF-PED-07` y `RF-PED-09` en
[lib/features/pedigree/](lib/features/pedigree/): pantalla 23 con árbol
horizontal, desplazamiento y zoom, selector de 2/3/4 generaciones y apertura de
la ficha desde cualquier nodo. El plan gratuito se queda en dos generaciones y
la pantalla lo dice (`RF-PED-03`).

El algoritmo es el del DDT §7 y **no se debe cambiar por uno recursivo por
nodo**: recolecta identificadores nivel a nivel y luego lee todo el árbol de
una vez —5 consultas en lugar de 31—, que es lo que sostiene `RNF-03`.

El corte de ciclos distingue dos casos que se confunden con facilidad: un
ancestro repetido **en el mismo camino** es un dato imposible y corta la rama
(`RS-05`); el mismo ancestro por la rama paterna y por la materna es
**endogamia**, información legítima del criadero, y se dibuja entero.

`RF-PED-08` (exportar a PDF) es Opcional y va en F4.

Con eso **F1 queda cerrado en lo Obligatorio**. Fuera quedan, con prioridad
Esperado, `RF-REG-14` y `RF-REG-15`.

**El esquema implementado diverge de la especificación.** Corregirlo es el
primer trabajo de F1, porque todo lo demás cuelga de la placa:

| Especificación | Implementado hoy | Acción |
|---|---|---|
| `birds.plate` integer obligatorio, correlativo | ✅ migrado | — |
| `birds.name` opcional | ✅ nullable | — |
| `profiles.next_plate` | ✅ columna, RPC `next_plate()` y fijado en el onboarding | ✅ consumido por el alta y por las camadas |
| `profiles.farm_name`, `location`, `country_code`, `locale`, `avatar_url` | ✅ alineado | — |
| `birds.weight_g` integer (gramos) | ✅ integer | — |
| `birds.status = loaned` | ✅ renombrado | — |
| `birds.line` | ✅ renombrado | — |
| `birds.is_dirty` | ✅ añadido | — |
| `clutches`: `date`, `eggs`, `hatched` | ✅ alineado | ✅ UI de camadas completa |
| Tabla `evaluations` | ✅ creada (esquema v4 + migración de Supabase) | — |
| Tabla `transactions` | ✅ creada (esquema v5 + migración de Supabase) | — |
| Tablas `employees`, `payroll_payments` | No existen | Crear con su feature |
| Triggers y RPC del servidor | ✅ `handle_new_user()`, `touch_updated_at()`, `next_plate()`, `active_bird_count()`; falta `delete_account()` y `verify_receipt()` | Implementar los dos restantes |
| Cifrado local (`RNF-15`) | ✅ SQLite3MultipleCiphers vía `hooks.user_defines` | — |
| Tokens en Keychain/Keystore (`RNF-14`) | ✅ `SecureSessionStorage` | — |
| Rutas `/tests`, `/community`, `/account`, `/accounting`, `/payroll` | Faltan (las de `RF-AUT` ya están) | Completar con su feature |

---

## 9. Sistema de diseño

| Rol | Color |
|---|---|
| Navy (marca) | `#0E2A47` |
| Rojo acción | `#C8102E` |
| Macho | `#1E7A4C` |
| Hembra | `#2B6CB0` |
| Fondo | `#F4F6F9` |
| Borde | `#E7ECF2` |
| Texto tenue | `#6B7A8C` |
| Advertencia | `#B7791F` |

Verde para machos y azul para hembras es una **convención cerrada**: se aplica
igual en listas, fichas, pedigrí y estadísticas, y no se usa nunca para
significar otra cosa. El color nunca es el único portador de significado —
siempre lo acompaña una etiqueta textual (`RNF-25`).

Tipografía Inter: título de pantalla 24/600 · sección 16–18/600 · cuerpo
15/400 a 1,55 · secundario 13,5/400 · etiqueta 11/600 +0,1 em · dato numérico
24–28/700.

Componentes: botón 52 px de alto, radio 12 px · campo de texto 52 px, borde
1,5 px · tarjeta radio 16 px, borde 1 px, sin sombra · área táctil mínima
44 px · espaciado en múltiplos de 4, márgenes laterales 20–24 px.

Iconografía de trazo geométrico de 1,7 px, esquinas redondeadas, sin relleno.
Los íconos del dominio siguen la misma retícula que los de interfaz — nunca
ilustración caricaturesca.

### Formatos

Fecha `dd/mm/aaaa` (almacenada ISO 8601 UTC) · fecha y hora `dd/mm/aaaa hh:mm`
en 24 h · moneda con símbolo del país del perfil, separador de miles y dos
decimales (`RD$ 12,450.00`), almacenada `numeric(12,2)` · peso en kg con dos
decimales (o libras si el perfil lo indica), almacenado entero en gramos ·
placa sin ceros a la izquierda, precedida de `#` · edad en meses hasta 24, luego
años y meses · teléfono agrupado por país `(809) 555-1234`, almacenado E.164.

### Estados no felices

Sin conexión → franja ámbar permanente, todo sigue funcionando · límite de plan
→ mensaje con el número exacto del límite y acceso directo a planes, nunca un
error genérico · lista vacía → estado vacío con acción primaria, nunca pantalla
en blanco · búsqueda sin resultados → mensaje distinto al de lista vacía, sin
acción de crear · credenciales inválidas → mensaje único que no revela si el
correo existe (`E-AUTH-01`) · compra cancelada → regreso silencioso, sin mensaje
(`E-IAP-01`).

Toda pantalla superpuesta puede cerrarse; si contiene datos capturados, se pide
confirmación antes de descartarlos.

---

## 10. Umbrales de calidad

| ID | Requisito | Umbral |
|---|---|---|
| `RNF-01` | Arranque en frío hasta pantalla utilizable | < 2,5 s en gama baja |
| `RNF-02` | Búsqueda local sobre 500 ejemplares | < 150 ms |
| `RNF-03` | Pedigrí de 4 generaciones | < 300 ms |
| `RNF-04` | Camada de 15 crías | < 500 ms |
| `RNF-05` | Totales mensuales sobre 2.000 movimientos | < 200 ms |
| `RNF-06` | Desplazamiento en listas y pedigrí | 60 fps sostenidos |
| `RNF-07` | Paquete de instalación | < 40 MB |
| `RNF-09` | Pérdida de datos por fallo de sincronización | Cero |
| `RNF-10` | Operaciones sin resolver > 24 h | < 0,5 % |
| `RNF-22` | Contraste en texto de cuerpo | ≥ 4,5:1 |
| `RNF-24` | Escalado tipográfico del sistema | Hasta 200 % sin recorte |

El pedigrí usa lectura **por nivel** (una consulta por generación, no una por
nodo): 2ⁿ lecturas se reducen a n+1. Es lo que sostiene `RNF-03`.

### Pruebas

Cobertura ≥70 % en ViewModels y repositorios; límites de plan y sincronización
cubiertos de forma exhaustiva. Todo requisito obligatorio de la fase cuenta con
al menos una prueba automatizada que lo verifica. Prueba de resiliencia: 72
horas sin red con 200 operaciones encoladas, cero pérdida de datos.

---

## 11. Comandos

```bash
flutter pub get
dart run build_runner build          # Drift (*.g.dart)
flutter gen-l10n                     # traducciones

cp env.example.json env.json         # y rellena tus credenciales
flutter run --dart-define-from-file=env.json

flutter analyze
# Solo el código escrito a mano: los generados no siguen esta convención.
find lib test -name '*.dart' ! -name '*.g.dart' -not -path '*/generated/*' \
  -print0 | xargs -0 dart format --set-exit-if-changed
flutter test
```

Los generados no se versionan: hay que ejecutarlos tras clonar y cada vez que
cambien las tablas o los `.arb`. Sin `env.json` la app arranca en modo solo
local (Drift funciona; login y sincronización quedan desactivados con aviso).

Las credenciales viven en `env.json`, ignorado por git. **Nunca en
[.vscode/launch.json](.vscode/launch.json)**, que sí se versiona. La clave
publicable es pública por diseño — lo que protege los datos es la RLS.

El arranque del backend paso a paso —migraciones, plantillas de correo con
`{{ .Token }}`, credenciales— está en [README.md](README.md#conectar-con-supabase).

---

## 11 bis. Seguridad del dispositivo

**La base local va cifrada** (`RNF-15`). El cifrado no lo aporta un paquete de
Flutter sino la compilación de SQLite que se empaqueta: el bloque
`hooks.user_defines` del `pubspec.yaml` pide la variante SQLite3MultipleCiphers.
**Si se quita esa línea, el `PRAGMA key` se ignora en silencio y la base queda
en claro sin que nada falle** — por eso hay una prueba que lo comprueba
(`test/core/encryption_test.dart`) y no debe borrarse.

Los paquetes `sqlcipher_flutter_libs` y `sqlite3_flutter_libs` que nombra el
DDT están descontinuados desde febrero de 2026; esta es la forma vigente de
pedir lo mismo. Se eligió SQLite3MultipleCiphers sobre la compilación de
SQLCipher porque esta enlaza OpenSSL en Android y Linux y puede traer un SQLite
más antiguo.

La clave son 256 bits aleatorios en el almacén seguro del sistema
([lib/core/security/secure_store.dart](lib/core/security/secure_store.dart)).
**Si se pierde, los datos locales son irrecuperables**: no hay copia ni forma de
derivarla, y en iOS no viaja en las copias de iCloud a propósito. Lo que protege
al criador de perder su libro es la sincronización, no esta clave.

Los tokens de sesión van al mismo almacén (`RNF-14`): el de refresco vale tanto
como la contraseña, y `SharedPreferences` es un XML legible en un Android
rooteado.

Un dispositivo que ya tuviera la app con base sin cifrar se migra al arrancar,
copiando tabla por tabla —`sqlcipher_export` no existe en sqlite3mc— y **sin
borrar la original hasta que la cifrada está escrita**.

## 12. Convenciones de código

- **Español** en comentarios, nombres de dominio y documentación; el código sigue las convenciones de Dart.
- **Ninguna cadena visible incrustada en el código** (`RNF-27`). Todas viven en `app_es.arb` / `app_en.arb` desde el primer día. Los diseños toleran cadenas 40 % más largas que el español (`RNF-28`).
- Los ViewModels de pantalla usan `autoDispose`; los servicios de larga vida (base, sincronización, sesión, plan) no.
- Sustituir un repositorio por un doble de prueba debe ser una sola sobrescritura de provider.
- Las rutas se declaran en [lib/core/router/routes.dart](lib/core/router/routes.dart); nadie escribe paths a mano en las Views.
- Comenta el **porqué**, no el qué, y cita el identificador del requisito cuando la línea existe por una regla.

---

## 12 bis. El prototipo interactivo es la fuente del diseño

El diseño visual **no está en el DDT** —ese documento es técnico: capas,
esquema, algoritmos, seguridad, riesgos— ni completo en el PRD. Vive en el
prototipo interactivo del proyecto de Claude Design
(`Criador Pro Auth.dc.html`, 27 pantallas), que es lo que hay que consultar
antes de dar por buena una pantalla.

Dos campos salen de ahí y de ningún documento:

**Marca de nacimiento.** Seis posiciones en tres zonas: 1 y 2 en el pie
izquierdo, 3 y 4 en el derecho, 5 y 6 en el pico. Se captura tocando los puntos
sobre el dibujo de la pata y del pico, no eligiendo números de una lista. Se
guarda como `1,4`, y `none` cuando el criador declara que el ave no lleva marca
— que **no es lo mismo que dejarlo en blanco**: en blanco es «no se ha dicho».

**Cintas de ala.** Una paleta cerrada por ala (roja, rosada, azul, verde,
amarilla) con los tonos del prototipo, elegidos para distinguirse a varios
metros y bajo el sol. Como el color no puede ser el único portador de
significado (`RNF-25`) y la etiqueta no cabe, va como descripción accesible.

Ambos aparecen en la ficha del ejemplar, como en el prototipo.

**Plumaje y cresta son catálogos abiertos**, no cerrados
([lib/core/domain/bird_traits.dart](lib/core/domain/bird_traits.dart)). No están
en la lista de catálogos cerrados del SRS §5 —ahí solo hay categorías
contables, estado, resultado, frecuencia y método de pago— y el SRS define
`birds.color` como texto libre. Cada criadero nombra los colores a su manera,
así que el criador **puede crear los suyos** y el valor se guarda tal cual, no
como clave traducible.

La lista que ve son sus valores en uso más unas sugerencias de fábrica que
aparecen a cero. Cada opción lleva **cuántos ejemplares la usan**: ver 211
cenizos y 1 amarillo dice de un vistazo cuál es el nombre real del criadero y
cuál fue un error de tecleo. Se elige en una hoja con radios y no en un
desplegable, porque la lista crece con el criadero.

`comb` (tipo de cresta) **no aparece en ningún documento ni en el prototipo**:
sale de la app de referencia que usa el criador. Mismo trato que el color.

Ninguna de las dos columnas lleva `CHECK` en Postgres — siendo abiertas, sería
contradictorio.

## 12 ter. Divergencias con el prototipo, sin resolver

| Qué | Estado |
|---|---|
| La ficha lleva **cabecera navy** con la foto y las insignias dentro | Pendiente |
| Sus pestañas se llaman «Datos · Evaluaciones · Crías» | Pendiente — choca con la decisión abierta de terminología |
| El registro de cruce tiene **«Estado del cruce»**: Prueba · Hecho · Repetidos | Pendiente, campo nuevo |
| El registro de cruce captura la marca y las cintas **para toda la camada** | Pendiente; hoy solo se capturan por ejemplar |
| El peso se muestra en **libras** | Pendiente; hoy en gramos |

**Aviso de cumplimiento:** el prototipo llama «trabas» al módulo de Comunidad —
«Buscar trabas», `is('trabas')`, `is('trabaRequests')`— con 22 apariciones. Es
vocabulario prohibido por el BRD §8 y **no puede pasar al código ni a los
`.arb`**. La compuerta de compilación lo rechazaría. Al implementar `RF-COM` hay
que renombrarlo: «solicitud de encuentro» es el término del glosario.

## 13. Decisiones abiertas

Pendientes de aprobación; no las cierres por tu cuenta.

| Pregunta | Estado |
|---|---|
| Unificar «gallera» → «criadero» en todo el copy | Recomendado por cumplimiento. Afecta once pantallas del prototipo. **En código nuevo usa «criadero».** |
| Unificar «Evaluaciones» y «Evaluación física» → «Prueba de campo» | Mismo barrido de cumplimiento |
| Moneda por defecto fuera de República Dominicana | Por definir: seguir el país del perfil o elección manual |
| Límite de almacenamiento de fotos por plan | Por definir |
| Precio anual con descuento | Fuera del MVP; evaluar tras medir la conversión mensual |
| Reglas de moderación en Comunidad | Requiere política aprobada antes de abrir el módulo al público |
