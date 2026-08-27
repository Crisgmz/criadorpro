/// Apertura de la base local — `RNF-15`.
///
/// El cuerpo vive en dos archivos y la plataforma elige cuál:
///
/// - [encrypted_connection_native.dart] en iOS y Android, que es el producto:
///   base cifrada con SQLite3MultipleCiphers y migración de la que hubiera
///   quedado en claro.
/// - [encrypted_connection_web.dart] al compilar para el navegador, donde
///   **no hay cifrado**: la vista web solo sirve para revisar pantallas.
///
/// El desvío no es cosmético. La implementación nativa importa
/// `package:sqlite3`, que arrastra `dart:ffi`, y `dart2js` rechaza los miembros
/// `external` que no son interoperabilidad con JS. Compilada para web, la
/// aplicación entera fallaba con cientos de «Only JS interop members may be
/// 'external'» dentro del paquete —ni una sola línea del proyecto en el
/// mensaje—, así que el error no señalaba a su causa.
library;

export 'encrypted_connection_native.dart'
    if (dart.library.js_interop) 'encrypted_connection_web.dart';
