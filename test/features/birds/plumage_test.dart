import 'package:criadorpro/core/domain/plumage.dart';
import 'package:flutter_test/flutter_test.dart';

/// Color de plumaje y marca de nacimiento.
///
/// La marca se guarda como una cadena compuesta, así que lo que se prueba es la
/// codificación en los dos sentidos: un formato mal leído mostraría al criador
/// una marca que no es la del ave.
void main() {
  group('catálogo de color', () {
    test('las claves son estables y únicas', () {
      final ids = PlumageColor.values.map((c) => c.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
      // Las claves viajan a la base: cambiarlas rompería lo ya registrado.
      expect(PlumageColor.fromId('red'), PlumageColor.red);
      expect(PlumageColor.fromId('giro'), PlumageColor.giro);
    });

    test('un valor fuera del catálogo devuelve null y no revienta', () {
      // Texto libre escrito antes de cerrar el catálogo: la ficha lo muestra
      // tal cual en vez de perderlo.
      expect(PlumageColor.fromId('colorao con pinta'), isNull);
      expect(PlumageColor.fromId(''), isNull);
      expect(PlumageColor.fromId(null), isNull);
    });
  });

  group('marca de pie', () {
    test('codifica y descodifica las dos patas', () {
      final value = FootMark.encode(left: {1, 3}, right: {2});

      expect(value, '1,3|2');
      expect(FootMark.leftOf(value), {1, 3});
      expect(FootMark.rightOf(value), {2});
    });

    test('las posiciones salen ordenadas, se toquen en el orden que se toquen', () {
      expect(FootMark.encode(left: {4, 1, 3}, right: {}), '1,3,4|');
    });

    test('sin marca en ningún pie el valor es nulo, no una cadena vacía', () {
      // Guardar «|» dejaría en la base un valor que parece marca y no lo es.
      expect(FootMark.encode(left: {}, right: {}), isNull);
    });

    test('una sola pata marcada deja la otra vacía', () {
      final value = FootMark.encode(left: {}, right: {4});

      expect(value, '|4');
      expect(FootMark.leftOf(value), isEmpty);
      expect(FootMark.rightOf(value), {4});
    });

    test('un valor corrupto no rompe la lectura', () {
      // Puede llegar de una versión anterior o de una sincronización a medias.
      expect(FootMark.leftOf('abc|xyz'), isEmpty);
      expect(FootMark.leftOf(null), isEmpty);
      expect(FootMark.rightOf('1,2'), isEmpty);
      // Posiciones fuera del rango se descartan en lugar de dibujarse.
      expect(FootMark.leftOf('0,5,9|'), isEmpty);
      expect(FootMark.leftOf('2,7|'), {2});
    });

    test('el valor «1 · 4» del prototipo se representa como una por pata', () {
      final value = FootMark.encode(left: {1}, right: {4});

      expect(value, '1|4');
      expect(FootMark.leftOf(value), {1});
      expect(FootMark.rightOf(value), {4});
    });
  });

  group('marca de pico', () {
    test('catálogo cerrado con claves estables', () {
      expect(BeakMark.fromId('upper'), BeakMark.upper);
      expect(BeakMark.fromId('right'), BeakMark.right);
      expect(BeakMark.fromId('otra cosa'), isNull);
      expect(BeakMark.fromId(null), isNull);
    });
  });
}
