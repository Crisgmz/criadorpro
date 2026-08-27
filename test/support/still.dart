import 'package:flutter/widgets.dart';

/// Monta el árbol con el movimiento apagado.
///
/// Las animaciones del producto respetan «reducir movimiento» del sistema, así
/// que activarlo aquí las deja en su estado final desde el primer frame. Sin
/// esto, `pumpAndSettle` se cuelga en cualquier pantalla con una animación
/// continua —la ilustración que flota en el onboarding, por ejemplo—, que por
/// definición nunca termina.
///
/// El movimiento en sí se prueba aparte, en `test/core/motion_test.dart`.
Widget still(Widget child) =>
    MediaQuery(data: const MediaQueryData(disableAnimations: true), child: child);
