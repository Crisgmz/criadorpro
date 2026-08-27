import 'package:criadorpro/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

/// Las rutas se declaran en un solo sitio y nadie escribe paths a mano en las
/// vistas, así que su forma es un contrato.
void main() {
  group('alta de ejemplar', () {
    test('la variante que devuelve el resultado lleva su marca', () {
      // Con ella, el formulario devuelve el ejemplar en lugar de llevarse al
      // criador a la lista: el selector de progenitor lo necesita de vuelta.
      expect(Routes.birdNewForResult, '${Routes.birdNew}?return=1');
      expect(Uri.parse(Routes.birdNewForResult).path, Routes.birdNew);
      expect(Uri.parse(Routes.birdNewForResult).queryParameters['return'], '1');
    });

    test('el alta normal no la lleva', () {
      expect(Uri.parse(Routes.birdNew).queryParameters, isEmpty);
    });
  });

  test('las rutas privadas no se cuelan entre las públicas', () {
    for (final route in [Routes.home, Routes.birds, Routes.birdNew, Routes.accounting]) {
      expect(Routes.isPublic(route), isFalse, reason: route);
    }
    for (final route in [Routes.welcome, Routes.login, Routes.signUp]) {
      expect(Routes.isPublic(route), isTrue, reason: route);
    }
  });

  test('el pedigrí y la ficha se construyen sobre el id del ejemplar', () {
    expect(Routes.birdDetail('abc'), '/birds/abc');
    expect(Routes.birdPedigree('abc'), '/birds/abc/pedigree');
    expect(Routes.birdEdit('abc'), '/birds/abc/edit');
  });
}
