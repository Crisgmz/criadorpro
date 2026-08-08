import 'dart:math' as math;

import 'package:criadorpro/core/theme/app_colors.dart';
import 'package:criadorpro/core/theme/app_spacing.dart';
import 'package:criadorpro/core/theme/app_theme.dart';
import 'package:criadorpro/core/theme/app_typography.dart';
import 'package:criadorpro/core/theme/semantic_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// El sistema de diseño del PRD §6 es una paleta y una escala cerradas. Estas
/// comprobaciones existen para que dejen de serlo solo a propósito: si alguien
/// cambia un tamaño o un color, falla aquí y no en una revisión de capturas.
void main() {
  _textColorTests();
  _semanticColorTests();

  final light = AppTheme.light;
  final dark = AppTheme.dark;

  group('paleta', () {
    test('el rojo de acción es el primario: es lo que Material pinta en botones', () {
      expect(light.colorScheme.primary, AppColors.action);
      expect(AppColors.action, const Color(0xFFC8102E));
    });

    test('el navy de marca viaja en secondary', () {
      expect(light.colorScheme.secondary, AppColors.navy);
      expect(AppColors.navy, const Color(0xFF0E2A47));
    });

    test('el código de sexo es una convención cerrada', () {
      expect(AppColors.male, const Color(0xFF1E7A4C));
      expect(AppColors.female, const Color(0xFF2B6CB0));
    });

    test('error y acción comparten rojo: el PRD usa #C8102E también en campos', () {
      expect(light.colorScheme.error, AppColors.action);
    });

    test('el fondo es el gris del PRD, no el blanco de Material', () {
      expect(light.scaffoldBackgroundColor, AppColors.background);
      expect(AppColors.background, const Color(0xFFF4F6F9));
    });
  });

  group('tipografía', () {
    final text = light.textTheme;

    test('toda la escala usa Inter', () {
      for (final style in [
        text.headlineSmall,
        text.titleMedium,
        text.bodyLarge,
        text.bodyMedium,
        text.labelSmall,
        text.headlineMedium,
      ]) {
        expect(style!.fontFamily, AppTypography.fontFamily);
      }
    });

    test('título de pantalla: 24 · 600', () {
      expect(text.headlineSmall!.fontSize, 24);
      expect(text.headlineSmall!.fontWeight, FontWeight.w600);
    });

    test('cuerpo: 15 con interlineado 1,55', () {
      expect(text.bodyLarge!.fontSize, 15);
      expect(text.bodyLarge!.height, 1.55);
      expect(text.bodyLarge!.fontWeight, FontWeight.w400);
    });

    test('secundario: 13,5', () {
      expect(text.bodyMedium!.fontSize, 13.5);
    });

    test('etiqueta: 11 · 600 con tracking', () {
      expect(text.labelSmall!.fontSize, 11);
      expect(text.labelSmall!.fontWeight, FontWeight.w600);
      expect(text.labelSmall!.letterSpacing, greaterThan(0));
    });

    test('dato numérico: 28 · 700', () {
      expect(text.headlineMedium!.fontSize, 28);
      expect(text.headlineMedium!.fontWeight, FontWeight.w700);
    });
  });

  group('componentes', () {
    test('botones y campos miden 52 px de alto', () {
      expect(AppSizes.control, 52);

      final filled = light.filledButtonTheme.style!.minimumSize!.resolve({})!;
      expect(filled.height, AppSizes.control);
      expect(light.inputDecorationTheme.constraints!.minHeight, AppSizes.control);
    });

    test('ningún botón fuerza ancho infinito', () {
      // `Size.fromHeight` lo haría, y revienta el layout dentro de una Row o de
      // las acciones de un diálogo.
      for (final style in [
        light.filledButtonTheme.style,
        light.outlinedButtonTheme.style,
        light.textButtonTheme.style,
      ]) {
        expect(style!.minimumSize!.resolve({})!.width, lessThan(double.infinity));
      }
    });

    test('el área táctil mínima es de 44 px', () {
      expect(AppSizes.minTouchTarget, 44);
      expect(light.textButtonTheme.style!.minimumSize!.resolve({})!.height, 44);
    });

    test('radios: botón 12, tarjeta 16, insignia 6', () {
      expect(AppRadius.md, 12);
      expect(AppRadius.card, 16);
      expect(AppRadius.badge, 6);
    });

    test('la tarjeta no tiene sombra y sí borde', () {
      expect(light.cardTheme.elevation, 0);
      final shape = light.cardTheme.shape! as RoundedRectangleBorder;
      expect(shape.side.style, BorderStyle.solid);
      expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
    });

    test('el campo enfocado se marca con borde de 1,5 px', () {
      final border = light.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(border.borderSide.width, 1.5);
    });

    test('el botón deshabilitado va al 40 % — PRD §6', () {
      final disabled = light.filledButtonTheme.style!.backgroundColor!.resolve({
        WidgetState.disabled,
      });
      expect(disabled!.a, closeTo(0.4, 0.01));
    });
  });

  group('espaciado', () {
    test('la escala son múltiplos de 4', () {
      for (final step in [
        AppSpacing.xs,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.lg,
        AppSpacing.xl,
        AppSpacing.xxl,
      ]) {
        expect(step % 4, 0, reason: '$step no es múltiplo de 4');
      }
    });

    test('el margen lateral de pantalla está entre 20 y 24', () {
      expect(AppSpacing.screen, inInclusiveRange(20, 24));
    });
  });

  group('tema oscuro', () {
    test('mantiene la escala y la familia', () {
      expect(dark.textTheme.bodyLarge!.fontSize, 15);
      expect(dark.textTheme.bodyLarge!.fontFamily, AppTypography.fontFamily);
    });

    test('el fondo es el navy profundo, no negro puro', () {
      expect(dark.scaffoldBackgroundColor, AppColors.navyDeep);
    });
  });
}

/// `RNF-22` exige 4,5:1 en texto de cuerpo. Estas pruebas lo comprueban con la
/// fórmula de WCAG en lugar de fiarse del ojo: los tonos del PRD están
/// calculados sobre blanco, y al llevarlos al tema oscuro es fácil dejar un
/// verde que se ve «bien» pero no llega al umbral.
double _contrast(Color a, Color b) {
  double channel(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  double luminance(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

  final (light, dark) = luminance(a) > luminance(b) ? (a, b) : (b, a);
  return (luminance(light) + 0.05) / (luminance(dark) + 0.05);
}

/// Un `TextStyle` sin color se pinta blanco, así que sobre tarjeta blanca el
/// texto simplemente no aparece: nada falla, nada avisa, solo hay un hueco. Es
/// exactamente lo que ocurrió con los contadores del panel.
void _textColorTests() {
  group('color del texto', () {
    test('ningún estilo del tema queda sin color', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final t = theme.textTheme;
        final styles = <String, TextStyle?>{
          'displayLarge': t.displayLarge,
          'displayMedium': t.displayMedium,
          'displaySmall': t.displaySmall,
          'headlineLarge': t.headlineLarge,
          'headlineMedium': t.headlineMedium,
          'headlineSmall': t.headlineSmall,
          'titleLarge': t.titleLarge,
          'titleMedium': t.titleMedium,
          'titleSmall': t.titleSmall,
          'bodyLarge': t.bodyLarge,
          'bodyMedium': t.bodyMedium,
          'bodySmall': t.bodySmall,
          'labelLarge': t.labelLarge,
          'labelMedium': t.labelMedium,
          'labelSmall': t.labelSmall,
        };
        styles.forEach((name, style) {
          expect(style?.color, isNotNull, reason: '$name sin color en ${theme.brightness}');
        });
      }
    });

    testWidgets('el dato numérico se pinta y contrasta con la tarjeta', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Card(
              child: Builder(builder: (context) => Text('0', style: AppTypography.metric(context))),
            ),
          ),
        ),
      );

      final painted = tester
          .widget<RichText>(find.descendant(of: find.byType(Card), matching: find.byType(RichText)))
          .text
          .style
          ?.color;

      expect(painted, isNotNull);
      expect(_contrast(painted!, AppTheme.light.cardTheme.color!), greaterThanOrEqualTo(4.5));
    });
  });
}

void _semanticColorTests() {
  group('SemanticColors', () {
    test('el tema registra la paleta de dominio en ambos brillos', () {
      expect(AppTheme.light.extension<SemanticColors>(), SemanticColors.light);
      expect(AppTheme.dark.extension<SemanticColors>(), SemanticColors.dark);
    });

    test('RNF-22 · los acentos de dominio contrastan sobre su superficie', () {
      final lightSurface = AppTheme.light.colorScheme.surface;
      for (final color in [
        SemanticColors.light.male,
        SemanticColors.light.female,
        SemanticColors.light.unknownSex,
        SemanticColors.light.brand,
      ]) {
        expect(_contrast(color, lightSurface), greaterThanOrEqualTo(4.5), reason: '$color');
      }

      final darkSurface = AppTheme.dark.colorScheme.surfaceContainerLow;
      for (final color in [
        SemanticColors.dark.male,
        SemanticColors.dark.female,
        SemanticColors.dark.unknownSex,
        SemanticColors.dark.brand,
      ]) {
        expect(_contrast(color, darkSurface), greaterThanOrEqualTo(4.5), reason: '$color');
      }
    });

    test('la convención de sexo no se invierte al oscurecer', () {
      // Verde macho, azul hembra: el tono se mantiene aunque suba la luminosidad.
      expect(SemanticColors.dark.male.g, greaterThan(SemanticColors.dark.male.b));
      expect(SemanticColors.dark.female.b, greaterThan(SemanticColors.dark.female.g));
    });

    test('en oscuro la tarjeta no se confunde con el fondo', () {
      // Si `color` de la tarjeta fuese `surface`, la tarjeta desaparecería:
      // el fondo del Scaffold es exactamente ese color.
      expect(AppTheme.dark.cardTheme.color, isNot(AppTheme.dark.scaffoldBackgroundColor));
      expect(
        AppTheme.dark.inputDecorationTheme.fillColor,
        isNot(AppTheme.dark.scaffoldBackgroundColor),
      );
    });
  });
}
