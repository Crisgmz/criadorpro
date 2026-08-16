/// Rasgos del ejemplar que se eligen de una lista **abierta**: color del
/// plumaje y tipo de cresta.
///
/// A diferencia de los catálogos cerrados del SRS §5 —categorías contables,
/// estado, resultado de prueba—, estos no están fijados: el SRS define
/// `birds.color` como texto libre, y cada criadero nombra los colores a su
/// manera. Por eso el criador puede añadir los suyos, y por eso el valor se
/// guarda tal cual y no como clave traducible.
enum BirdTrait {
  plumage,
  comb;

  /// Sugerencias de fábrica. Aparecen aunque nadie las use todavía, con su
  /// contador a cero, para que el criadero no arranque con la lista vacía.
  ///
  /// Van en español porque es el idioma origen del producto; el criador las
  /// renombra o añade las suyas si su vocabulario es otro.
  List<String> get suggestions => switch (this) {
    BirdTrait.plumage => const [
      'Amarillo',
      'Blanco',
      'Canelo',
      'Cenizo',
      'Colorado',
      'Giro',
      'Jabado',
      'Negro',
      'Pinto',
      'Retinto',
    ],
    BirdTrait.comb => const ['Motón', 'Pava', 'Peine', 'Rosa', 'Simple', 'Fresa', 'Nuez'],
  };
}

/// Una opción de la lista, con cuántos ejemplares la usan.
///
/// El contador no es decorativo: al elegir el color de un ejemplar nuevo, ver
/// que el criadero tiene 211 cenizos y 1 amarillo dice de un vistazo cuál es el
/// nombre que se usa de verdad y cuál fue un error de tecleo.
class TraitOption implements Comparable<TraitOption> {
  const TraitOption({required this.value, required this.count});

  final String value;
  final int count;

  /// `true` si nadie la usa todavía: es una sugerencia de fábrica.
  bool get isUnused => count == 0;

  /// Orden alfabético, insensible a mayúsculas y acentos, como en la lista.
  @override
  int compareTo(TraitOption other) => value.toLowerCase().compareTo(other.value.toLowerCase());
}

/// Compone la lista que ve el criador: sus valores en uso más las sugerencias
/// que aún no ha tocado.
///
/// Los valores en uso mandan sobre las sugerencias cuando coinciden salvo por
/// mayúsculas o espacios: si el criadero escribió «cenizo», no se le añade
/// además «Cenizo» como si fueran dos colores distintos.
List<TraitOption> buildTraitOptions({required BirdTrait trait, required Map<String, int> inUse}) {
  final options = <String, TraitOption>{};

  for (final entry in inUse.entries) {
    final value = entry.key.trim();
    if (value.isEmpty) continue;
    options[value.toLowerCase()] = TraitOption(value: value, count: entry.value);
  }

  for (final suggestion in trait.suggestions) {
    options.putIfAbsent(suggestion.toLowerCase(), () => TraitOption(value: suggestion, count: 0));
  }

  final sorted = options.values.toList()..sort();
  return sorted;
}
