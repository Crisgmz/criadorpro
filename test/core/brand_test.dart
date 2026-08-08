import 'package:criadorpro/core/theme/app_theme.dart';
import 'package:criadorpro/core/widgets/brand.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El símbolo es sólido y viene en dos colores fijos: no se puede teñir, hay
/// que servir el archivo correcto. Servir el navy sobre fondo oscuro lo deja
/// invisible, que es justo lo que estas pruebas evitan.
void main() {
  Future<void> pump(WidgetTester tester, Widget child, {required Brightness brightness}) =>
      tester.pumpWidget(
        MaterialApp(
          theme: brightness == Brightness.light ? AppTheme.light : AppTheme.dark,
          home: Scaffold(body: child),
        ),
      );

  String assetOf(WidgetTester tester) =>
      (tester.widget<Image>(find.byType(Image)).image as AssetImage).assetName;

  group('BrandSymbol', () {
    testWidgets('en tema claro usa la variante navy', (tester) async {
      await pump(tester, const BrandSymbol(), brightness: Brightness.light);

      expect(assetOf(tester), BrandAsset.symbolNavy);
    });

    testWidgets('en tema oscuro usa la variante blanca', (tester) async {
      await pump(tester, const BrandSymbol(), brightness: Brightness.dark);

      expect(assetOf(tester), BrandAsset.symbolWhite);
    });

    testWidgets('sobre una superficie navy se fuerza la blanca aunque el tema sea claro', (
      tester,
    ) async {
      await pump(tester, const BrandSymbol(onDark: true), brightness: Brightness.light);

      expect(assetOf(tester), BrandAsset.symbolWhite);
    });
  });

  group('BrandIcon', () {
    testWidgets('hereda tamaño y color del IconTheme, como un Icon de Material', (tester) async {
      await pump(
        tester,
        const IconTheme(
          data: IconThemeData(size: 30, color: Color(0xFF112233)),
          child: BrandIcon(),
        ),
        brightness: Brightness.light,
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, 30);
      expect(image.color, const Color(0xFF112233));
      // `srcIn` conserva el alfa del PNG: tiñe la silueta, no el recuadro.
      expect(image.colorBlendMode, BlendMode.srcIn);
    });

    testWidgets('el destino activo y el inactivo se tiñen distinto', (tester) async {
      Color colorAt(int index) =>
          tester.widgetList<Image>(find.byType(Image)).elementAt(index).color!;

      await pump(
        tester,
        const Row(
          children: [
            IconTheme(
              data: IconThemeData(color: Color(0xFF0E2A47)),
              child: BrandIcon(),
            ),
            IconTheme(
              data: IconThemeData(color: Color(0xFF637284)),
              child: BrandIcon(),
            ),
          ],
        ),
        brightness: Brightness.light,
      );

      expect(colorAt(0), isNot(colorAt(1)));
    });

    testWidgets('en oscuro se tiñe claro sin que nadie se lo pida', (tester) async {
      // Suelto en la pantalla toma el color por omisión del tema. Es el caso
      // que dejaba el símbolo navy invisible sobre fondo oscuro.
      await pump(tester, const BrandIcon(), brightness: Brightness.dark);

      final tint = tester.widget<Image>(find.byType(Image)).color!;
      expect(tint.computeLuminance(), greaterThan(0.5));
    });
  });

  group('barra de navegación', () {
    test('el icono seleccionado y el inactivo no comparten color', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final icons = theme.navigationBarTheme.iconTheme!;
        final selected = icons.resolve({WidgetState.selected})!.color;
        final idle = icons.resolve(<WidgetState>{})!.color;

        expect(selected, isNotNull);
        expect(idle, isNotNull);
        expect(selected, isNot(idle), reason: '${theme.brightness}');
        // 24 es la retícula de Material: por debajo, el símbolo de marca se ve
        // más pequeño que los iconos vecinos.
        expect(icons.resolve(<WidgetState>{})!.size, 24);
      }
    });

    test('el indicador usa el navy suave, no el rojo de acción', () {
      final theme = AppTheme.light;
      expect(theme.navigationBarTheme.indicatorColor, theme.colorScheme.secondaryContainer);
      expect(theme.navigationBarTheme.indicatorColor, isNot(theme.colorScheme.primaryContainer));
    });

    test('la altura deja sitio al icono y a su etiqueta', () {
      expect(AppTheme.light.navigationBarTheme.height, greaterThanOrEqualTo(72));
    });
  });

  group('BrandLockup', () {
    testWidgets('en claro usa el lockup horizontal navy', (tester) async {
      await pump(tester, const BrandLockup(), brightness: Brightness.light);

      expect(assetOf(tester), BrandAsset.lockupHorizontalNavy);
    });

    testWidgets('en oscuro usa el lockup vertical blanco', (tester) async {
      await pump(tester, const BrandLockup(), brightness: Brightness.dark);

      expect(assetOf(tester), BrandAsset.lockupVerticalWhite);
    });
  });
}
