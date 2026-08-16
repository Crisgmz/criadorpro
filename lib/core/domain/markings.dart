import 'package:flutter/material.dart';

/// Marca de nacimiento — seis posiciones repartidas en tres zonas.
///
/// Es como el criador identifica una nidada antes de que las crías tengan
/// placa: se perfora o se corta en una posición concreta y todas las del mismo
/// cruce llevan la misma marca. El prototipo la muestra como `1 · 4`.
///
/// Las posiciones **no son arbitrarias**: 1 y 2 caen en el pie izquierdo, 3 y 4
/// en el derecho, 5 y 6 en el pico. De ahí sale la zona, que no se guarda
/// aparte porque se deduce.
enum MarkZone {
  leftFoot([1, 2]),
  rightFoot([3, 4]),
  beak([5, 6]);

  const MarkZone(this.positions);

  final List<int> positions;

  static MarkZone of(int position) => switch (position) {
    1 || 2 => MarkZone.leftFoot,
    3 || 4 => MarkZone.rightFoot,
    _ => MarkZone.beak,
  };
}

/// Conjunto de posiciones marcadas, y su lectura como código.
abstract final class BirthMark {
  /// Valor guardado cuando el criador declara que el ave **no lleva marca**.
  ///
  /// No es lo mismo que el campo vacío: vacío es «no se ha dicho», y esto es
  /// «se miró y no tiene». El prototipo lo distingue con un interruptor propio.
  static const String none = 'none';

  static const List<int> allPositions = [1, 2, 3, 4, 5, 6];

  /// Compone el valor almacenado: `1,4`, o `none`.
  static String? encode({required Set<int> positions, required bool hasNoMark}) {
    if (hasNoMark) return none;
    if (positions.isEmpty) return null;
    final sorted = positions.toList()..sort();
    return sorted.join(',');
  }

  static bool isNone(String? value) => value == none;

  static Set<int> positionsOf(String? value) {
    if (value == null || value.isEmpty || value == none) return {};
    return {
      for (final part in value.split(','))
        if (int.tryParse(part.trim()) case final position?)
          if (allPositions.contains(position)) position,
    };
  }

  /// Zonas con al menos una posición marcada. Es lo que resalta la tarjeta.
  static Set<MarkZone> zonesOf(String? value) => {
    for (final position in positionsOf(value)) MarkZone.of(position),
  };

  /// Lectura del código para la ficha: `1 · 4`.
  static String? codeOf(String? value) {
    final positions = positionsOf(value).toList()..sort();
    return positions.isEmpty ? null : positions.join(' · ');
  }
}

/// Cinta de ala — paleta cerrada.
///
/// Es el otro identificador rápido del criadero: una cinta de color en cada
/// ala, que se lee de lejos sin tener que agarrar al ave. Los tonos son los del
/// prototipo y no se eligen al azar: tienen que distinguirse a varios metros y
/// bajo el sol.
enum WingBand {
  red('red', Color(0xFFC8102E)),
  pink('pink', Color(0xFFE8467C)),
  blue('blue', Color(0xFF1E6FD9)),
  green('green', Color(0xFF2FB46A)),
  yellow('yellow', Color(0xFFF2B705));

  const WingBand(this.id, this.color);

  final String id;
  final Color color;

  static WingBand? fromId(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final band in values) {
      if (band.id == id) return band;
    }
    return null;
  }
}
