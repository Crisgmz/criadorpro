import 'package:criadorpro/core/domain/markings.dart';
import 'package:criadorpro/core/domain/plumage_color.dart';
import 'package:flutter_test/flutter_test.dart';

/// Marca de nacimiento y cintas de ala, según el prototipo.
///
/// La marca se guarda como una cadena compuesta, así que lo que se prueba es la
/// codificación en los dos sentidos: leerla mal mostraría al criador una marca
/// que no es la del ave.
void main() {
  group('marca de nacimiento', () {
    test('el código del prototipo, «1 · 4», se codifica y se lee', () {
      final value = BirthMark.encode(positions: {1, 4}, hasNoMark: false);

      expect(value, '1,4');
      expect(BirthMark.positionsOf(value), {1, 4});
      expect(BirthMark.codeOf(value), '1 · 4');
    });

    test('las posiciones salen ordenadas, se toquen en el orden que se toquen', () {
      expect(BirthMark.encode(positions: {5, 1, 3}, hasNoMark: false), '1,3,5');
    });

    test('cada posición cae en su zona', () {
      expect(MarkZone.of(1), MarkZone.leftFoot);
      expect(MarkZone.of(2), MarkZone.leftFoot);
      expect(MarkZone.of(3), MarkZone.rightFoot);
      expect(MarkZone.of(4), MarkZone.rightFoot);
      expect(MarkZone.of(5), MarkZone.beak);
      expect(MarkZone.of(6), MarkZone.beak);
    });

    test('las zonas activas se deducen de las posiciones', () {
      // Es lo que resalta la tarjeta del pie o del pico.
      expect(BirthMark.zonesOf('1,4'), {MarkZone.leftFoot, MarkZone.rightFoot});
      expect(BirthMark.zonesOf('5'), {MarkZone.beak});
      expect(BirthMark.zonesOf(null), isEmpty);
    });

    test('«sin marca» no es lo mismo que no haber dicho nada', () {
      final none = BirthMark.encode(positions: {}, hasNoMark: true);
      final blank = BirthMark.encode(positions: {}, hasNoMark: false);

      // Nulo es «no se ha dicho»; `none` es «se miró y no tiene».
      expect(none, BirthMark.none);
      expect(blank, isNull);
      expect(BirthMark.isNone(none), isTrue);
      expect(BirthMark.isNone(blank), isFalse);
    });

    test('marcar «sin marca» descarta las posiciones que hubiera', () {
      expect(BirthMark.encode(positions: {1, 2}, hasNoMark: true), BirthMark.none);
      expect(BirthMark.positionsOf(BirthMark.none), isEmpty);
    });

    test('un valor corrupto no rompe la lectura', () {
      expect(BirthMark.positionsOf('abc'), isEmpty);
      // Fuera del rango 1..6: se descarta en lugar de dibujarse.
      expect(BirthMark.positionsOf('0,7,9'), isEmpty);
      expect(BirthMark.positionsOf('2,8'), {2});
      expect(BirthMark.codeOf(null), isNull);
    });
  });

  group('color del plumaje', () {
    test('las claves son estables y únicas', () {
      final ids = PlumageColor.values.map((c) => c.id).toList();
      // Viajan a la base: cambiarlas rompería lo ya registrado.
      expect(ids.toSet(), hasLength(ids.length));
      expect(PlumageColor.fromId('giro'), PlumageColor.giro);
      expect(PlumageColor.fromId('red'), PlumageColor.red);
    });

    test('un valor fuera del catálogo devuelve null y no revienta', () {
      // Texto libre escrito antes de cerrar el catálogo: la ficha lo muestra
      // tal cual en lugar de perderlo.
      expect(PlumageColor.fromId('colorao con pinta'), isNull);
      expect(PlumageColor.fromId(''), isNull);
      expect(PlumageColor.fromId(null), isNull);
    });
  });

  group('cintas de ala', () {
    test('la paleta es la del prototipo, con sus claves estables', () {
      expect(WingBand.values.map((b) => b.id), ['red', 'pink', 'blue', 'green', 'yellow']);
      expect(WingBand.fromId('blue'), WingBand.blue);
      expect(WingBand.red.color.toARGB32(), 0xFFC8102E);
    });

    test('un valor desconocido o vacío es «ninguna»', () {
      expect(WingBand.fromId('morado'), isNull);
      expect(WingBand.fromId(''), isNull);
      expect(WingBand.fromId(null), isNull);
    });
  });
}
