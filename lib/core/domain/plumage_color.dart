import 'package:flutter/material.dart';

/// Color del plumaje — catálogo cerrado.
///
/// El SRS y el DDT lo definen como texto libre de 40 caracteres, y ninguna
/// pantalla del prototipo lo captura. Se cierra en catálogo porque escrito a
/// mano el mismo color acaba con varias grafías —«colorao», «colorado»,
/// «Colorado»— y deja de servir para filtrar o comparar.
///
/// Los nombres salen del vocabulario del oficio y de los propios ejemplares del
/// prototipo: Giro Colorado, Canela, Blanca Real, Giro Pinta, Cenizo, Pinto
/// Bravo. **Es una propuesta, no un dato de los documentos**: si el criadero
/// usa otros, se cambian aquí y en los `.arb`.
///
/// La muestra es orientativa. Sirve para distinguir una opción de otra en la
/// lista, no para reproducir el tono exacto de un ave.
enum PlumageColor {
  giro('giro', Color(0xFFCFC7B6)),
  red('red', Color(0xFF8E3B24)),
  cinnamon('cinnamon', Color(0xFFB87A46)),
  white('white', Color(0xFFF2F0EA)),
  mottled('mottled', Color(0xFFA89880)),
  ash('ash', Color(0xFF808791)),
  barred('barred', Color(0xFF55575A)),
  yellow('yellow', Color(0xFFD8A63F)),
  dark('dark', Color(0xFF5A2A20)),
  black('black', Color(0xFF1F1D1B));

  const PlumageColor(this.id, this.swatch);

  /// Clave estable que viaja a la base y al servidor.
  final String id;

  /// Muestra para la interfaz. Nunca va sola: siempre con su nombre (`RNF-25`),
  /// porque hay colores del oficio que se distinguen por el patrón y no por el
  /// tono — jabado y pinto son dibujos, no tonalidades.
  final Color swatch;

  /// `null` si el valor guardado no pertenece al catálogo, por ejemplo texto
  /// libre escrito antes de cerrarlo. Se conserva y se muestra tal cual en vez
  /// de perderlo.
  static PlumageColor? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final color in values) {
      if (color.id == id) return color;
    }
    return null;
  }
}
