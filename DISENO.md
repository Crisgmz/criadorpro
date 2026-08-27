# Inventario del diseño

Del prototipo `Criador Pro Auth.dc.html` del proyecto de Claude Design
(`42f22e91-446e-40c2-a9b3-709ef701392f`). **30 pantallas y 5 estados
superpuestos.**

> La copia que había en Descargas eran 93 KB y 12 pantallas: solo el flujo de
> autenticación. La buena son 263 KB. Todo lo que se construyó de la pantalla 11
> en adelante se hizo **sin ver este archivo**, extrapolando del vocabulario
> compartido. Esta tabla es la deuda que eso dejó.

## Antes de copiar nada

Tres cosas del prototipo **no pueden pasar al código ni a los `.arb`**, y no es
una preferencia de estilo: es la condición de admisión en App Store y Google
Play, y el riesgo de mayor prioridad del proyecto (BRD §8).

| En el prototipo | En el código |
|---|---|
| «trabas» — pantallas 18 y 24, el menú | «solicitud de encuentro» |
| «gallera» — en casi todas | «criadero» (decisión §13, ya recomendada) |
| «GALLO» como rótulo de sexo — pantalla 22 | «MACHO» |

La compuerta de compilación revisa los `.arb` contra la lista antes de cada
envío. Copiar el texto tal cual hace fallar la compilación.

## Pantallas que no existen en la app

| # | Pantalla | Qué trae |
|---|---|---|
| 13 | **Mi perfil** | Editar nombre, criadero, ubicación, teléfono, idioma, foto. Próxima placa sugerida. «Zona de riesgo» con eliminar cuenta |
| 14 | **Tutoriales** | Lista de vídeos con duración y nivel (Básico/Intermedio/Pro) + tarjeta de soporte |
| 15 | **Soporte WhatsApp** | Número, horario, tiempo de respuesta, botón a WhatsApp y correo |
| 19 | **Pagos y facturación** | Plan actual, método de pago, próximo cobro, historial, cancelar. Dice que en la app se cobra por la tienda |
| 25 | **Eliminar cuenta** | Pantalla completa, no diálogo. Enumera qué se borra y ofrece **descargar los datos antes** |
| 29 | **Reporte por categoría** | Detalle histórico de una categoría contable, con exportación propia |
| — | **Hoja «Agregar registro»** | Tres caminos: nacimiento (marca física, sin placa aún), ave individual, camada |
| — | **Drawer** | Secciones: Membresía · Mi gallera · Mi cuenta · Ayuda · Información. Insignia con solicitudes pendientes |

## Pantallas que existen pero difieren

| # | Pantalla | En qué difiere |
|---|---|---|
| 11 | Registrar camada | **«Estado del cruce»** (Prueba · Hecho · Repetidos), marca de nacimiento y cintas **para toda la camada**, «Notas de objetivo» |
| 12 | Mis registros | Pestañas **Todos · Camadas · Nacimientos**; hoy el filtro es por sexo y estado |
| 18 | Buscar encuentros | Filtros por **clase de peso** (Liviano/Medio/Pesado), distancia en km, insignia **VERIFICADA**, peso en lb. Hoy es un directorio de criaderos |
| 20 | Evaluaciones | Tres cifras: registros, % favorable, **índice promedio**. Filtros Todas/Favorable/**Neutral**/Desfavorable |
| 21 | Nueva evaluación | **Tipo de registro** (prueba de campo · evaluación física · sesión de acondicionamiento), **duración en minutos**, **cuatro índices 1–5** (resistencia, agilidad, capacidad de respuesta), **condición física final** (Óptima/Buena/Descanso) |
| 22 | Ficha | Campo **«Criador»**, peso en **lb**, cifras **por ejemplar** en la pestaña de evaluaciones |
| 24 | Solicitudes | **«Coordinar por WhatsApp»** al aceptar |
| 26 | Contabilidad | Tarjeta de **costo de empleomanía**, pestañas de mes, filtro Todo/Gastos/Ingresos |
| 28 | Empleomanía | **Comprobante** de pago con envío, «Exportar nómina del mes» |
| 30 | Nuevo empleado | **Foto** del empleado, **fecha de entrada** |

## Lo que choca con el SRS

No se puede copiar sin decidir antes, porque contradice la especificación:

| Qué | Conflicto |
|---|---|
| Estado **REGALADO** en la lista | El catálogo del SRS es `active`/`sold`/`deceased`/`loaned` |
| **Neutral** como resultado | El SRS dice `favorable`/`unfavorable`/`undefined` — «Neutral» ≈ «undefined», pero el rótulo cambia |
| **Índices 1–5** de desempeño | El SRS define `condition` 1–10 y ningún índice más |
| Peso en **libras** | El SRS almacena gramos; la presentación en libras necesita el ajuste en el perfil |
| **Registrar nacimiento** sin placa | La placa es obligatoria en `birds` (`RS-01`) |
| Insignia **VERIFICADA** | No existe verificación de criaderos en ningún requisito |

## Orden recomendado

1. **Sin decisiones** — Mi perfil, Soporte, Drawer, Eliminar cuenta a pantalla completa.
2. **Campos nuevos que no chocan** — duración y tipo de la evaluación, foto y fecha de entrada del empleado, estado del cruce, notas de objetivo.
3. **Requieren tu decisión** — la tabla de arriba.
4. **Módulos enteros** — Tutoriales y Pagos necesitan contenido y cuentas de tienda.
