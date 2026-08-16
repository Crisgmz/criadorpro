import 'package:criadorpro/core/domain/bird_traits.dart';
import 'package:flutter_test/flutter_test.dart';

/// Plumaje y cresta son catálogos **abiertos**: el criadero usa su vocabulario
/// y añade lo que le falte. Lo que se prueba es cómo se compone la lista que ve
/// —lo suyo primero, las sugerencias después— y que no aparezcan duplicados.
void main() {
  group('composición de la lista', () {
    test('sin nada registrado se ven solo las sugerencias, a cero', () {
      final options = buildTraitOptions(trait: BirdTrait.plumage, inUse: const {});

      expect(options, hasLength(BirdTrait.plumage.suggestions.length));
      expect(options.every((o) => o.count == 0), isTrue);
      expect(options.every((o) => o.isUnused), isTrue);
    });

    test('los valores en uso traen su contador', () {
      final options = buildTraitOptions(
        trait: BirdTrait.plumage,
        inUse: const {'Cenizo': 211, 'Canelo': 23},
      );

      final cenizo = options.firstWhere((o) => o.value == 'Cenizo');
      expect(cenizo.count, 211);
      expect(cenizo.isUnused, isFalse);
    });

    test('un valor propio del criadero aparece junto a las sugerencias', () {
      final options = buildTraitOptions(trait: BirdTrait.plumage, inUse: const {'Céspedes': 1});

      expect(options.map((o) => o.value), contains('Céspedes'));
      expect(options.map((o) => o.value), contains('Giro'));
    });

    test('lo que ya usa el criadero manda sobre la sugerencia que coincide', () {
      // Si escribió «cenizo» en minúscula, no se le añade además «Cenizo»
      // como si fueran dos colores distintos.
      final options = buildTraitOptions(trait: BirdTrait.plumage, inUse: const {'cenizo': 40});

      final matches = options.where((o) => o.value.toLowerCase() == 'cenizo');
      expect(matches, hasLength(1));
      expect(matches.single.value, 'cenizo');
      expect(matches.single.count, 40);
    });

    test('la lista sale ordenada alfabéticamente, sin importar mayúsculas', () {
      final options = buildTraitOptions(trait: BirdTrait.comb, inUse: const {'zorro': 2, 'ala': 1});

      final values = options.map((o) => o.value.toLowerCase()).toList();
      expect(values, List<String>.from(values)..sort());
    });

    test('los valores vacíos se descartan', () {
      // Una fila con la cadena vacía crearía una opción sin nombre.
      final options = buildTraitOptions(trait: BirdTrait.comb, inUse: const {'': 5, '  ': 3});

      expect(options.map((o) => o.value), isNot(contains('')));
      expect(options, hasLength(BirdTrait.comb.suggestions.length));
    });
  });

  test('cada rasgo trae sus propias sugerencias', () {
    expect(BirdTrait.plumage.suggestions, contains('Cenizo'));
    expect(BirdTrait.comb.suggestions, contains('Peine'));
    // No se mezclan: una cresta «Cenizo» no significa nada.
    expect(BirdTrait.comb.suggestions, isNot(contains('Cenizo')));
  });
}
