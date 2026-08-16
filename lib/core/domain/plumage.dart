import 'package:flutter/material.dart';

/// Color del plumaje — catálogo cerrado con muestra.
///
/// El SRS define `birds.color` como texto libre de 40 caracteres, pero escrito
/// a mano el mismo color acaba con cinco grafías —«colorao», «colorado»,
/// «Colorado»— y deja de servir para filtrar o comparar. Se guarda la clave en
/// inglés, como el resto de catálogos, y se traduce en presentación.
///
/// Los nombres salen del vocabulario del oficio; los del prototipo del PRD
/// («Giro Colorado», «Canela», «Blanca Real», «Giro Pinta», «Cenizo») confirman
/// varios. **Esta lista es una propuesta, no un dato de los documentos**: si el
/// criadero usa otros nombres, se cambian aquí y en los `.arb`.
///
/// La muestra es orientativa: sirve para reconocer la fila de un vistazo, no
/// para reproducir el tono exacto de un ave.
enum PlumageColor {
  white('white', Color(0xFFF2F0EA)),
  giro('giro', Color(0xFFCFC7B6)),
  red('red', Color(0xFF8E3B24)),
  cinnamon('cinnamon', Color(0xFFB87A46)),
  yellow('yellow', Color(0xFFD8A63F)),
  ash('ash', Color(0xFF808791)),
  barred('barred', Color(0xFF55575A)),
  mottled('mottled', Color(0xFFA89880)),
  dark('dark', Color(0xFF5A2A20)),
  black('black', Color(0xFF1F1D1B));

  const PlumageColor(this.id, this.swatch);

  /// Clave estable que viaja a la base y al servidor.
  final String id;

  /// Muestra para la interfaz. Nunca va sola: siempre con su nombre (`RNF-25`).
  final Color swatch;

  /// `null` si el valor guardado no pertenece al catálogo — por ejemplo, texto
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

/// Marca física de identificación — pie y pico.
///
/// El prototipo del PRD la muestra en la ficha como «Marca de nacimiento: 1 · 4»
/// pero ni el SRS ni el DDT la recogen en el esquema; se añade aquí porque el
/// criador la usa para reconocer al ave antes de que tenga placa.
///
/// El pie se marca perforando las membranas entre los dedos, en cuatro
/// posiciones por pata. Se guarda como `izquierda|derecha`, cada lado con sus
/// posiciones separadas por comas: `1,3|2`. Un formato de texto y no cuatro
/// columnas booleanas porque es un dato que solo se lee entero.
abstract final class FootMark {
  static const int positions = 4;
  static const String _sideSeparator = '|';

  /// Compone el valor almacenado a partir de las posiciones de cada pata.
  static String? encode({required Set<int> left, required Set<int> right}) {
    if (left.isEmpty && right.isEmpty) return null;
    return '${_join(left)}$_sideSeparator${_join(right)}';
  }

  static Set<int> leftOf(String? value) => _parse(value, 0);
  static Set<int> rightOf(String? value) => _parse(value, 1);

  static String _join(Set<int> positions) {
    final sorted = positions.toList()..sort();
    return sorted.join(',');
  }

  static Set<int> _parse(String? value, int side) {
    if (value == null || value.isEmpty) return {};
    final sides = value.split(_sideSeparator);
    if (side >= sides.length) return {};
    return {
      for (final part in sides[side].split(','))
        if (int.tryParse(part.trim()) case final position?)
          if (position >= 1 && position <= positions) position,
    };
  }
}

/// Marca en el pico — catálogo cerrado.
enum BeakMark {
  upper('upper'),
  lower('lower'),
  left('left'),
  right('right');

  const BeakMark(this.id);

  final String id;

  static BeakMark? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final mark in values) {
      if (mark.id == id) return mark;
    }
    return null;
  }
}
