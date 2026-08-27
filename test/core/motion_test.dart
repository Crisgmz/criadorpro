import 'package:criadorpro/core/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El movimiento del producto (`§9` del PRD y el prototipo interactivo).
///
/// Lo que se comprueba aquí no es la estética —para eso están las capturas—
/// sino las dos cosas que se rompen en silencio: que «reducir movimiento» del
/// sistema se respete de verdad, y que ningún gesto deje un `Ticker` vivo.
void main() {
  Widget host(Widget child, {bool reduced = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );

  group('reducir movimiento', () {
    testWidgets('CpFadeUp pinta su hijo entero desde el primer frame', (tester) async {
      await tester.pumpWidget(host(const CpFadeUp(child: Text('hola')), reduced: true));

      // Sin transición intermedia: si quedara una opacidad animada, este
      // primer frame mostraría el texto a medio aparecer.
      expect(find.byType(FadeTransition), findsNothing);
      expect(find.text('hola'), findsOneWidget);
    });

    testWidgets('CpPop no rebota', (tester) async {
      await tester.pumpWidget(host(const CpPop(child: Text('listo')), reduced: true));

      expect(find.byType(ScaleTransition), findsNothing);
      expect(find.text('listo'), findsOneWidget);
    });

    testWidgets('CpFloat no deja un ciclo infinito abierto', (tester) async {
      await tester.pumpWidget(host(const CpFloat(child: Text('ave')), reduced: true));

      // Es la comprobación central: con el ciclo arrancado esto no volvería.
      await tester.pumpAndSettle();
      expect(find.text('ave'), findsOneWidget);
    });

    testWidgets('CpDrawCheck sale ya dibujada', (tester) async {
      await tester.pumpWidget(host(const CpDrawCheck(color: Colors.white), reduced: true));
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('con movimiento', () {
    testWidgets('CpFadeUp entra y termina', (tester) async {
      await tester.pumpWidget(host(const CpFadeUp(child: Text('hola'))));

      expect(find.byType(FadeTransition), findsOneWidget);
      final opacity = tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity;
      expect(opacity.value, lessThan(1));

      await tester.pumpAndSettle();
      expect(opacity.value, 1);
    });

    testWidgets('CpFloat sigue latiendo', (tester) async {
      await tester.pumpWidget(host(const CpFloat(child: Text('ave'))));
      await tester.pump(const Duration(seconds: 2));

      final transform = tester.widget<Transform>(find.byType(Transform).first);
      expect(transform.transform.getTranslation().y, lessThan(0));
    });
  });

  // Regresión: los controladores se creaban en un `late final` perezoso, así
  // que con el movimiento apagado nadie los tocaba en `build` y era `dispose`
  // quien acababa construyéndolos —ya fuera del árbol, buscando un `TickerMode`
  // que ya no existe—. Reventaba solo en ese camino.
  testWidgets('quitar del árbol un gesto que nunca llegó a animarse no revienta', (tester) async {
    for (final child in [
      const CpFadeUp(child: Text('a')),
      const CpPop(child: Text('b')),
      const CpFloat(child: Text('c')),
      const CpDrawCheck(color: Colors.black),
    ]) {
      await tester.pumpWidget(host(child, reduced: true));
      await tester.pumpWidget(host(const SizedBox(), reduced: true));
      await tester.pumpAndSettle();
    }
  });
}
